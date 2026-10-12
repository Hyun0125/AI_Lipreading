import librosa
import numpy as np
import re
from pathlib import Path
from .audio_graphs import save_frequency_graphs, build_graph_data, save_spectrogram


def count_korean_syllables(text):
    """
    한글 완성형 음절 수 계산
    예: 안녕하세요 -> 5음절
    """
    return len(re.findall(r"[가-힣]", text))


def analyze_audio_features(audio_path, recognized_text="", *, graph_data=None, output_dir="."):
    y, sr = librosa.load(audio_path, sr=None, mono=True)

    if len(y) == 0:
        raise ValueError("오디오 데이터가 비어 있습니다.")

    # =========================================================
    # 1. 전체 길이
    # =========================================================
    duration = librosa.get_duration(y=y, sr=sr)

    # =========================================================
    # 2. 실제 발화 구간 검출
    # =========================================================
    # top_db가 클수록 더 작은 소리까지 발화로 포함
    # Relative-to-peak detection labels even an all-zero signal as speech.
    intervals = (
        librosa.effects.split(y, top_db=30)
        if np.any(y)
        else np.empty((0, 2), dtype=int)
    )

    speech_duration = 0.0

    for start, end in intervals:
        speech_duration += (end - start) / sr

    silence_duration = max(duration - speech_duration, 0)

    silence_ratio = (
        silence_duration / duration * 100
        if duration > 0
        else 0
    )

    speech_ratio = (
        speech_duration / duration * 100
        if duration > 0
        else 0
    )

    # =========================================================
    # 3. 쉼 분석
    # =========================================================
    pauses = []

    if len(intervals) >= 2:
        for i in range(len(intervals) - 1):
            current_end = intervals[i][1]
            next_start = intervals[i + 1][0]

            pause_duration = (next_start - current_end) / sr

            # 0.15초 이상만 의미 있는 쉼으로 판단
            if pause_duration >= 0.15:
                pauses.append(pause_duration)

    pause_count = len(pauses)

    average_pause = (
        float(np.mean(pauses))
        if pauses
        else 0.0
    )

    max_pause = (
        float(np.max(pauses))
        if pauses
        else 0.0
    )

    total_pause = float(np.sum(pauses)) if pauses else 0.0

    # =========================================================
    # 4. 음량 분석
    # =========================================================
    rms = librosa.feature.rms(y=y)[0]

    # 0 방지
    rms_safe = np.maximum(rms, 1e-10)

    rms_db = librosa.amplitude_to_db(
        rms_safe,
        ref=1.0
    )

    mean_volume_db = float(np.mean(rms_db))
    min_volume_db = float(np.min(rms_db))
    max_volume_db = float(np.max(rms_db))

    volume_range_db = max_volume_db - min_volume_db
    volume_std_db = float(np.std(rms_db))

    # =========================================================
    # 5. 음높이(F0) 분석
    # =========================================================
    f0, voiced_flag, voiced_prob = librosa.pyin(
        y,
        fmin=librosa.note_to_hz("C2"),
        fmax=librosa.note_to_hz("C7"),
        sr=sr
    )

    output_dir = Path(output_dir)
    save_frequency_graphs(y, sr, f0, output_dir / 'frequency_graph.png')
    if graph_data is not None:
        graph_data.update(build_graph_data(y, sr, f0))
        save_spectrogram(y, sr, output_dir / 'spectrogram.png')

    valid_f0 = f0[~np.isnan(f0)]

    if len(valid_f0) > 0:
        mean_pitch = float(np.mean(valid_f0))
        median_pitch = float(np.median(valid_f0))
        min_pitch = float(np.min(valid_f0))
        max_pitch = float(np.max(valid_f0))

        pitch_range = max_pitch - min_pitch
        pitch_std = float(np.std(valid_f0))

        pitch_cv = (
            pitch_std / mean_pitch * 100
            if mean_pitch > 0
            else 0
        )

        # Hz 범위보다 사람의 음높이 변화 체감에 가까운 반음 범위
        pitch_range_semitones = (
            12 * np.log2(max_pitch / min_pitch)
            if min_pitch > 0
            else 0
        )

    else:
        mean_pitch = None
        median_pitch = None
        min_pitch = None
        max_pitch = None
        pitch_range = None
        pitch_std = None
        pitch_cv = None
        pitch_range_semitones = None

    # =========================================================
    # 6. 유성음 비율
    # =========================================================
    if voiced_flag is not None and len(voiced_flag) > 0:
        voiced_ratio = (
            np.sum(voiced_flag) /
            len(voiced_flag) *
            100
        )
    else:
        voiced_ratio = 0

    # =========================================================
    # 7. 말하기 속도
    # =========================================================
    syllable_count = count_korean_syllables(recognized_text)

    words = recognized_text.split()
    word_count = len(words)

    if speech_duration > 0:
        syllables_per_second = (
            syllable_count / speech_duration
        )

        words_per_minute = (
            word_count / speech_duration * 60
        )

    else:
        syllables_per_second = 0
        words_per_minute = 0

    # 전체 영상 길이를 기준으로 한 속도도 따로 계산
    if duration > 0:
        syllables_per_total_second = (
            syllable_count / duration
        )
    else:
        syllables_per_total_second = 0

    # =========================================================
    # 결과
    # =========================================================
    return {

        "duration": {
            "total_sec": round(float(duration), 2),
            "speech_sec": round(float(speech_duration), 2),
            "silence_sec": round(float(silence_duration), 2),
            "speech_ratio_percent": round(float(speech_ratio), 2),
            "silence_ratio_percent": round(float(silence_ratio), 2)
        },

        "speech_rate": {
            "syllable_count": syllable_count,
            "word_count": word_count,

            "syllables_per_second": round(
                float(syllables_per_second), 2
            ),

            "syllables_per_total_second": round(
                float(syllables_per_total_second), 2
            ),

            "words_per_minute": round(
                float(words_per_minute), 2
            )
        },

        "volume": {
            "mean_db": round(mean_volume_db, 2),
            "min_db": round(min_volume_db, 2),
            "max_db": round(max_volume_db, 2),
            "range_db": round(volume_range_db, 2),
            "std_db": round(volume_std_db, 2)
        },

        "pitch": {
            "mean_hz": (
                round(mean_pitch, 2)
                if mean_pitch is not None
                else None
            ),

            "median_hz": (
                round(median_pitch, 2)
                if median_pitch is not None
                else None
            ),

            "min_hz": (
                round(min_pitch, 2)
                if min_pitch is not None
                else None
            ),

            "max_hz": (
                round(max_pitch, 2)
                if max_pitch is not None
                else None
            ),

            "range_hz": (
                round(pitch_range, 2)
                if pitch_range is not None
                else None
            ),

            "std_hz": (
                round(pitch_std, 2)
                if pitch_std is not None
                else None
            ),

            "variation_percent": (
                round(pitch_cv, 2)
                if pitch_cv is not None
                else None
            ),

            "range_semitones": (
                round(float(pitch_range_semitones), 2)
                if pitch_range_semitones is not None
                else None
            )
        },

        "pause": {
            "count": pause_count,
            "total_sec": round(total_pause, 2),
            "average_sec": round(average_pause, 2),
            "max_sec": round(max_pause, 2)
        },

        "voice": {
            "voiced_ratio_percent": round(
                float(voiced_ratio), 2
            )
        }
    }
