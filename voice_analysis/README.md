# 음성 분석 모듈

영상에서 음성을 추출하고 한국어 음성 인식, 기준 문장 비교, 음성 특성 분석과 그래프 생성을 수행합니다.
기존 백엔드 및 입 모양 분석과 독립적으로 사용할 수 있습니다.

프로젝트 폴더(`AI_Lipreading-main`, 이 폴더의 상위)에서 실행합니다.

```powershell
py -m pip install -r voice_analysis/requirements.txt
py -m voice_analysis.analyze "영상.mp4" --reference-text "안녕하세요" --output-dir outputs/voice-001
py -m unittest voice_analysis.test_text_comparison
```

다른 Python 코드에서 사용:

```python
from voice_analysis import analyze_video

result = analyze_video(
    "영상.mp4",
    output_dir="outputs/voice-001",
    media_base_url="/media/voice-001",
    reference_text="안녕하세요",
)
```

결과는 반환값과 `result.json`에 기록됩니다.

- `recognized_text`: 인식 문장
- `text_comparison`: 원문 일치, 정규화 일치, 문자 유사도, 차이 목록. 기준 문장이 없으면 `null`
- `audio_features`: 발화·무음 시간, 말하기 속도, 음량, 음높이, 쉼, 유성음 비율
- `graphs`: 음높이·주파수 배열과 그래프 URL
- `audio_url`: 추출한 음성 URL

출력 폴더에는 `audio.wav`, `spectrogram.png`, `frequency_graph.png`도 저장됩니다. 같은 출력 폴더를 재사용하면 덮어씁니다.
미디어 URL은 서버가 출력 폴더를 제공할 때 사용할 경로이며 이 모듈 자체는 HTTP 서버를 실행하지 않습니다.
문자 유사도는 인식된 텍스트의 비교 결과이며 발음 정확도 점수가 아닙니다.

최초 분석 시 Whisper small 모델을 다운로드하므로 인터넷 연결이 필요합니다. 이후 모델을 재사용합니다.
FFmpeg가 설치되어 있으면 사용하고, 없으면 `imageio-ffmpeg`의 실행 파일을 사용합니다.

## 이 PC에서 검증한 실행 환경

프로젝트 안의 `.venv-voice`에 분석 라이브러리를 설치했습니다. 프로젝트 폴더에서 실행:

```powershell
.\.venv-voice\Scripts\python.exe -m voice_analysis.analyze "영상.mp4" --reference-text "안녕하세요"
.\.venv-voice\Scripts\python.exe -m unittest voice_analysis.test_text_comparison voice_analysis.test_audio_features
```

2026-10-12 검증: 샘플 영상 전체 분석 성공, 테스트 8개 통과, 라이브러리 의존성 검사 통과.
결과는 `outputs/voice-validation`에 저장했습니다.
완전 무음이 발화로 계산되던 오류를 수정했고, 무음은 음성 인식을 건너뛰어 빈 문자열을 반환합니다.
샘플 기준 문장의 `임용`을 Whisper가 `이명`으로 인식했습니다. 텍스트 비교 결과는 음성 인식 오류의 영향을 받습니다.
발화 검출은 최대 음량 대비 임계값 방식이므로 배경 소음을 발화로 포함할 수 있습니다.
음량 dB는 디지털 오디오 진폭 기준이며 실제 환경의 소음계 측정값(dB SPL)이 아닙니다.

## 자음·모음 비교

`phoneme_comparison.py`는 기준 문장과 인식 문장의 한글을 초성(`initial`), 중성(`vowel`), 종성(`final`)으로 나눠 비교합니다.
음절 삽입·삭제를 고려해 문장을 정렬하고, 위치와 문자별 일치 횟수 및 차이 목록을 반환합니다.

```python
from voice_analysis import compare_phonemes

result = compare_phonemes("밥", "바")
print(result["mismatched_symbols"])  # 받침 ㅂ: 기대 1회, 일치 0회, 누락 1회
print(result["differences"])  # final / delete / expected: ㅂ
```

영상 분석에 `reference_text`를 전달하면 결과 JSON의 `phoneme_comparison`에도 자동으로 포함됩니다.
기준 문장이 없으면 `null`입니다.

- `overall`, `by_position`: 일치·교체·누락·추가 횟수와 유사도
- `symbols`: 기준에 나타난 문자별 기대 횟수, 일치 횟수, 차이 횟수, 일치율, 혼동된 문자
- `mismatched_symbols`: 기준 문자 중 일치하지 않은 사례가 있는 항목
- `differences`: 초성·모음·받침별 차이, 해당 음절, 정규화 문장 내 0부터 시작하는 위치

유사도는 `일치 / (일치 + 교체 + 누락 + 추가) × 100`입니다. 받침이 없는 자리끼리는 점수를 더하지 않습니다.
문자별 일치율은 `일치 횟수 / 기준에 나타난 횟수 × 100`입니다. 한글 비교 항목이 없으면 유사도는 `null`입니다.
비한글 문자 자체는 평가하지 않고, 겹받침·복합모음은 각각 하나의 표기 단위로 비교합니다.
중복 음절은 정렬 결과가 여러 개 가능하므로 위치는 추정입니다.

이 모듈은 **표기상 한글 구성 요소의 비교**입니다. 초성 ㅇ도 표기 단위로 계산하며 연음·동화·받침 발음 변화는 반영하지 않습니다.
따라서 차이가 난 문자는 재확인할 대상으로 사용해야 하며, 발음이 부족하다는 확정 판정으로 사용하면 안 됩니다.
실제 발음을 평가하려면 음성 자체의 음소 인식과 기준 발음 정렬이 추가로 필요합니다.

검증 명령:

```powershell
.\.venv-voice\Scripts\python.exe -m unittest voice_analysis.test_text_comparison voice_analysis.test_audio_features voice_analysis.test_phoneme_comparison
```

2026-10-12: 전체 18개 테스트 통과. 기존 샘플의 자음·모음 비교 결과는 `outputs/voice-validation/phoneme_comparison.json`에 저장했습니다.

## ETRI 한국어 발음 평가 API

공식 문서: https://epretx.etri.re.kr/apiDetail?id=98

`etri_pronunciation.py`를 추가했습니다. API 키를 환경 변수 `ETRI_API_KEY`에 설정하고 실행합니다.
키는 소스 코드에 넣거나 채팅에 공유하지 마세요.

```powershell
# ETRI에서 발급받은 키를 이 터미널의 ETRI_API_KEY 환경 변수에 설정한 뒤 실행
.\.venv-voice\Scripts\python.exe -m voice_analysis.analyze "영상.mp4" --reference-text "밥을 먹어요" --pronunciation-provider etri --output-dir outputs/etri-result
```

추출한 WAV만 평가할 수도 있습니다.

```python
from voice_analysis import assess_pronunciation

result = assess_pronunciation("outputs/voice-validation/audio.wav", "기준 문장")
print(result["score"])  # 공식 문서 기준 1~5점
```

ETRI를 선택하면 녹음 음성과 기준 문장이 외부 서버로 전송됩니다.
문서의 호출 주소는 HTTP입니다. 확인된 HTTPS 주소가 있는 경우 `ETRI_PRONUNCIATION_URL` 환경 변수로 지정할 수 있습니다.
16 kHz, 16-bit, mono PCM WAV를 검증하고, 0초·60초 초과·완전 무음 파일은 호출 전에 거부합니다.
공개 문서에는 오디오 컨테이너와 헤더 처리가 명확하지 않아 기본값은 WAV 파일 전체의 Base64입니다.
서버가 헤더 없는 PCM을 요구하는 것으로 확인되면 `--etri-audio-format pcm` 또는 `audio_format="pcm"`을 사용하세요.
파일 형식에 따른 실제 서버 수용 여부는 API 키를 이용한 호출로 추가 검증해야 합니다. 자동 재호출은 하지 않습니다.

결과 JSON의 `pronunciation_assessment`에 문장 발음 점수를 저장합니다. ETRI를 선택하지 않으면 `null`입니다.
ETRI 사용 시 문장·자음·모음 비교는 ETRI 인식 문장을 사용하고 Whisper는 호출하지 않습니다.
문서가 제공하는 점수는 문장 전체에 대한 값이며 개별 자음·모음 점수는 제공된 것으로 가정하지 않습니다.
`phoneme_scores`는 `null`이고, 낮은 점수로 특정 자음의 결함이나 발음 장애를 판정하지 않습니다.

```powershell
.\.venv-voice\Scripts\python.exe -m unittest voice_analysis.test_text_comparison voice_analysis.test_audio_features voice_analysis.test_phoneme_comparison voice_analysis.test_etri_pronunciation
```

요청 구성·응답·오류 처리와 영상 분석 연결은 모의 응답으로 검증합니다. 실제 API 점수의 품질과 자격 증명은 별도 검증이 필요합니다.

2026-10-12 실제 API 호출 검증 완료: 샘플의 16 kHz mono WAV 파일 전체를 전송하여 성공 응답을 받았습니다.
발음 점수는 3.578604/5였으며, 인식 문장은 `혼자 임용시험 준비를 하려니 너무 외로워`였습니다.
결과 파일: `outputs/voice-validation/etri_validation.json`. 이 샘플에서는 WAV 형식이 수용되어 PCM 재호출은 하지 않았습니다.
실행 환경의 네트워크 제한 및 SSLKEYLOGFILE 설정 충돌을 피한 별도 검증 프로세스에서 호출했습니다.
이 검증은 통신·응답 처리의 성공을 확인한 것이며, 점수의 정확성이나 개별 음소 판정의 검증은 아닙니다.
