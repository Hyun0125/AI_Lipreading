# 한국어 OLKAVS 모델

- 출처: https://github.com/IIP-Sogang/olkavs-avspeech
- 코드 커밋: af2feda3e3ac91ff3fef2454fcee662366ce9f4b
- 공식 배포 파일: https://drive.google.com/file/d/1nFLZHVwKgYrds-JJbFDJPlu5DJ1jeubC/view
- 로컬 파일: multiview_lip.pt (304,202,492 bytes)
- SHA256: f41d742380af11b72f9cafe178cd59d0a9016c02f5a976145f5f7595d44326a5
- 확인 날짜: 2026-11-02

영상 전용 45,191,824개 파라미터 모델. 72개 자모·특수 기호를 출력합니다.
torch.load(weights_only=True)로 읽고 모든 1,221개 state_dict 항목을 strict=True로 검증했습니다.
음성 또는 외부 음성 인식 서비스는 사용하지 않습니다.
공식 hybrid decoder와 ctc_rate=0.6을 사용합니다.
CPU 메모리 절감을 위해 영상 전단만 16프레임씩 처리하며 앞뒤 2프레임을 포함합니다.
21프레임 입력의 전체 처리와 분할 처리 출력 차이가 0인 것을 확인했습니다.

코드의 이용 조건은 vendor/olkavs/README.md의 License 안내(MIT),
데이터는 연결된 AI Hub 이용 조건을 참고하세요. 가중치의 상업적 사용 허용 여부를
별도로 확인한 것은 아닙니다.
