from datetime import datetime, timezone, timedelta
from pathlib import Path
from uuid import uuid4

import logging
import time
from contextlib import contextmanager

LOG = logging.getLogger("uvicorn.error")

@contextmanager
def measure(timings, label):
    started = time.perf_counter()
    try:
        yield
    finally:
        elapsed = round((time.perf_counter() - started) * 1000, 1)
        timings[label] = elapsed
        LOG.info("analysis stage=%s elapsed_ms=%.1f", label, elapsed)


def get_korea_now():
    """
    한국 시간 기준 현재 시간을 반환한다.
    DB 저장 및 결과 기록의 생성 시간으로 사용된다.
    """
    return datetime.now(timezone(timedelta(hours=9))).replace(tzinfo=None)


def get_target_pronunciation(category: str, target_item: str):
    """
    사용자가 선택한 학습 항목을 실제 AI 분석에 사용할 발음으로 변환한다.

    예:
    - 자음 'ㄱ' 선택 → 실제 발음 '가'
    - 모음 'ㅏ' 선택 → 실제 발음 '아'

    AI 모듈은 단독 자음/모음보다 실제 발음 가능한 음절을 기준으로 분석하므로
    여기서 목표 발음 값을 변환한다.
    
    consonant_practice_map = {
        "ㄱ": "가",
        "ㄲ": "까",
        "ㅋ": "카",
        "ㅇ": "아",

        "ㅂ": "바",
        "ㅃ": "빠",
        "ㅍ": "파",
        "ㅁ": "마",

        "ㄷ": "다",
        "ㄸ": "따",
        "ㅌ": "타",
        "ㅅ": "사",
        "ㅆ": "싸",
        "ㄴ": "나",
        "ㄹ": "라",

        "ㅈ": "자",
        "ㅉ": "짜",
        "ㅊ": "차",

        "ㅎ": "하",
    }
    """
    
    consonant_practice_map = {
        "ㄱ": "그",
        "ㄲ": "끄",
        "ㅋ": "크",
        "ㅇ": "으",

        "ㅂ": "브",
        "ㅃ": "쁘",
        "ㅍ": "프",
        "ㅁ": "므",

        "ㄷ": "드",
        "ㄸ": "뜨",
        "ㅌ": "트",
        "ㅅ": "스",
        "ㅆ": "쓰",
        "ㄴ": "느",
        "ㄹ": "르",

        "ㅈ": "즈",
        "ㅉ": "쯔",
        "ㅊ": "츠",

        "ㅎ": "흐",
    }

    # Frontend 21개 모음 중 기준 영상/보정값이 확보된 19개만 평가한다.
    # 단독 자모는 음성 인식에 적합한 초성 'ㅇ' 결합 음절로 변환한다.
    vowel_practice_map = {
        "ㅏ": "아", "ㅐ": "애", "ㅑ": "야",
        "ㅓ": "어", "ㅔ": "에", "ㅕ": "여",
        "ㅗ": "오", "ㅘ": "와", "ㅙ": "왜", "ㅚ": "외", "ㅛ": "요",
        "ㅜ": "우", "ㅝ": "워", "ㅞ": "웨", "ㅟ": "위", "ㅠ": "유",
        "ㅡ": "으", "ㅢ": "의", "ㅣ": "이",
    }

    if category == "자음":
        return consonant_practice_map.get(target_item, target_item)

    if category == "모음":
        item = target_item.strip()
        if item in ("ㅒ", "ㅖ", "얘", "예"):
            raise ValueError(
                f"'{item}'은 현재 입모양 기준 영상이 없어 분석 대상에서 제외되었습니다."
            )
        if item in vowel_practice_map:
            return vowel_practice_map[item]
        # Flutter의 구버전이 이미 결합된 음절(예: '와')을 전송해도 허용한다.
        if item in vowel_practice_map.values():
            return item
        raise ValueError(f"지원하지 않는 모음 학습 항목입니다: {target_item!r}")

    return target_item


def is_lip_analysis_failed(visual_result: dict):
    """0점과 입술 검출 실패는 구분한다.

    기존 버전의 raw_lip_result.error, 최신 버전의 visual_analysis_status 및
    video_result.success_frame_count를 모두 지원한다.
    """
    raw = visual_result.get("raw_lip_result") or {}
    status = visual_result.get("visual_analysis_status") or raw.get("error_code")
    if status == "landmarks_missing" or raw.get("error"):
        return True
    video = visual_result.get("video_result") or {}
    return isinstance(video, dict) and video.get("success_frame_count") == 0


def analyze_sentence(video_path: str, target_item: str):
    """Analyze sentences with the independent voice_analysis package only.

    Never call the legacy mouth/phoneme scoring pipeline here. Legacy numeric
    score keys use None because those scores are not calculated for sentences.
    """
    from voice_analysis import analyze_video

    timings = {}
    session_id = uuid4().hex
    output_dir = Path("outputs") / "voice_analysis" / session_id
    with measure(timings, "sentence_full_pipeline"):
        raw = analyze_video(
            str(video_path), output_dir=output_dir,
            media_base_url=f"/media/{session_id}", reference_text=target_item,
            pronunciation_provider=__import__("os").environ.get("SENTENCE_PRONUNCIATION_PROVIDER") or None,
        )
    LOG.info("analysis completed category=문장 timings_ms=%s", timings)

    # ETRI + Whisper 텍스트를 비교해 단어/음절 단위 재연습 후보를 추가합니다.
    # 기존 발음 점수나 인식 결과는 변경하지 않습니다.
    from voice_analysis.correction_integration import enrich_sentence_analysis
    raw = enrich_sentence_analysis(raw, reference_text=target_item, output_dir=output_dir)

    recognized = raw.get("recognized_text") or ""
    comparison = raw.get("text_comparison") or {}
    features = raw.get("audio_features") or {}
    duration = features.get("duration") or {}
    volume = features.get("volume") or {}
    pitch = features.get("pitch") or {}
    matched = bool(comparison.get("normalized_match"))

    if not recognized.strip():
        feedbacks = ["음성 인식 결과가 없습니다. 녹음 상태를 확인해 주세요."]
    elif matched:
        feedbacks = ["음성 인식 문장이 기준 문장과 일치합니다. 이는 발음 정확도 점수가 아닙니다."]
    else:
        feedbacks = [
            "음성 인식 결과와 기준 문장이 다릅니다. "
            "인식 오류 가능성이 있으므로 발음 오류로 단정하지 않습니다."
        ]

    # 두 인식 결과의 불일치가 있을 때만 재연습 안내를 덧붙입니다.
    correction = raw.get("correction_candidates") or {}
    if correction.get("status") == "review_candidates":
        feedbacks.append(correction["summary"])

    # ETRI 점수가 안내 기준보다 낮을 때 문장 전체 재연습 권고.
    # 특정 음소가 틀렸다는 단정이나 자모별 점수 생성은 하지 않습니다.
    repractice = raw.get("sentence_repractice") or {}
    if repractice.get("recommended"):
        feedbacks.append(repractice["message"])

    return {
        "id": None,
        "user_id": None,
        "category": "문장",
        "target_item": target_item,
        "video_path": str(video_path),
        "created_at": get_korea_now().strftime("%Y-%m-%d %H:%M:%S"),
        "target_pronunciation": target_item,
        "whisper_result": recognized,
        "is_correct": matched,  # Recognized text match, NOT pronunciation quality.
        "speech_start_time": None,
        "speech_end_time": None,
        "speech_duration": duration.get("speech_sec"),
        "volume": volume.get("mean_db"),  # dBFS
        "energy_change": None,
        "average_pitch": pitch.get("mean_hz"),
        "pitch_change": pitch.get("range_hz"),
        "speed_score": None,
        "duration_score": None,
        "stability_score": None,
        "pitch_score": None,
        "volume_score": None,
        "audio_total_score": None,
        "average_mouth_open_ratio": None,
        "max_mouth_open_ratio": None,
        "min_mouth_open_ratio": None,
        "lip_movement_change": None,
        "average_mouth_open_score": None,
        "max_mouth_open_score": None,
        "lip_movement_score": None,
        "visual_total_score": None,
        "feedbacks": feedbacks,
        "voice_analysis": raw,
        "analysis_timing_ms": timings,
    }


def analyze_pronunciation(
    video_path: str,
    category: str,
    target_item: str,
):
    """
    발음 분석 전체 흐름을 담당하는 함수

    처리 순서:
    1. 학습 항목을 실제 목표 음절로 변환하고 기준값 존재 여부를 검증
    2. 요청별 독립된 결과 폴더 생성
    3. 오디오 분석
    4. 입모양 분석
    5. Whisper 음성 인식
    6. 목표 발음과 인식 결과 비교
    7. 피드백 생성
    8. 최종 결과 JSON 저장
    9. 백엔드 응답용 dict 반환
    """

    # Route sentences exclusively to voice_analysis; retain the complete
    # original audio + lip + Whisper pipeline for consonants and vowels.
    if category == "문장":
        return analyze_sentence(video_path, target_item)
    if category not in ("자음", "모음"):
        raise ValueError(f"지원하지 않는 분석 유형: {category!r}")

    # 발음 타깃/기준 영상 검증을 비싼 ML 모듈 import 이전에 먼저 수행한다.
    target_pronunciation = get_target_pronunciation(category, target_item)
    if category == "모음":
        from ai.targets import TARGETS
        ref = TARGETS.get(target_pronunciation) or {}
        if not ref.get("visual"):
            raise ValueError(
                f"'{target_item}'({target_pronunciation}) 입모양 평가 기준값이 없어 "
                "분석을 시작할 수 없습니다. ai/generated_targets.json을 확인하세요."
            )
        if not ref.get("audio_aliases"):
            raise ValueError(
                f"'{target_pronunciation}' 음성 비교 기준이 없습니다. "
                "ai/generated_targets.json의 audio_aliases를 확인하세요."
            )

    # Heavy imports are local: a sentence request does not load MediaPipe or legacy Whisper.
    from ai.audio_module import analyze_audio
    from ai.lip_module import analyze_lip
    from ai.whisper_module import recognize_speech, check_target_match
    from ai.feedback_module import make_feedback
    from ai.result_writer import save_final_result, convert_audio_result_for_save

    timings = {}
    work_dir = Path("outputs") / "jamo" / uuid4().hex
    work_dir.mkdir(parents=True, exist_ok=True)

    with measure(timings, "jamo_audio_extract_trim_features"):
        audio_result = analyze_audio(
            video_path=video_path, target_pronunciation=target_pronunciation,
            output_dir=work_dir,
        )
    with measure(timings, "jamo_lip_landmarks_score"):
        visual_result = analyze_lip(
            video_path=video_path,
            target_pronunciation=target_pronunciation,
            start_time=audio_result.get("lip_start_time", 0.0),
            end_time=audio_result.get("lip_end_time", 0.0),
            output_dir=work_dir,
        )
    with measure(timings, "jamo_whisper_inference"):
        whisper_result = recognize_speech(audio_path=audio_result["trimmed_audio_path"])
    recognized_text = whisper_result.get("recognized_text", "")
    audio_match = check_target_match(recognized_text=recognized_text, target_char=target_pronunciation)
    audio_result["whisper_result"] = recognized_text
    audio_result["is_correct"] = audio_match

    # 음성 분석 결과, 입모양 분석 결과, Whisper 인식 결과를 바탕으로 피드백 생성
    feedbacks = make_feedback(
        target_pronunciation=target_pronunciation,
        audio_result=audio_result,
        visual_result=visual_result,
    )

    # 입모양 분석 실패 여부 판단
    lip_failed = is_lip_analysis_failed(visual_result)

    # 입모양 분석 실패 시 사용자에게 재촬영 안내 피드백 추가
    if lip_failed:
        feedbacks.insert(
            0,
            "입모양 분석에 실패했습니다. 얼굴을 정면에 두고 입이 잘 보이도록 다시 촬영해 주세요.",
        )

    # result_writer.py에서 최종 결과 저장에 사용할 원본 입모양 결과와 영상 처리 결과 추출
    raw_lip_result = visual_result.get("raw_lip_result")
    video_result = visual_result.get("video_result")

    # 입모양 분석 결과가 존재하면 최종 결과를 final_result.json으로 저장
    if raw_lip_result is not None:
        save_final_result(
            target_char=target_pronunciation,
            audio_result=convert_audio_result_for_save(audio_result),
            lip_result=raw_lip_result,
            whisper_result=whisper_result,
            audio_match=audio_match,
            feedback=feedbacks,
            video_path=video_path,
            video_result=video_result,
            lip_failed=lip_failed,
            output_path=str(work_dir / "final_result.json"),
        )

    timings["total_measured_ms"] = round(sum(timings.values()), 1)
    LOG.info("analysis completed category=%s timings_ms=%s", category, timings)

    # FastAPI를 통해 Flutter로 전달할 최종 응답 데이터
    return {
        "id": None,
        "user_id": None,

        "category": category,
        "target_item": target_item,
        "video_path": str(video_path),
        "created_at": get_korea_now().strftime("%Y-%m-%d %H:%M:%S"),

        "target_pronunciation": target_pronunciation,
        "whisper_result": recognized_text,
        "is_correct": audio_match,

        # Librosa 음성 분석 결과
        "speech_start_time": audio_result.get("speech_start_time", 0.0),
        "speech_end_time": audio_result.get("speech_end_time", 0.0),
        "speech_duration": audio_result.get("speech_duration", 0.0),

        "volume": audio_result.get("volume", 0.0),
        "energy_change": audio_result.get("energy_change", 0.0),
        "average_pitch": audio_result.get("average_pitch", 0.0),
        "pitch_change": audio_result.get("pitch_change", 0.0),

        # 음성 세부 점수
        "speed_score": audio_result.get("speed_score", 0.0),
        "duration_score": audio_result.get("duration_score", 0.0),
        "stability_score": audio_result.get("stability_score", 0.0),
        "pitch_score": audio_result.get("pitch_score", 0.0),
        "volume_score": audio_result.get("volume_score", 0.0),
        "audio_total_score": audio_result.get("audio_total_score", 0.0),

        # 입모양 분석 결과
        "average_mouth_open_ratio": visual_result.get(
            "average_mouth_open_ratio",
            0.0,
        ),
        "max_mouth_open_ratio": visual_result.get(
            "max_mouth_open_ratio",
            0.0,
        ),
        "min_mouth_open_ratio": visual_result.get(
            "min_mouth_open_ratio",
            0.0,
        ),
        "lip_movement_change": visual_result.get(
            "lip_movement_change",
            0.0,
        ),

        # 입모양 세부 점수
        "average_mouth_open_score": visual_result.get(
            "average_mouth_open_score",
            0.0,
        ),
        "max_mouth_open_score": visual_result.get(
            "max_mouth_open_score",
            0.0,
        ),
        "lip_movement_score": visual_result.get(
            "lip_movement_score",
            0.0,
        ),
        "visual_total_score": visual_result.get(
            "visual_total_score",
            0.0,
        ),

        # 사용자에게 보여줄 피드백 문장 목록
        "feedbacks": feedbacks,
        "analysis_timing_ms": timings,
    }