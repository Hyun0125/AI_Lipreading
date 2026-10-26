import json


def save_lip_score(lip_result, output_path="lip_score.json"):
    """
    입모양 점수 결과를 lip_score.json으로 저장한다.
    main_pipeline.py 같은 로컬 테스트용에서 사용할 수 있다.
    """

    data = {
        "target_pronunciation": lip_result["target_char"],
        "avg_mouth_open_ratio": round(lip_result["avg_ratio"], 4),
        "max_mouth_open_ratio": round(lip_result["max_ratio"], 4),
        "min_mouth_open_ratio": round(lip_result["min_ratio"], 4),
        "mouth_movement_range": round(lip_result["movement_range"], 4),
        "avg_mouth_score": round(lip_result["avg_score"], 2),
        "max_mouth_score": round(lip_result["max_score"], 2),
        "mouth_movement_score": round(lip_result["movement_score"], 2),
        "lip_total_score": round(lip_result["final_score"], 2),
        "is_lip_failed": (
            lip_result["avg_score"] == 0
            and lip_result["max_score"] == 0
            and lip_result["movement_score"] == 0
            and lip_result["final_score"] == 0
        ),
    }

    if "error" in lip_result:
        data["error"] = lip_result["error"]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=4)

    return output_path


def convert_audio_result_for_save(audio_result):
    """
    analyze.py에서 받은 audio_result를
    final_result.json 저장 형식에 맞게 변환한다.

    """

    return {
        "speech_start_time": audio_result.get("speech_start_time", 0.0),
        "speech_end_time": audio_result.get("speech_end_time", 0.0),
        "duration": audio_result.get("speech_duration", 0.0),

        "volume": audio_result.get("volume", 0.0),
        "energy_std": audio_result.get("energy_change", 0.0),
        "pitch_mean": audio_result.get("average_pitch", 0.0),
        "pitch_std": audio_result.get("pitch_change", 0.0),

        "speed_score": audio_result.get("speed_score", 0.0),
        "duration_score": audio_result.get("duration_score", 0.0),
        "stability_score": audio_result.get("stability_score", 0.0),
        "pitch_score": audio_result.get("pitch_score", 0.0),
        "volume_score": audio_result.get("volume_score", 0.0),
        "final_audio_score": audio_result.get("audio_total_score", 0.0),
    }


def save_final_result(
    target_char,
    audio_result,
    lip_result,
    whisper_result,
    audio_match,
    feedback,
    video_path=None,
    video_result=None,
    lip_failed=False,
    output_path="final_result.json",
):
    """
    전체 분석 결과를 final_result.json으로 저장한다.
    """

    result = {
        "target_pronunciation": target_char,
        "input_video": video_path,
        "whisper_result": whisper_result["recognized_text"],
        "is_correct": audio_match,

        "speech_start_time": audio_result["speech_start_time"],
        "speech_end_time": audio_result["speech_end_time"],
        "speech_duration": audio_result["duration"],
        "volume": audio_result["volume"],
        "energy_change": audio_result["energy_std"],
        "average_pitch": audio_result["pitch_mean"],
        "pitch_change": audio_result["pitch_std"],

        "speed_score": audio_result["speed_score"],
        "duration_score": audio_result["duration_score"],
        "stability_score": audio_result["stability_score"],
        "pitch_score": audio_result["pitch_score"],
        "volume_score": audio_result["volume_score"],
        "audio_total_score": audio_result["final_audio_score"],

        "avg_mouth_open_ratio": round(lip_result["avg_ratio"], 4),
        "max_mouth_open_ratio": round(lip_result["max_ratio"], 4),
        "min_mouth_open_ratio": round(lip_result["min_ratio"], 4),
        "mouth_movement_range": round(lip_result["movement_range"], 4),

        "avg_mouth_score": round(lip_result["avg_score"], 2),
        "max_mouth_score": round(lip_result["max_score"], 2),
        "mouth_movement_score": round(lip_result["movement_score"], 2),
        "lip_total_score": round(lip_result["final_score"], 2),

        "is_lip_failed": lip_failed,
        "feedback": feedback,
    }

    if video_result is not None:
        result["video_analysis"] = {
            "fps": video_result["fps"],
            "total_frames": video_result["total_frames"],
            "start_frame": video_result["start_frame"],
            "end_frame": video_result["end_frame"],
            "success_frame_count": video_result["success_frame_count"],
            "failed_frame_count": video_result["failed_frame_count"],
        }

    if "error" in lip_result:
        result["lip_error"] = lip_result["error"]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=4)

    return output_path