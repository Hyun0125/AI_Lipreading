import json
import tempfile
import unittest
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

from voice_analysis.audio_graphs import build_graph_data


class AudioGraphVolumeTests(unittest.TestCase):
    def test_volume_graph_has_matching_time_and_rms_arrays(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tone.wav"
            sample_rate = 16000
            samples = np.arange(sample_rate, dtype=np.float32) / sample_rate
            signal = 0.2 * np.sin(2 * np.pi * 220 * samples)
            sf.write(path, signal, sample_rate)
            audio, sr = librosa.load(path, sr=None, mono=True)
            f0 = np.full(1 + len(audio) // 512, 220.0, dtype=float)

            graphs = build_graph_data(audio, sr, f0)
            volume = graphs["volume"]

            self.assertGreater(len(volume["time_sec"]), 1)
            self.assertEqual(len(volume["time_sec"]), len(volume["rms_dbfs"]))
            self.assertTrue(all(value is None or np.isfinite(value)
                                for value in volume["rms_dbfs"]))
            json.dumps(graphs, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
