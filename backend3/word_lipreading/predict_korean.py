"""한국어 입 모양 인식: 일반 영상에서 음성 없이 문장을 예측합니다."""
import argparse
from datetime import datetime
import json
import math
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np

from korean_model import KoreanLipReader

ROOT = Path(__file__).resolve().parent
LIPS = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409,
        291, 375, 321, 405, 314, 17, 84, 181, 91, 146]


def segments(path, start, end, window):
    cap = cv2.VideoCapture(str(path))
    try:
        fps = cap.get(cv2.CAP_PROP_FPS)
        if not cap.isOpened() or not math.isfinite(fps) or fps <= 0:
            raise ValueError(f'영상을 열 수 없습니다: {path}')
        index = int(start*fps)
        cap.set(cv2.CAP_PROP_POS_FRAMES, index)
        stop = int(end*fps) if end is not None else math.inf
        with mp.solutions.face_mesh.FaceMesh(max_num_faces=2, refine_landmarks=True) as detector:
            while index < stop:
                first = index
                patches = []
                multiple = False
                for _ in range(round(window*fps)):
                    if index >= stop:
                        break
                    ok, frame = cap.read()
                    if not ok:
                        break
                    index += 1
                    h, w = frame.shape[:2]
                    small = cv2.resize(frame, (min(w, 640), round(h*min(w, 640)/w)))
                    found = detector.process(cv2.cvtColor(small, cv2.COLOR_BGR2RGB)).multi_face_landmarks or []
                    patch = None
                    if len(found) > 1:
                        multiple = True
                    elif found:
                        pts = np.array([[found[0].landmark[i].x*w, found[0].landmark[i].y*h] for i in LIPS])
                        center = (pts.min(0)+pts.max(0))/2
                        side = max(np.ptp(pts[:, 0])*2, np.ptp(pts[:, 1])*2, 16)
                        x, y = center-side/2
                        matrix = np.array([[side/96, 0, x], [0, side/96, y]], dtype=np.float32)
                        patch = cv2.warpAffine(frame, matrix, (96, 96),
                            flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REPLICATE)
                    patches.append(patch)
                if not patches:
                    break
                detected = sum(p is not None for p in patches)
                info = {'start_seconds': first/fps, 'end_seconds': index/fps,
                        'detected_frames': detected, 'total_frames': len(patches)}
                if multiple or detected < .8*len(patches) or len(patches)/fps < .3:
                    info['status'] = 'skipped_face_or_duration'
                    yield None, info
                    continue
                previous = next(p for p in patches if p is not None)
                for i, patch in enumerate(patches):
                    if patch is None:
                        patches[i] = previous
                    else:
                        previous = patch
                # Official preprocessing uses 30 FPS; preserve clip duration.
                ids = np.linspace(0, len(patches)-1, max(1, round(len(patches)/fps*30))).astype(int)
                yield np.stack([patches[i] for i in ids]), info
    finally:
        cap.release()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('video', nargs='?', type=Path)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--start', type=float, default=0)
    parser.add_argument('--end', type=float)
    parser.add_argument('--segment-seconds', type=float, default=6)
    parser.add_argument('--decoder', choices=['hybrid', 'ctc'], default='hybrid')
    args = parser.parse_args()
    if args.output_dir and not args.video:
        parser.error('--output-dir은 영상 하나를 지정할 때 사용하세요.')
    if not math.isfinite(args.start) or args.start < 0 or not .3 <= args.segment_seconds <= 10:
        parser.error('시작 시간은 0 이상, 구간 길이는 0.3~10초여야 합니다.')
    if args.end is not None and (not math.isfinite(args.end) or args.end <= args.start):
        parser.error('종료 시간은 시작 시간보다 커야 합니다.')
    videos = [args.video] if args.video else sorted(p for p in (ROOT/'input_videos').iterdir()
        if p.suffix.lower() in ('.mp4', '.avi', '.mov', '.mkv', '.webm'))
    if not videos:
        parser.error('input_videos 폴더에 영상 파일을 넣어 주세요.')
    print('한국어 입 모양 인식 모델을 불러옵니다. 음성은 사용하지 않습니다.', flush=True)
    reader = KoreanLipReader()
    failed = False
    for video in videos:
        out = args.output_dir or ROOT/'results'/f'{video.stem}_korean_{datetime.now():%Y%m%d_%H%M%S_%f}'
        out.mkdir(parents=True, exist_ok=True)
        report = {'video': str(video.resolve()), 'model': '한국어 입 모양 인식 모델',
            'language': 'Korean', 'audio_used': False, 'strict_weights': True,
            'decoder': args.decoder, 'segments': [],
            'warning': '실험용 예측입니다. 자동 입술 검출은 원본 JSON 경계 상자와 다르며, 고정 구간 경계에서 문장이 끊길 수 있습니다.'}
        try:
            for frames, info in segments(video, args.start, args.end, args.segment_seconds):
                if frames is not None:
                    print(f'{info["start_seconds"]:.2f}–{info["end_seconds"]:.2f}초 분석 중...', flush=True)
                    info['text'] = reader.predict(frames, args.decoder)
                    info['status'] = 'predicted' if info['text'] else 'empty_prediction'
                    if not (out/'mouth_preview.jpg').exists():
                        cv2.imwrite(str(out/'mouth_preview.jpg'), np.concatenate(frames[np.linspace(0,len(frames)-1,5).astype(int)],axis=1))
                report['segments'].append(info)
                print(info.get('text', info['status']), flush=True)
            report['status'] = 'completed' if any(s.get('text') for s in report['segments']) else 'no_text'
        except Exception as error:
            report['status'] = 'error'
            report['error'] = str(error)
            failed = True
        (out/'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2),encoding='utf-8')
        lines = [report['warning'], f'상태: {report["status"]}']
        if 'error' in report:
            lines.append(report['error'])
        lines += [f'{s["start_seconds"]:.2f}–{s["end_seconds"]:.2f}초: {s.get("text", s["status"])}' for s in report['segments']]
        (out/'result.txt').write_text('\n'.join(lines), encoding='utf-8-sig')
        print(f'저장 위치: {out}', flush=True)
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
