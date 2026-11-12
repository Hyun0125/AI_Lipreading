"""Whisper transcription for SENTENCE voice analysis only.

The jamo path uses ``ai/whisper_module.py`` and is not affected.
An empty transcription means no reliable sentence recognition; the Flutter
report presents the same friendly message for that case.
"""

from functools import lru_cache
import re

import numpy as np


@lru_cache(maxsize=1)
def _load_model():
    import whisper

    return whisper.load_model("small")


def _is_effectively_silent(audio):
    """Conservative absolute-level check; relative VAD mislabels room noise.

    A weak recording containing speech is preserved whenever its louder frames
    exceed the absolute threshold. Thresholds are empirical and adjustable.
    """
    if len(audio) == 0:
        return True
    absolute = np.abs(audio)
    rms = float(np.sqrt(np.mean(audio.astype(np.float64) ** 2)))
    p99 = float(np.percentile(absolute, 99))
    return rms < 0.0025 and p99 < 0.009


def _is_unreliable_transcript(text, audio_seconds, segments):
    if not text:
        return True

    # Whisper may hallucinate extremely long repetitions in near-silent clips.
    if re.search(r"([가-힣ㄱ-ㅎㅏ-ㅣ])\1{5,}", text):
        return True
    compact = re.sub(r"\s+", "", text)
    if len(compact) > max(40, int(audio_seconds * 11)):
        return True

    # This task uses Korean sentences. Foreign-only / largely foreign output
    # (e.g. Chinese + Latin words + emoji) is not a usable transcription.
    korean = sum("가" <= ch <= "힣" for ch in text)
    non_korean_letters = sum(
        ch.isalpha() and not ("가" <= ch <= "힣")
        and not ("ㄱ" <= ch <= "ㅎ") and not ("ㅏ" <= ch <= "ㅣ")
        for ch in text
    )
    if korean == 0 or non_korean_letters > korean:
        return True

    # Reject only segments that strongly indicate no speech AND low confidence.
    # Being different from the reference sentence is NOT a failure criterion.
    if segments and all(
        segment.get("no_speech_prob", 0) >= 0.6
        and segment.get("avg_logprob", 0) < -1.0
        for segment in segments
    ):
        return True
    return False


def transcribe_audio(audio_path):
    import librosa

    audio, _ = librosa.load(audio_path, sr=16000, mono=True)
    if _is_effectively_silent(audio):
        return ""

    result = _load_model().transcribe(audio, language="ko", fp16=False)
    text = str(result.get("text") or "").strip()
    if _is_unreliable_transcript(text, len(audio) / 16000.0, result.get("segments") or []):
        return ""
    return text
