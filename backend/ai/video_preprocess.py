import cv2
import mediapipe as mp
import numpy as np
import os
import shutil


# MediaPipe FaceMesh 모듈 사용
mp_face_mesh = mp.solutions.face_mesh

# MediaPipe FaceMesh에서 입술에 해당하는 랜드마크 번호 목록
# 이 좌표들을 이용하여 입술 영역 crop, 대표 좌표, 입 벌림 비율을 계산한다.
LIPS = [
    61, 185, 40, 39, 37, 0, 267, 269, 270, 409,
    291, 375, 321, 405, 314, 17, 84, 181, 91, 146
]


def get_lip_crop_and_landmarks(frame, face_mesh, image_size=(96, 96)):
    """
    한 프레임에서 얼굴을 검출하고, 입술 영역과 입술 랜드마크를 추출한다.

    반환값:
    - lip_crop_resized: 입술 영역을 잘라 96x96 크기로 변환한 이미지
    - debug: 랜드마크와 bounding box가 표시된 확인용 이미지
    - points: 입술 랜드마크 좌표 배열
    - features: 대표 좌표 및 입 벌림 비율 정보
    """

    # OpenCV는 BGR 형식이므로 MediaPipe 입력을 위해 RGB로 변환
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # FaceMesh를 이용하여 얼굴 랜드마크 추출
    results = face_mesh.process(rgb)

    # 얼굴이 검출되지 않으면 실패 처리
    if not results.multi_face_landmarks:
        return None, None, None, None

    h, w, _ = frame.shape
    face_landmarks = results.multi_face_landmarks[0]

    points = []

    # 입술에 해당하는 랜드마크 좌표만 추출
    for idx in LIPS:
        lm = face_landmarks.landmark[idx]
        x = int(lm.x * w)
        y = int(lm.y * h)
        points.append([x, y])

    points = np.array(points, dtype=np.int32)

    # 입술 랜드마크의 최소/최대 좌표를 이용해 입술 영역의 bounding box 계산
    x_min = np.min(points[:, 0])
    x_max = np.max(points[:, 0])
    y_min = np.min(points[:, 1])
    y_max = np.max(points[:, 1])

    lip_w = x_max - x_min
    lip_h = y_max - y_min

    # 입술이 잘리지 않도록 좌우/상하 padding 추가
    pad_x = int(lip_w * 0.20)
    pad_top = int(lip_h * 0.30)
    pad_bottom = int(lip_h * 0.25)

    # 이미지 범위를 벗어나지 않도록 crop 좌표 보정
    x1 = max(x_min - pad_x, 0)
    y1 = max(y_min - pad_top, 0)
    x2 = min(x_max + pad_x, w)
    y2 = min(y_max + pad_bottom, h)

    # 입술 영역 crop
    lip_crop = frame[y1:y2, x1:x2]

    # crop된 영역이 비어 있으면 실패 처리
    if lip_crop.size == 0:
        return None, None, None, None

    # 모델 입력 또는 저장을 위해 입술 이미지를 고정 크기로 변환
    lip_crop_resized = cv2.resize(lip_crop, image_size)

    # 확인용 debug 이미지 생성
    debug = frame.copy()

    # 전체 입술 랜드마크 표시
    for x, y in points:
        cv2.circle(debug, (x, y), 3, (0, 255, 0), -1)

    # 입술의 좌/우/상/하 대표 좌표 계산
    left_point = points[np.argmin(points[:, 0])]
    right_point = points[np.argmax(points[:, 0])]
    top_point = points[np.argmin(points[:, 1])]
    bottom_point = points[np.argmax(points[:, 1])]

    # 대표 좌표를 debug 이미지에 표시
    cv2.circle(debug, tuple(left_point), 6, (0, 0, 255), -1)
    cv2.circle(debug, tuple(right_point), 6, (0, 0, 255), -1)
    cv2.circle(debug, tuple(top_point), 6, (255, 0, 255), -1)
    cv2.circle(debug, tuple(bottom_point), 6, (255, 0, 255), -1)

    # 입술 crop 영역 표시
    cv2.rectangle(debug, (x1, y1), (x2, y2), (255, 0, 0), 2)

    # 입 너비, 입 높이, 입 벌림 비율 계산
    mouth_width = int(right_point[0] - left_point[0])
    mouth_height = int(bottom_point[1] - top_point[1])
    openness_ratio = mouth_height / mouth_width if mouth_width != 0 else 0

    # 후속 입모양 분석에 사용할 특징값
    features = {
        "left": left_point,
        "right": right_point,
        "top": top_point,
        "bottom": bottom_point,
        "mouth_width": mouth_width,
        "mouth_height": mouth_height,
        "openness_ratio": openness_ratio
    }

    return lip_crop_resized, debug, points, features


def process_video_by_time(
    video_path: str,
    start_time: float,
    end_time: float,
    output_dir: str = "speech_lip_frames",
    image_size=(96, 96)
):
    """
    지정한 시간 구간의 영상 프레임을 읽어 입술 영역과 랜드마크를 추출한다.

    처리 과정:
    1. 출력 폴더 초기화
    2. 영상 파일 열기
    3. start_time ~ end_time 구간을 프레임 번호로 변환
    4. 각 프레임에서 입술 crop 및 랜드마크 추출
    5. 성공/실패 프레임 기록
    6. 입술 이미지, debug 이미지, landmark npy/txt 파일 저장
    7. 영상 처리 결과 정보를 dict로 반환
    """

    # 이전 실행 결과가 남아 있으면 삭제 후 새로 생성
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # OpenCV로 영상 파일 열기
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        raise ValueError("영상 파일을 열 수 없습니다.")

    # 영상 FPS와 전체 프레임 수 확인
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # 분석할 시작/종료 시간을 프레임 번호로 변환
    start_frame = max(int(start_time * fps), 0)
    end_frame = min(int(end_time * fps), total_frames - 1)

    # 분석 결과 저장용 리스트
    lip_crops = []
    lip_landmarks = []
    lip_features = []
    frame_numbers = []
    failed_frames = []

    # FaceMesh 모델 생성
    with mp_face_mesh.FaceMesh(
        static_image_mode=True,
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5
    ) as face_mesh:

        # 지정된 구간의 프레임을 하나씩 처리
        for frame_idx in range(start_frame, end_frame + 1):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            ret, frame = cap.read()

            # 프레임을 읽지 못하면 실패 프레임으로 기록
            if not ret:
                failed_frames.append(frame_idx)
                continue

            # 현재 프레임에서 입술 crop, landmark, 특징값 추출
            crop, debug, points, features = get_lip_crop_and_landmarks(
                frame,
                face_mesh,
                image_size=image_size
            )

            # 얼굴 또는 입술 영역 검출 실패 시 실패 프레임으로 기록
            if crop is None:
                failed_frames.append(frame_idx)
                continue

            # 성공한 프레임의 결과 저장
            lip_crops.append(crop)
            lip_landmarks.append(points)
            lip_features.append(features)
            frame_numbers.append(frame_idx)

            # 확인용 입술 crop 이미지와 debug 이미지 저장
            cv2.imwrite(f"{output_dir}/lip_{frame_idx:04d}.jpg", crop)
            cv2.imwrite(f"{output_dir}/debug_{frame_idx:04d}.jpg", debug)

    # 영상 객체 해제
    cap.release()

    # 리스트 형태의 결과를 numpy 배열로 변환
    lip_crops = np.array(lip_crops, dtype=np.uint8)
    lip_landmarks = np.array(lip_landmarks, dtype=np.int32)
    frame_numbers = np.array(frame_numbers, dtype=np.int32)
    failed_frames = np.array(failed_frames, dtype=np.int32)

    # 후속 입모양 점수 계산에 사용할 중간 결과 저장
    np.save("speech_lip_frames.npy", lip_crops)
    np.save("speech_lip_landmarks.npy", lip_landmarks)
    np.save("speech_frame_numbers.npy", frame_numbers)
    np.save("speech_failed_frames.npy", failed_frames)

    # 사람이 직접 확인할 수 있도록 landmark와 특징값을 txt로 저장
    with open("speech_lip_landmarks.txt", "w", encoding="utf-8") as f:
        for frame_idx, points, features in zip(frame_numbers, lip_landmarks, lip_features):
            f.write(f"frame {frame_idx}\n")

            f.write("[representative_points]\n")
            f.write(f"left: {features['left'][0]}, {features['left'][1]}\n")
            f.write(f"right: {features['right'][0]}, {features['right'][1]}\n")
            f.write(f"top: {features['top'][0]}, {features['top'][1]}\n")
            f.write(f"bottom: {features['bottom'][0]}, {features['bottom'][1]}\n")

            f.write("[features]\n")
            f.write(f"mouth_width: {features['mouth_width']}\n")
            f.write(f"mouth_height: {features['mouth_height']}\n")
            f.write(f"openness_ratio: {features['openness_ratio']:.4f}\n")

            f.write("[all_landmarks]\n")
            for i, (x, y) in enumerate(points):
                f.write(f"{i}: {x}, {y}\n")

            f.write("\n")

    # 영상 처리 결과 요약 반환
    return {
        "fps": fps,
        "total_frames": total_frames,
        "start_frame": start_frame,
        "end_frame": end_frame,
        "success_frame_count": len(lip_crops),
        "failed_frame_count": len(failed_frames),
        "output_dir": output_dir,
        "landmark_txt": "speech_lip_landmarks.txt",
        "landmark_npy": "speech_lip_landmarks.npy",
        "frames_npy": "speech_lip_frames.npy"
    }