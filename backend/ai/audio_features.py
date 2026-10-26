import numpy as np
import librosa

from ai.audio_score import (
    score_speed,
    score_duration,
    score_stability,
    score_pitch,
    score_volume,
    calculate_final_audio_score,
)


def analyze_audio_features(trimmed_audio, sr):
    """
    무음 제거된 발화 구간 오디오를 분석하여
    길이, 음량, 에너지 변화량, 피치, 음성 점수를 계산한다.
    """

    if len(trimmed_audio) == 0:
        return {
            "duration": 0,
            "volume": 0,
            "energy_std": 0,
            "pitch_mean": 0,
            "pitch_std": 0,
            "speed_score": 0,
            "duration_score": 0,
            "stability_score": 0,
            "pitch_score": 0,
            "volume_score": 0,
            "final_audio_score": 0,
        }

    duration = len(trimmed_audio) / sr

    rms = librosa.feature.rms(y=trimmed_audio)[0]
    volume = float(np.mean(rms))
    energy_std = float(np.std(rms))

    # 음량이 거의 없으면 발화하지 않은 것으로 판단
    # volume == 0만 검사하면 작은 잡음이 있는 무음은 걸러지지 않으므로 threshold 사용
    silence_threshold = 0.005

    if volume <= silence_threshold:
        return {
            "duration": round(duration, 3),
            "volume": round(volume, 5),
            "energy_std": round(energy_std, 5),
            "pitch_mean": 0,
            "pitch_std": 0,
            "speed_score": 0,
            "duration_score": 0,
            "stability_score": 0,
            "pitch_score": 0,
            "volume_score": 0,
            "final_audio_score": 0,
        }

    f0, voiced_flag, voiced_probs = librosa.pyin(
        trimmed_audio,
        fmin=librosa.note_to_hz("C2"),
        fmax=librosa.note_to_hz("C7"),
    )

    if np.all(np.isnan(f0)):
        pitch_mean = 0
        pitch_std = 0
    else:
        pitch_mean = float(np.nanmean(f0))
        pitch_std = float(np.nanstd(f0))

    speed_score = score_speed(duration)
    duration_score = score_duration(duration)
    stability_score = score_stability(energy_std)
    pitch_score = score_pitch(pitch_std)
    volume_score = score_volume(volume)

    final_audio_score = calculate_final_audio_score(
        speed_score=speed_score,
        duration_score=duration_score,
        stability_score=stability_score,
        pitch_score=pitch_score,
        volume_score=volume_score,
    )

    return {
        "duration": round(duration, 3),
        "volume": round(volume, 5),
        "energy_std": round(energy_std, 5),
        "pitch_mean": round(pitch_mean, 2),
        "pitch_std": round(pitch_std, 2),
        "speed_score": round(speed_score, 2),
        "duration_score": round(duration_score, 2),
        "stability_score": round(stability_score, 2),
        "pitch_score": round(pitch_score, 2),
        "volume_score": round(volume_score, 2),
        "final_audio_score": round(final_audio_score, 2),
    }