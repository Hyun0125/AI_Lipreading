"""ETRI Korean sentence pronunciation assessment client.

Reference: https://epretx.etri.re.kr/apiDetail?id=98
The documented response provides a sentence score, not named phoneme scores.
"""

import base64
import json
import math
import os
import wave
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .text_comparison import normalize_text

DEFAULT_URL = "http://epretx.etri.re.kr:8000/api/WiseASR_PronunciationKor"


class EtriAPIError(RuntimeError):
    pass


def get_api_key(api_key=None):
    key = api_key or os.environ.get("ETRI_API_KEY", "")
    if not key.strip():
        raise ValueError("ETRI_API_KEY 환경 변수에 API 키를 설정하세요.")
    return key.strip()


def build_payload(audio_path, reference_text, audio_format="wav"):
    if not normalize_text(reference_text):
        raise ValueError("기준 문장에는 글자 또는 숫자가 포함되어야 합니다.")
    if audio_format not in ("wav", "pcm"):
        raise ValueError("audio_format은 wav 또는 pcm이어야 합니다.")
    path = Path(audio_path)
    with wave.open(str(path), "rb") as audio:
        if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate(), audio.getcomptype()) != (1, 2, 16000, "NONE"):
            raise ValueError("16 kHz, 16-bit, mono PCM WAV 파일이 필요합니다.")
        frames = audio.getnframes()
        if not 0 < frames <= 16000 * 60:
            raise ValueError("음성 길이는 0초 초과, 60초 이하여야 합니다.")
        pcm = audio.readframes(frames)
        if len(pcm) != frames * 2:
            raise ValueError("음성 파일이 손상되었거나 잘렸습니다.")
        if not any(pcm):
            raise ValueError("완전 무음 파일은 발음 평가할 수 없습니다.")
    # Restore the WAV file bytes (including RIFF header): this is the format
    # that produced a real score in the original AI module validation.
    data = path.read_bytes() if audio_format == "wav" else pcm
    return {"argument": {
        "language_code": "korean", "script": reference_text,
        "audio": base64.b64encode(data).decode("ascii"),
    }}


def parse_response(response):
    if not isinstance(response, dict) or type(response.get("result")) is not int:
        raise EtriAPIError("ETRI 응답 형식이 올바르지 않습니다.")
    if response["result"] != 0:
        raise EtriAPIError(f"ETRI 발음 평가 실패 (result={response['result']}). 키·허용 IP·호출 한도를 확인하세요.")
    body = response.get("return_object")
    if not isinstance(body, dict) or not isinstance(body.get("recognized"), str):
        raise EtriAPIError("ETRI 응답에 인식 문장이 없습니다.")
    score = body.get("score")
    if isinstance(score, bool):
        raise EtriAPIError("ETRI 점수 형식이 올바르지 않습니다.")
    try:
        score = float(score)
    except (TypeError, ValueError) as exc:
        if isinstance(score, str) and score.lstrip().startswith("<"):
            raise EtriAPIError(
                "ETRI 인식은 성공했지만 발음평가 score에 숫자 대신 XML/HTML 형태의 오류 문자열이 반환됐습니다. "
                "ETRI 평가 엔진 또는 요청 데이터의 문제일 수 있습니다. 서버에 점수를 임의 생성하지 않습니다."
            ) from None
        raise EtriAPIError("ETRI 응답에 유효한 숫자 발음평가 점수가 없습니다.") from exc
    if not math.isfinite(score) or not 1 <= score <= 5:
        raise EtriAPIError("ETRI 발음 점수가 문서의 1~5 범위를 벗어났습니다.")
    return {
        "provider": "etri", "assessment_scope": "sentence",
        "recognized_text": body["recognized"], "score": score,
        "score_min": 1, "score_max": 5,
        "phoneme_scores": None,
        "limitation": "문장 전체 발음 평가입니다. 특정 자음·모음의 결함을 판정하지 않습니다.",
    }


def assess_pronunciation(audio_path, reference_text, *, api_key=None, endpoint=None,
                         timeout=120, audio_format="wav"):
    key = get_api_key(api_key)
    payload = build_payload(audio_path, reference_text, audio_format)
    request = Request(
        endpoint or os.environ.get("ETRI_PRONUNCIATION_URL") or DEFAULT_URL,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json; charset=UTF-8", "Authorization": key},
        method="POST",
    )
    # Use the transport from the original tested AI module.
    try:
        with urlopen(request, timeout=timeout) as response:
            result = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        raise EtriAPIError(
            f"ETRI HTTP 오류 {exc.code}. API 키, 허용 IP, 사용 한도 또는 서버 상태를 확인하세요."
        ) from None
    except TimeoutError:
        raise EtriAPIError(
            f"ETRI HTTP 요청이 {timeout}초 제한 내에 완료되지 않았습니다."
        ) from None
    except URLError as exc:
        # Keep diagnostic text concise and never include request headers/keys.
        reason = exc.reason
        if isinstance(reason, TimeoutError):
            raise EtriAPIError(
                f"ETRI HTTP 요청이 {timeout}초 제한 내에 완료되지 않았습니다."
            ) from None
        raise EtriAPIError(
            f"ETRI HTTP 연결 실패: {type(reason).__name__}"
        ) from None
    except (ValueError, UnicodeError):
        raise EtriAPIError("ETRI 응답을 JSON으로 읽을 수 없습니다.") from None
    return parse_response(result)
