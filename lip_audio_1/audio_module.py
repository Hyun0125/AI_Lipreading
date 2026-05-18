import os
import numpy as np
import librosa
import soundfile as sf
from moviepy import VideoFileClip


def clamp_score(score):
    return max(0, min(100, score))


def extract_audio_from_video(video_path, audio_path="extracted_audio.wav"):
    """
    영상 파일에서 오디오를 추출하여 wav 파일로 저장
    """
    if os.path.exists(audio_path):
        return audio_path

    clip = VideoFileClip(video_path)

    if clip.audio is None:
        clip.close()
        raise ValueError("영상에 음성이 없습니다.")

    clip.audio.write_audiofile(audio_path, fps=16000)
    clip.close()

    return audio_path


def score_speed(duration, target_duration=1.0):
    """
    속도 평가
    한 글자 발음 기준으로 발화 시간이 너무 짧거나 길면 감점
    """
    score = 100 - abs(duration - target_duration) * 70
    return clamp_score(score)


def score_duration(duration, target_duration=1.0):
    """
    길이 평가
    발음이 기준 시간에 가깝게 유지되었는지 평가
    """
    score = 100 - abs(duration - target_duration) * 60
    return clamp_score(score)


def score_volume(volume, target_volume=0.05):
    """
    음량 평가
    평균 RMS 음량이 기준값에 가까울수록 높은 점수
    """
    score = 100 - abs(volume - target_volume) * 1000
    return clamp_score(score)


def score_stability(energy_std, target_std=0.02):
    """
    안정성 평가
    음성 에너지 변화량이 기준값에 가까울수록 안정적이라고 판단
    """
    score = 100 - abs(energy_std - target_std) * 1000
    return clamp_score(score)


def score_pitch(pitch_std, target_pitch_std=30):
    """
    높낮이 평가
    피치 변화량이 기준값에 가까울수록 높은 점수
    """
    if pitch_std is None or np.isnan(pitch_std):
        return 0

    score = 100 - abs(pitch_std - target_pitch_std) * 1.5
    return clamp_score(score)


def analyze_audio_features(trimmed_audio, sr):
    """
    무음 제거된 발화 구간 오디오를 분석하여
    속도, 길이, 안정성, 높낮이, 음량 점수를 계산
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
            "final_audio_score": 0
        }

    # 1. 발화 길이
    duration = len(trimmed_audio) / sr

    # 2. 음량, 안정성
    rms = librosa.feature.rms(y=trimmed_audio)[0]
    volume = float(np.mean(rms))
    energy_std = float(np.std(rms))

    # 3. 높낮이
    f0, voiced_flag, voiced_probs = librosa.pyin(
        trimmed_audio,
        fmin=librosa.note_to_hz("C2"),
        fmax=librosa.note_to_hz("C7")
    )

    if np.all(np.isnan(f0)):
        pitch_mean = 0
        pitch_std = 0
    else:
        pitch_mean = float(np.nanmean(f0))
        pitch_std = float(np.nanstd(f0))

    # 4. 항목별 점수
    speed_score = score_speed(duration)
    duration_score = score_duration(duration)
    stability_score = score_stability(energy_std)
    pitch_score = score_pitch(pitch_std)
    volume_score = score_volume(volume)

    # 5. 최종 음성 평가 점수
    final_audio_score = (
        speed_score * 0.22
        + duration_score * 0.22
        + stability_score * 0.22
        + pitch_score * 0.22
        + volume_score * 0.12
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
        "final_audio_score": round(final_audio_score, 2)
    }


def save_audio_score(result, output_path="audio_score.txt"):
    """
    Librosa 음성 분석 결과를 txt 파일로 저장
    """
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("=== Librosa 음성 분석 결과 ===\n")
        f.write(f"speech_start_time: {result['speech_start_time']}\n")
        f.write(f"speech_end_time: {result['speech_end_time']}\n")
        f.write(f"duration: {result['duration']}\n")
        f.write(f"volume: {result['volume']}\n")
        f.write(f"energy_std: {result['energy_std']}\n")
        f.write(f"pitch_mean: {result['pitch_mean']}\n")
        f.write(f"pitch_std: {result['pitch_std']}\n\n")

        f.write("=== 음성 평가 점수 ===\n")
        f.write(f"speed_score: {result['speed_score']}\n")
        f.write(f"duration_score: {result['duration_score']}\n")
        f.write(f"stability_score: {result['stability_score']}\n")
        f.write(f"pitch_score: {result['pitch_score']}\n")
        f.write(f"volume_score: {result['volume_score']}\n")
        f.write(f"final_audio_score: {result['final_audio_score']}\n")


def find_speech_segment(audio_path, sr=16000, top_db=25, trimmed_path="trimmed_audio.wav"):
    """
    Librosa를 이용하여 무음 구간을 제거하고,
    발화 시작/종료 시간과 음성 평가 점수를 계산
    """

    audio, sr = librosa.load(audio_path, sr=sr, mono=True)

    trimmed_audio, index = librosa.effects.trim(audio, top_db=top_db)

    start_time = index[0] / sr
    end_time = index[1] / sr

    # 무음 제거된 음성 저장
    sf.write(trimmed_path, trimmed_audio, sr)

    # 속도, 길이, 안정성, 높낮이, 음량 분석
    audio_features = analyze_audio_features(trimmed_audio, sr)

    result = {
        "speech_start_time": round(start_time, 3),
        "speech_end_time": round(end_time, 3),
        "audio_path": audio_path,
        "trimmed_audio_path": trimmed_path
    }

    result.update(audio_features)

    save_audio_score(result)

    return result


def find_speech_segment_from_video(video_path):
    """
    영상에서 오디오 추출 후,
    발화 구간 탐지와 음성 평가를 한 번에 수행
    """
    audio_path = extract_audio_from_video(video_path)
    return find_speech_segment(audio_path)