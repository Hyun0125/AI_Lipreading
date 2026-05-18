import whisper
import re
from targets import TARGETS


def recognize_speech(audio_path="trimmed_audio.wav", model_size="small"):
    """
    Whisper를 이용하여 음성을 텍스트로 인식한다.
    기본 입력 파일은 무음 제거된 trimmed_audio.wav이다.
    """

    model = whisper.load_model(model_size)

    result = model.transcribe(
        audio_path,
        language="ko",
        fp16=False,
        temperature=0,
        condition_on_previous_text=False
    )

    text = result.get("text", "").strip()

    return {
        "recognized_text": text
    }


def normalize_text(text):
    """
    Whisper 인식 결과 비교를 위해
    공백과 특수문자를 제거한다.
    """

    if text is None:
        return ""

    text = text.replace(" ", "")
    text = re.sub(r"[^가-힣a-zA-Z0-9]", "", text)

    return text


def check_target_match(recognized_text, target_char):
    """
    Whisper 인식 결과가 목표 발음과 일치하는지 확인한다.
    targets.py의 audio_aliases를 기준으로 비교한다.
    """

    if target_char not in TARGETS:
        return False

    recognized_text = normalize_text(recognized_text)
    aliases = TARGETS[target_char]["audio_aliases"]

    for alias in aliases:
        alias = normalize_text(alias)

        if alias in recognized_text:
            return True

    return False