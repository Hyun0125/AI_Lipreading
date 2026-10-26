from datetime import datetime, timezone, timedelta

from ai.cleanup import cleanup_previous_outputs
from ai.audio_module import analyze_audio
from ai.lip_module import analyze_lip
from ai.whisper_module import recognize_speech, check_target_match
from ai.feedback_module import make_feedback
from ai.result_writer import save_final_result, convert_audio_result_for_save


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

    vowel_practice_map = {
        "ㅏ": "아",
        "ㅑ": "야",
        "ㅓ": "어",
        "ㅕ": "여",
        "ㅗ": "오",
        "ㅛ": "요",
        "ㅜ": "우",
        "ㅠ": "유",
        "ㅡ": "으",
        "ㅣ": "이",
    }

    if category == "자음":
        return consonant_practice_map.get(target_item, target_item)

    if category == "모음":
        return vowel_practice_map.get(target_item, target_item)

    return target_item


def is_lip_analysis_failed(visual_result: dict):
    """
    입모양 분석 실패 여부를 판단한다.

    입모양 관련 점수가 모두 0점이면
    입술 랜드마크가 제대로 추출되지 않았거나
    분석 가능한 프레임이 부족한 것으로 판단한다.
    """

    return (
        visual_result.get("average_mouth_open_score", 0.0) == 0
        and visual_result.get("max_mouth_open_score", 0.0) == 0
        and visual_result.get("lip_movement_score", 0.0) == 0
        and visual_result.get("visual_total_score", 0.0) == 0
    )


def analyze_pronunciation(
    video_path: str,
    category: str,
    target_item: str,
):
    """
    발음 분석 전체 흐름을 담당하는 함수

    처리 순서:
    1. 이전 분석 결과 파일 삭제
    2. 사용자가 선택한 항목을 실제 목표 발음으로 변환
    3. 오디오 분석
    4. 입모양 분석
    5. Whisper 음성 인식
    6. 목표 발음과 인식 결과 비교
    7. 피드백 생성
    8. 최종 결과 JSON 저장
    9. 백엔드 응답용 dict 반환
    """

    # 이전 실행에서 생성된 임시 파일 및 결과 파일 삭제
    cleanup_previous_outputs()

    # 사용자가 선택한 자음/모음을 실제 분석 가능한 발음으로 변환
    target_pronunciation = get_target_pronunciation(
        category=category,
        target_item=target_item,
    )

    # 오디오 전처리 및 Librosa 기반 음성 분석 수행
    # 내부에서 오디오 추출, 무음 제거, 발화 구간 탐지, 음성 특징 분석을 수행
    audio_result = analyze_audio(
        video_path=video_path,
        target_pronunciation=target_pronunciation,
    )

    # 음성 발화 구간을 기준으로 입모양 분석 수행
    # lip_start_time, lip_end_time은 audio_module에서 계산되어 전달
    visual_result = analyze_lip(
        video_path=video_path,
        target_pronunciation=target_pronunciation,
        start_time=audio_result.get("lip_start_time", 0.0),
        end_time=audio_result.get("lip_end_time", 0.0),
    )

    # 무음 제거된 오디오 파일을 Whisper에 전달하여 음성 인식 수행
    whisper_result = recognize_speech(
        audio_path=audio_result["trimmed_audio_path"],
    )

    recognized_text = whisper_result.get("recognized_text", "")

    # Whisper 인식 결과가 목표 발음과 일치하는지 확인
    audio_match = check_target_match(
        recognized_text=recognized_text,
        target_char=target_pronunciation,
    )

    # 피드백 생성 시 사용할 수 있도록 오디오 분석 결과에 Whisper 결과 추가
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
        )

    # FastAPI를 통해 Flutter로 전달할 최종 응답 데이터
    return {
        "id": None,
        "user_id": None,

        "category": category,
        "target_item": target_item,
        "video_path": video_path,
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
    }