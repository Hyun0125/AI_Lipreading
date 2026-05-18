import cv2
import mediapipe as mp
import numpy as np
import os
import shutil


mp_face_mesh = mp.solutions.face_mesh

LIPS = [
    61, 185, 40, 39, 37, 0, 267, 269, 270, 409,
    291, 375, 321, 405, 314, 17, 84, 181, 91, 146
]


def get_lip_crop_and_landmarks(frame, face_mesh, image_size=(96, 96)):
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(rgb)

    if not results.multi_face_landmarks:
        return None, None, None, None

    h, w, _ = frame.shape
    face_landmarks = results.multi_face_landmarks[0]

    points = []

    for idx in LIPS:
        lm = face_landmarks.landmark[idx]
        x = int(lm.x * w)
        y = int(lm.y * h)
        points.append([x, y])

    points = np.array(points, dtype=np.int32)

    x_min = np.min(points[:, 0])
    x_max = np.max(points[:, 0])
    y_min = np.min(points[:, 1])
    y_max = np.max(points[:, 1])

    lip_w = x_max - x_min
    lip_h = y_max - y_min

    pad_x = int(lip_w * 0.20)
    pad_top = int(lip_h * 0.30)
    pad_bottom = int(lip_h * 0.25)

    x1 = max(x_min - pad_x, 0)
    y1 = max(y_min - pad_top, 0)
    x2 = min(x_max + pad_x, w)
    y2 = min(y_max + pad_bottom, h)

    lip_crop = frame[y1:y2, x1:x2]

    if lip_crop.size == 0:
        return None, None, None, None

    lip_crop_resized = cv2.resize(lip_crop, image_size)

    debug = frame.copy()

    for x, y in points:
        cv2.circle(debug, (x, y), 3, (0, 255, 0), -1)

    left_point = points[np.argmin(points[:, 0])]
    right_point = points[np.argmax(points[:, 0])]
    top_point = points[np.argmin(points[:, 1])]
    bottom_point = points[np.argmax(points[:, 1])]

    cv2.circle(debug, tuple(left_point), 6, (0, 0, 255), -1)
    cv2.circle(debug, tuple(right_point), 6, (0, 0, 255), -1)
    cv2.circle(debug, tuple(top_point), 6, (255, 0, 255), -1)
    cv2.circle(debug, tuple(bottom_point), 6, (255, 0, 255), -1)

    cv2.rectangle(debug, (x1, y1), (x2, y2), (255, 0, 0), 2)

    mouth_width = int(right_point[0] - left_point[0])
    mouth_height = int(bottom_point[1] - top_point[1])
    openness_ratio = mouth_height / mouth_width if mouth_width != 0 else 0

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
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        raise ValueError("영상 파일을 열 수 없습니다.")

    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    start_frame = max(int(start_time * fps), 0)
    end_frame = min(int(end_time * fps), total_frames - 1)

    lip_crops = []
    lip_landmarks = []
    lip_features = []
    frame_numbers = []
    failed_frames = []

    with mp_face_mesh.FaceMesh(
        static_image_mode=True,
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5
    ) as face_mesh:

        for frame_idx in range(start_frame, end_frame + 1):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            ret, frame = cap.read()

            if not ret:
                failed_frames.append(frame_idx)
                continue

            crop, debug, points, features = get_lip_crop_and_landmarks(
                frame,
                face_mesh,
                image_size=image_size
            )

            if crop is None:
                failed_frames.append(frame_idx)
                continue

            lip_crops.append(crop)
            lip_landmarks.append(points)
            lip_features.append(features)
            frame_numbers.append(frame_idx)

            cv2.imwrite(f"{output_dir}/lip_{frame_idx:04d}.jpg", crop)
            cv2.imwrite(f"{output_dir}/debug_{frame_idx:04d}.jpg", debug)

    cap.release()

    lip_crops = np.array(lip_crops, dtype=np.uint8)
    lip_landmarks = np.array(lip_landmarks, dtype=np.int32)
    frame_numbers = np.array(frame_numbers, dtype=np.int32)
    failed_frames = np.array(failed_frames, dtype=np.int32)

    np.save("speech_lip_frames.npy", lip_crops)
    np.save("speech_lip_landmarks.npy", lip_landmarks)
    np.save("speech_frame_numbers.npy", frame_numbers)
    np.save("speech_failed_frames.npy", failed_frames)

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