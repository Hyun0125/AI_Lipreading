import whisper
import re
from ai.targets import TARGETS



_MODEL_CACHE = {}


def get_whisper_model(model_size="small"):
    """
    Whisper 모델을 불러오는 함수.

    동일한 크기의 모델이 이미 로드되어 있으면
    새로 불러오지 않고 캐시에 저장된 모델을 반환한다.
    """

    if model_size not in _MODEL_CACHE:
        _MODEL_CACHE[model_size] = whisper.load_model(model_size)

    return _MODEL_CACHE[model_size]


def recognize_speech(audio_path="trimmed_audio.wav", model_size="small"):
    """
    Whisper를 이용하여 음성을 텍스트로 인식한다.

    입력:
    - audio_path: 음성 인식에 사용할 오디오 파일 경로
    - model_size: 사용할 Whisper 모델 크기

    기본 입력 파일은 audio_segment.py에서 무음 제거 후 생성한
    trimmed_audio.wav 파일이다.
    """

    # Whisper 모델 로드
    model = get_whisper_model(model_size)

    # 한국어 음성 인식 수행
    # fp16=False는 CPU 환경에서도 동작하도록 설정한 값이다.
    result = model.transcribe(
        audio_path,
        language="ko",
        fp16=False,
        temperature=0,
        condition_on_previous_text=False
    )

    # Whisper 결과 중 인식된 텍스트만 추출
    text = result.get("text", "").strip()

    return {
        "recognized_text": text
    }


def normalize_text(text):
    """
    음성 인식 결과와 목표 발음을 비교하기 위해 문자열을 정리한다.

    처리 내용:
    - None 값은 빈 문자열로 변환
    - 공백 제거
    - 한글, 영문, 숫자를 제외한 특수문자 제거
    """

    if text is None:
        return ""

    text = text.replace(" ", "")
    text = re.sub(r"[^가-힣a-zA-Z0-9]", "", text)

    return text


def check_target_match(recognized_text, target_char):
    """
    Whisper 인식 결과가 목표 발음과 일치하는지 확인한다.

    targets.py에 정의된 audio_aliases를 기준으로 비교한다.
    예를 들어 목표 발음이 '아'이면,
    인식 결과 안에 '아'가 포함되어 있는지 확인한다.
    """

    # 지원하지 않는 목표 발음이면 일치하지 않는 것으로 처리
    if target_char not in TARGETS:
        return False

    # Whisper 인식 결과 정규화
    recognized_text = normalize_text(recognized_text)

    # 목표 발음에 대해 허용된 발음 표현 목록 가져오기
    aliases = TARGETS[target_char]["audio_aliases"]

    # 인식 결과 안에 허용 표현이 포함되어 있으면 일치로 판단
    for alias in aliases:
        alias = normalize_text(alias)

        if alias in recognized_text:
            return True

    return False