from functools import lru_cache


@lru_cache(maxsize=1)
def _load_model():
    import whisper

    return whisper.load_model("small")


def transcribe_audio(audio_path):
    import librosa

    audio, _ = librosa.load(audio_path, sr=16000, mono=True)
    if not audio.any():
        return ""
    result = _load_model().transcribe(audio, language="ko", fp16=False)
    return result["text"].strip()
