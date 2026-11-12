# coding: utf-8
"""One-shot live ETRI test using an already-recorded sentence WAV.

Run from backend3. Makes at most one ETRI API request. It never prints the API key.
"""
import argparse
import json
import os
import sys
from pathlib import Path


def latest_sentence_audio(base: Path):
    results = sorted(base.glob("*/result.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in results:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            reference = (data.get("text_comparison") or {}).get("reference_text")
            audio = path.parent / "audio.wav"
            if isinstance(reference, str) and reference.strip() and audio.is_file():
                return audio, reference
        except (OSError, ValueError, TypeError):
            pass
    raise FileNotFoundError("outputs/voice_analysis 아래에 문장 result.json + audio.wav가 없습니다.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", type=Path, help="이미 녹음된 16kHz mono WAV 파일")
    parser.add_argument("--text", help="녹음된 기준 문장. --audio 사용 시 필수")
    args = parser.parse_args()
    if bool(args.audio) != bool(args.text):
        parser.error("--audio 와 --text는 같이 사용해야 합니다.")
    key = os.environ.get("ETRI_API_KEY", "").strip()
    print("[ETRI 진단] 현재 프로세스에 API 키가 설정되었는가:", bool(key))
    if not key:
        print("[해결] 해당 PowerShell에 ETRI_API_KEY를 설정한 후 다시 실행하세요.")
        return 2
    print("[ETRI 진단] 전송 포맷:", os.environ.get("ETRI_AUDIO_FORMAT", "wav"), "(검증된 AI 방식: wav)")
    try:
        from voice_analysis.etri_pronunciation import assess_pronunciation
        if args.audio:
            audio, reference = args.audio, args.text
        else:
            audio, reference = latest_sentence_audio(Path("outputs/voice_analysis"))
        print("[ETRI 진단] 기존 녹음 사용:", audio)
        print("[ETRI 진단] 기준 문장:", reference)
        print("[ETRI 진단] 실제 ETRI API 요청 중 (1회)...")
        result = assess_pronunciation(
            audio, reference, api_key=key,
            audio_format=os.environ.get("ETRI_AUDIO_FORMAT", "wav").strip().lower(),
            timeout=120,
        )
        print("[ETRI 연결 성공] 발음 점수:", result["score"], "/ 5")
        print("[ETRI 연결 성공] 인식 문장:", result["recognized_text"])
        return 0
    except Exception as exc:
        print("[ETRI 연결 실패]", type(exc).__name__ + ":", str(exc))
        print("[안내] 위 오류를 확인해 주세요. API 키 원문은 공유하지 마세요.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
