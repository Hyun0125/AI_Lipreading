from datetime import datetime


def get_target_pronunciation(category: str, target_item: str):
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

    if category == "자음":
        return consonant_practice_map.get(target_item, target_item)

    return target_item


def analyze_pronunciation(
    video_path: str,
    category: str,
    target_item: str,
):
    target_pronunciation = get_target_pronunciation(
        category=category,
        target_item=target_item,
    )

    audio_feedback = (
        f"{target_pronunciation} 발음 음성이 정상적으로 업로드되었습니다. "
        f"현재는 임시 음성 피드백입니다. 이후 Whisper 분석 결과로 대체됩니다."
    )

    visual_feedback = (
        f"{target_pronunciation} 발음 영상이 정상적으로 업로드되었습니다. "
        f"현재는 임시 영상 피드백입니다. 이후 MediaPipe 입 모양 분석 결과로 대체됩니다."
    )

    audio_score = 80.0
    visual_score = 75.0

    return {
        "id": None,
        "user_id": None,

        "category": category,
        "target_item": target_item,
        "video_path": video_path,
        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),

        "target_pronunciation": target_pronunciation,
        "whisper_result": "",
        "is_correct": False,

        "speech_start_time": 0.0,
        "speech_end_time": 0.0,
        "speech_duration": 0.0,
        "volume": 0.0,
        "energy_change": 0.0,
        "average_pitch": 0.0,
        "pitch_change": 0.0,

        "speed_score": 0.0,
        "duration_score": 0.0,
        "stability_score": 0.0,
        "pitch_score": 0.0,
        "volume_score": 0.0,
        "audio_total_score": audio_score,

        "average_mouth_open_ratio": 0.0,
        "max_mouth_open_ratio": 0.0,
        "min_mouth_open_ratio": 0.0,
        "lip_movement_change": 0.0,
        "average_mouth_open_score": 0.0,
        "max_mouth_open_score": 0.0,
        "lip_movement_score": 0.0,
        "visual_total_score": visual_score,

        "feedbacks": [
            audio_feedback,
            visual_feedback,
        ],
    }