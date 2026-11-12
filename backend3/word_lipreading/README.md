# 한국어 입 모양 인식

## 설치 및 구성

처음 한 번 이 폴더에서 필요한 패키지를 설치하세요.

```powershell
py -m pip install -r requirements.txt
```

- `predict_video.py`: 기본 실행 진입점
- `predict_korean.py`: 일반 영상에서 입술 추출 및 결과 저장
- `korean_model.py`: 한국어 모델 로드 및 문장 예측
- `vendor/olkavs/`: 공식 모델 코드와 한국어 문자 목록
- `checkpoints/multiview_lip.pt`: 학습된 한국어 가중치
- `input_videos/`: 입력 영상
- `results/`: 영상별 결과
- `diagnostics/`: 검증 기록

모델 출처와 검증값은 [한국어 모델 안내](checkpoints/KOREAN_MODEL.md)에 있습니다.

## 일반 영상 파일 입력

1. 이 폴더의 `input_videos`에 영상을 넣습니다.
2. 이 폴더에서 `py predict_video.py`를 실행합니다.
3. `results` 아래 새 결과 폴더의 `result.txt`를 확인합니다.

```powershell
py predict_video.py
# 다른 위치의 영상 하나를 지정할 수도 있습니다.
py predict_video.py "D:\영상\sample.mp4"
```

한국어 입 모양 인식 모델을 사용하며, 6초 구간별로 한국어를 예측합니다.
입 모양을 기준으로 문장 경계를 찾는 기능은 아니므로 구간 경계에서 말이 끊길 수 있습니다.
음성은 사용하지 않습니다. 얼굴이 둘 이상이거나 검출이 부족한 구간은 건너뜁니다.
이미지 예시 `mouth_preview.jpg`로 입술 추출 상태도 확인할 수 있습니다.
출력은 실험용 예측이며 정확한 받아쓰기를 보장하지 않습니다.

한국어 모델의 모든 가중치가 일치하는지 검사했고 프로젝트 MP4에서 한국어 출력을 확인했습니다.
긴 영상은 구간별 처리해 메모리 사용을 제한합니다. 현재 CPU를 사용하므로 분석에 시간이 걸립니다.

특정 발화 구간만 분석하려면 다음과 같이 실행하세요.

```powershell
py predict_video.py "D:\영상\sample.mp4" --start 1.5 --end 7.2
```

한국어 코드는 `predict_korean.py`, `korean_model.py`, `vendor/olkavs`에 있습니다.
가중치는 `checkpoints/multiview_lip.pt`입니다. 이 폴더 전체를 함께 보관하세요.
입술 입력은 96×96 BGR, 30fps, 구간별 평균·표준편차 정규화입니다.
공개 preprocess.py의 기본 크기 224에서는 테스트 예측이 무너졌고,
공식 README의 96으로 변경한 뒤 발화와 겹치는 한국어 출력이 나타났습니다.
자동 MediaPipe 입술 영역은 원본 JSON의 경계 상자와 동일하지 않습니다.
모델의 학습 자료와 우리 영상의 중복 여부가 확인되지 않아 이 검사를 일반화 성능으로 볼 수 없습니다.

[실제 한국어 검사 결과](diagnostics/KOREAN_VALIDATION.md): 두 발화 중 하나는 마침표를
제외하고 정답과 일치했으며, 다른 하나는 일부 오인식이 있었습니다.


