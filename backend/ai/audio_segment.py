import librosa
import soundfile as sf

from ai.audio_features import analyze_audio_features


def find_speech_segment(
    audio_path,
    sr=16000,
    top_db=25,
    trimmed_path="trimmed_audio.wav",
):
    """
    오디오 파일에서 무음 구간을 제거하고,
    발화 시작 시간, 종료 시간, 음성 특징값을 반환한다.
    """

    audio, sr = librosa.load(audio_path, sr=sr, mono=True)

    trimmed_audio, index = librosa.effects.trim(audio, top_db=top_db)

    start_time = index[0] / sr
    end_time = index[1] / sr

    sf.write(trimmed_path, trimmed_audio, sr)

    audio_features = analyze_audio_features(
        trimmed_audio=trimmed_audio,
        sr=sr,
    )

    result = {
        "speech_start_time": round(start_time, 3),
        "speech_end_time": round(end_time, 3),
        "audio_path": audio_path,
        "trimmed_audio_path": trimmed_path,
    }

    result.update(audio_features)

    return result