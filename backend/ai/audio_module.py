from ai.audio_extractor import extract_audio_from_video
from ai.audio_segment import find_speech_segment


def find_speech_segment_from_video(video_path):
    """
    영상에서 오디오를 추출한 뒤,
    발화 구간 탐지와 음성 특징 분석을 수행한다.

    main_pipeline.py, target_builder.py에서 사용하는 함수이므로
    기존 함수명을 유지한다.
    """

    audio_path = extract_audio_from_video(video_path)
    return find_speech_segment(audio_path)


def analyze_audio(video_path: str, target_pronunciation: str = ""):
    """
    FastAPI 연결용 오디오 분석 wrapper 함수.

    오디오 추출, 무음 제거, 발화 구간 탐지 결과를
    analyze.py에서 바로 사용할 수 있는 형태로 정리한다.
    """

    result = find_speech_segment_from_video(video_path)

    speech_start_time = result.get("speech_start_time", 0.0)
    speech_end_time = result.get("speech_end_time", 0.0)

    lip_start_time = max(speech_start_time - 0.5, 0.0)
    lip_end_time = speech_end_time + 0.5

    return {
        "whisper_result": "",
        "is_correct": False,

        "speech_start_time": speech_start_time,
        "speech_end_time": speech_end_time,
        "speech_duration": result.get("duration", 0.0),

        "lip_start_time": lip_start_time,
        "lip_end_time": lip_end_time,

        "volume": result.get("volume", 0.0),
        "energy_change": result.get("energy_std", 0.0),
        "average_pitch": result.get("pitch_mean", 0.0),
        "pitch_change": result.get("pitch_std", 0.0),

        "speed_score": result.get("speed_score", 0.0),
        "duration_score": result.get("duration_score", 0.0),
        "stability_score": result.get("stability_score", 0.0),
        "pitch_score": result.get("pitch_score", 0.0),
        "volume_score": result.get("volume_score", 0.0),
        "audio_total_score": result.get("final_audio_score", 0.0),

        "audio_path": result.get("audio_path", "extracted_audio.wav"),
        "trimmed_audio_path": result.get("trimmed_audio_path", "trimmed_audio.wav"),
    }