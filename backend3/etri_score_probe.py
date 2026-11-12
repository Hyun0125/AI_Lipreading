# -*- coding: utf-8 -*-
"""One safe ETRI score-format diagnostic request (no API key printed).

Copy this file into backend3, then run:
    & "C:\\Users\\danee\\StudioProjects\\backend\\venv\\Scripts\\python.exe" .\\etri_score_probe.py

This reuses a recorded sentence and tests the same raw PCM audio with
just the trailing punctuation removed from the reference script.
"""
import json
import os
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import ProxyHandler, Request, build_opener

from voice_analysis.etri_pronunciation import DEFAULT_URL, build_payload


AUDIO_PATH = Path(
    r"outputs\voice_analysis\d5b045299f1d456e97c285b7e468ed88\audio.wav"
)
REFERENCE = "\uc544\uce68\ub9c8\ub2e4 \ucc45\uc744 \uc77d\uc5b4\uc694"  # no period


def main():
    key = os.environ.get("ETRI_API_KEY", "").strip()
    if not key:
        raise SystemExit("ETRI_API_KEY is not set in this PowerShell.")
    if not AUDIO_PATH.is_file():
        raise SystemExit(f"Recorded WAV not found: {AUDIO_PATH}")

    payload = build_payload(AUDIO_PATH, REFERENCE, audio_format="pcm")
    request = Request(
        os.environ.get("ETRI_PRONUNCIATION_URL") or DEFAULT_URL,
        data=json.dumps(payload, ensure_ascii=True).encode("utf-8"),
        headers={
            "Content-Type": "application/json; charset=UTF-8",
            "Authorization": key,
        },
        method="POST",
    )
    print("[TEST] PCM 16kHz / reference with final punctuation removed")
    print("[TEST] reference:", REFERENCE)
    print("[TEST] one ETRI request; key will not be printed")
    try:
        with build_opener(ProxyHandler({})).open(request, timeout=45) as resp:
            result = json.load(resp)
            obj = result.get("return_object") or {}
            print("HTTP:", resp.status)
            print("result:", result.get("result"))
            print("recognized:", repr(obj.get("recognized")))
            print("score:", repr(obj.get("score")))
            print("score_type:", type(obj.get("score")).__name__)
    except HTTPError as exc:
        print("HTTP error:", exc.code)
        print("response:", exc.read().decode("utf-8", "replace")[:300])
    except (URLError, TimeoutError) as exc:
        print("network error:", type(exc).__name__, str(exc))
    except (ValueError, OSError) as exc:
        print("error:", type(exc).__name__, str(exc))


if __name__ == "__main__":
    main()
