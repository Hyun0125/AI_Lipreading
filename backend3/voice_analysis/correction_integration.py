"""기존 문장 파이프라인을 보존하면서 Whisper + ETRI 교정 후보를 후처리."""
from __future__ import annotations

import json
import logging
import math
import os
from pathlib import Path

from .correction_candidates import detect_correction_candidates

_LOG = logging.getLogger("uvicorn.error")


def _as_text(value):
    return value.strip() if isinstance(value, str) else ""


def _repractice_threshold() -> float:
    """앱의 학습 안내 기준이며 ETRI가 공식 지정한 임계값은 아닙니다."""
    try:
        value = float(os.getenv("SENTENCE_REPRACTICE_THRESHOLD", "3.5"))
        if math.isfinite(value) and 1.0 <= value <= 5.0:
            return value
    except (TypeError, ValueError):
        pass
    _LOG.warning("Invalid SENTENCE_REPRACTICE_THRESHOLD; using 3.5")
    return 3.5


def build_sentence_repractice(score, threshold: float = 3.5) -> dict:
    """ETRI 문장 *전체* 점수로 문장 재연습 여부만 판단합니다.

    특정 단어·음소의 오류를 점수로부터 추론하지 않습니다.
    """
    number = None
    try:
        if score is not None and not isinstance(score, bool):
            parsed = float(score)
            if math.isfinite(parsed) and 1.0 <= parsed <= 5.0:
                number = parsed
    except (ValueError, TypeError):
        pass
    if number is None:
        return {
            "status": "unavailable", "recommended": False,
            "score": None, "threshold": threshold,
            "message": "ETRI 문장 점수가 없어 재연습 여부를 판단하지 않았어요.",
            "basis": "ETRI sentence score only", "is_diagnosis": False,
        }
    recommended = number < threshold
    if recommended:
        message = (
            f"ETRI 발음 점수 {number:.2f}/5.0점으로 학습 안내 기준 "
            f"{threshold:.1f}점보다 낮아요. 문장 전체를 천천히 다시 연습해 보세요. "
            "이 점수만으로 틀린 단어·음절을 특정할 수는 없어요."
        )
    else:
        message = (
            "ETRI 점수에 따른 문장 전체 재연습 안내는 없어요. "
            "다만 이것이 모든 발음의 정확성을 보장하지는 않아요."
        )
    return {
        "status": "recommended" if recommended else "not_needed",
        "recommended": recommended, "score": round(number, 5),
        "threshold": threshold, "message": message,
        "basis": "ETRI sentence score only", "is_diagnosis": False,
    }


def enrich_sentence_analysis(raw: dict, *, reference_text: str, output_dir) -> dict:
    """raw를 증강하되 기존 키·점수·오디오 분석 결과를 변경하지 않음.

    ETRI 측 결과가 있으나 독립 Whisper 텍스트가 별도 저장되지 않았을 경우
    이미 추출된 audio.wav로 Whisper를 한 번 실행한다. 추가 ETRI 호출은 없다.
    """
    if not isinstance(raw, dict):
        raise TypeError("voice_analysis 결과는 dict여야 합니다.")
    pronunciation = (
        raw.get("pronunciation_assessment")
        or raw.get("etri_assessment")
        or raw.get("etri_result")
        or {}
    )
    if not isinstance(pronunciation, dict):
        pronunciation = {}
    etri_text = _as_text(pronunciation.get("recognized_text"))
    if not etri_text:
        etri_text = _as_text(pronunciation.get("recognized"))
    etri_score = pronunciation.get("score")

    whisper_text = (
        _as_text(raw.get("whisper_recognized_text"))
        or _as_text(raw.get("whisper_result"))
        or _as_text(raw.get("whisper_text"))
    )
    warning = None
    if not whisper_text:
        if etri_text:
            audio_path = Path(output_dir) / "audio.wav"
            if audio_path.is_file():
                try:
                    from .whisper_module import transcribe_audio
                    whisper_text = _as_text(transcribe_audio(audio_path))
                except Exception as exc:
                    warning = f"Whisper 재인식 실패: {type(exc).__name__}"
                    _LOG.warning("correction candidates: Whisper failed: %s", exc)
            else:
                warning = "음성 파일이 없어 Whisper 재인식을 진행하지 못했습니다."
        else:
            # ETRI가 사용되지 않은 기존 경로에서는 recognized_text가 Whisper 결과
            whisper_text = _as_text(raw.get("recognized_text"))

    comparison = detect_correction_candidates(
        reference_text, whisper_text=whisper_text,
        etri_text=etri_text, etri_score=etri_score,
    )
    if warning:
        comparison["warning"] = warning
    raw["whisper_recognized_text"] = whisper_text
    raw["etri_recognized_text"] = etri_text
    raw["correction_candidates"] = comparison
    # 별도 학습 권고: 단어별 오류 탐지가 아닌 문장 전체 점수 기준.
    raw["sentence_repractice"] = build_sentence_repractice(
        etri_score, threshold=_repractice_threshold()
    )

    # 저장된 결과에도 반영. 기존 파일이 없다면 쓰지 않음.
    result_path = Path(output_dir) / "result.json"
    if result_path.is_file():
        try:
            persisted = json.loads(result_path.read_text(encoding="utf-8"))
            if isinstance(persisted, dict):
                persisted.update({
                    "whisper_recognized_text": whisper_text,
                    "etri_recognized_text": etri_text,
                    "correction_candidates": comparison,
                    "sentence_repractice": raw["sentence_repractice"],
                })
                tmp_path = result_path.with_name("result.correction.tmp")
                tmp_path.write_text(json.dumps(persisted, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
                tmp_path.replace(result_path)
        except (OSError, TypeError, ValueError) as exc:
            _LOG.warning("could not update correction result.json: %s", exc)
    return raw
