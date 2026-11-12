import numpy as np


def clamp_score(score):
    return max(0, min(100, score))


def score_speed(duration, target_duration=1.0):
    """
    발음 속도 평가
    """
    score = 100 - abs(duration - target_duration) * 70
    return clamp_score(score)


def score_duration(duration, target_duration=1.0):
    """
    발화 길이 평가
    """
    score = 100 - abs(duration - target_duration) * 60
    return clamp_score(score)


def score_volume(volume, target_volume=0.05):
    """
    음량 평가
    """
    score = 100 - abs(volume - target_volume) * 1000
    return clamp_score(score)


def score_stability(energy_std, target_std=0.02):
    """
    발화 안정성 평가
    """
    score = 100 - abs(energy_std - target_std) * 1000
    return clamp_score(score)


def score_pitch(pitch_std, target_pitch_std=30):
    """
    높낮이 평가
    """
    if pitch_std is None or np.isnan(pitch_std):
        return 0

    score = 100 - abs(pitch_std - target_pitch_std) * 1.5
    return clamp_score(score)


def calculate_final_audio_score(
    speed_score,
    duration_score,
    stability_score,
    pitch_score,
    volume_score,
):
    """
    최종 음성 점수 계산
    """
    return (
        speed_score * 0.22
        + duration_score * 0.22
        + stability_score * 0.22
        + pitch_score * 0.22
        + volume_score * 0.12
    )