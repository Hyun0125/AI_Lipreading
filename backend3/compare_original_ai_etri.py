# coding: utf-8
"""Compare old AI validation audio to the failing backend3 audio.

Put this script in backend3 and run with the same interpreter and session that
contains ETRI_API_KEY. This sends a *single* real ETRI request, only for the
original file, and never prints credentials. The failing current WAV is checked
locally, not re-submitted.
"""
import argparse
import array
import math
import os
import sys
import wave
from pathlib import Path

FAILED_REL = Path('outputs/voice_analysis/d5b045299f1d456e97c285b7e468ed88/audio.wav')
OLD_REFERENCE = '혼자 임용시험 준비를 하려니 너무 외로워'


def describe_wav(path):
    if not path or not path.is_file():
        print('[파일 없음]', path)
        return None
    with wave.open(str(path), 'rb') as f:
        rate, channels, width, frame_count = f.getframerate(), f.getnchannels(), f.getsampwidth(), f.getnframes()
        data = f.readframes(frame_count)
    if channels != 1 or width != 2 or rate != 16000:
        print('[오디오 형식]', path, 'rate=', rate, 'channels=', channels, 'width=', width)
        return None
    a = array.array('h')
    a.frombytes(data)
    # array('h') is native-endian on Windows (little-endian), as required.
    if sys.byteorder != 'little':
        a.byteswap()
    n = len(a)
    peak = max((abs(x) for x in a), default=0)
    rms = math.sqrt(sum(x*x for x in a) / n) if n else 0
    nseg = min(n, int(rate * .25))
    prefix = math.sqrt(sum(x*x for x in a[:nseg]) / nseg) if nseg else 0
    suffix = math.sqrt(sum(x*x for x in a[-nseg:]) / nseg) if nseg else 0
    result = dict(seconds=round(n/rate,2), peak_percent=round(peak/32768*100,2),
                  rms_percent=round(rms/32768*100,2), start_rms_percent=round(prefix/32768*100,2),
                  end_rms_percent=round(suffix/32768*100,2))
    print('[오디오 검사]', path)
    print(' ', result)
    return result


def find_original(start):
    root = start.parent
    candidates = []
    # Only check obvious old-project paths. Avoid recursively searching venvs.
    for pattern in (
        '*/backend/outputs/voice-validation/audio.wav',
        '*/outputs/voice-validation/audio.wav',
        '*/backend/pronunciation_analysis/sentence/outputs/voice-validation/audio.wav',
        '*/AI_Lipreading*/backend/outputs/voice-validation/audio.wav',
    ):
        candidates.extend(root.glob(pattern))
    return next((p for p in candidates if p.is_file()), None)


def main():
    parser = argparse.ArgumentParser(description='Original AI ETRI A/B diagnostic (one API request).')
    parser.add_argument('--original', type=Path, help='Path to the old successful outputs/voice-validation/audio.wav')
    parser.add_argument('--current', type=Path, default=FAILED_REL)
    args = parser.parse_args()
    key = os.environ.get('ETRI_API_KEY', '').strip()
    print('[키 설정 여부]', bool(key))
    if not key:
        print('ETRI_API_KEY is missing in this PowerShell session.')
        return 2
    describe_wav(args.current)
    original = args.original or find_original(Path.cwd())
    if original is None:
        print('[기존 AI 성공 샘플 WAV를 찾지 못함]')
        print('Old AI archive README references outputs/voice-validation/audio.wav,')
        print('but the ZIP itself does not include this validation recording.')
        print('If available on your PC, run:')
        print(r'  python .\compare_original_ai_etri.py --original "C:\path\to\audio.wav"')
        print('No ETRI API request was sent.')
        return 3
    if not describe_wav(original):
        print('Old AI WAV is not valid; no request was sent.')
        return 4
    print('[원본 AI 성공 샘플 1회 재검증]')
    from voice_analysis.etri_pronunciation import assess_pronunciation
    try:
        result = assess_pronunciation(original, OLD_REFERENCE, api_key=key, audio_format='wav', timeout=120)
        print('[원본 AI WAV 현재 점수]', result['score'], '/ 5')
        print('[원본 AI WAV 현재 인식]', result['recognized_text'])
        print('[판정] Old AI file scores today. Compare the current capture/FFmpeg audio preprocessing.')
        return 0
    except Exception as exc:
        print('[원본 AI WAV도 현재 실패]', type(exc).__name__, str(exc))
        print('[판정] The same successful sample fails now. This is NOT evidence that the current Flutter recording caused it.')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
