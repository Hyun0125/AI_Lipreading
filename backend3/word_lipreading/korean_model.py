"""Official OLKAVS visual-only model with strict pretrained loading."""
import csv
from pathlib import Path
import sys

import torch

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'vendor/olkavs'
sys.path.insert(0, str(SOURCE))
from avsr.utils.model_builder import build_model
from avsr.utils.search import SearchSequence
from vocabulary.utils import grp2char


class KoreanLipReader:
    def __init__(self):
        torch.set_num_threads(2)
        self.model = build_model(72, 0, architecture='video', front_dim=512,
            encoder_n_layer=12, encoder_d_model=256, encoder_n_head=8,
            encoder_ff_dim=2048, encoder_dropout_p=.1, decoder_n_layer=6,
            decoder_d_model=256, decoder_n_head=8, decoder_ff_dim=2048,
            decoder_dropout_p=.1, pass_visual_frontend=False, verbose=False)
        state = torch.load(ROOT/'checkpoints/multiview_lip.pt', map_location='cpu', weights_only=True)
        self.model.load_state_dict(state, strict=True)
        self.model.eval()
        with (SOURCE/'vocabulary/kor_grapheme.csv').open(encoding='utf-8-sig') as f:
            self.labels = {int(row['id']): row['char'] for row in csv.DictReader(f)}

    @torch.inference_mode()
    def predict(self, frames, method='hybrid'):
        # Match original _parse_video: BGR, per-clip standardization.
        video = torch.from_numpy(frames).float()
        std = video.std()
        if not torch.isfinite(std) or std < 1e-6:
            raise ValueError('입술 영상의 변화 또는 명암이 부족합니다.')
        video = ((video-video.mean())/std).permute(3, 0, 1, 2)[None]
        # Frontend has one temporal kernel of width 5. Halo preserves its output
        # while avoiding a full-clip high-resolution activation allocation.
        parts = []
        for start in range(0, video.shape[2], 16):
            end = min(start+16, video.shape[2])
            lo, hi = max(0, start-2), min(video.shape[2], end+2)
            feat = self.model.encoder.front(video[:, :, lo:hi])
            parts.append(feat[:, start-lo:end-lo])
        features = torch.cat(parts, dim=1)
        encoder = self.model.encoder
        # Use the original decoder search on precomputed visual features.
        encoder.pass_front = True
        try:
            lengths = torch.tensor([features.shape[1]])
            if method == 'ctc':
                encoded = self.model.medium(encoder(features, lengths))
                logits = self.model.decoder.ctcdecoder(encoded)
                ids = torch.unique_consecutive(logits.argmax(-1)[0]).tolist()
            else:
                search = SearchSequence(self.model, 72, method='hybrid', max_len=200,
                                        ctc_rate=.6, mp_num=1)
                outputs, lengths = search(features, lengths, None, None,
                                          beam_size=1, D_end=-14, M_end=16, mp_num=1)
                ids = outputs[0, :int(lengths[0])].tolist()
        finally:
            encoder.pass_front = False
        tokens = []
        for i in ids:
            if i == 2:
                break
            if i > 3:
                tokens.append(self.labels[i])
        return grp2char(''.join(tokens)).strip()
