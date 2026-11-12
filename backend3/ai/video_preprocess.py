import cv2
import mediapipe as mp
import numpy as np
import os
import shutil
import subprocess
import logging
import math
from pathlib import Path


# MediaPipe FaceMesh 모듈 사용
mp_face_mesh = mp.solutions.face_mesh
LOGGER = logging.getLogger("uvicorn.error")

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



def _open_video_with_valid_timestamps(video_path, artifacts_dir):
    """Open a video with a reliable frame index/time correspondence.

    Browser MediaRecorder WebM sometimes presents 1000 as its FPS and a
    guessed frame count to OpenCV. These are *not* real decoded frames.
    Convert only suspicious sources to a temporary 15-FPS MP4, preserving
    the original uploaded video and audio files unchanged.
    """
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise ValueError("영상 파일을 열 수 없습니다.")

    original_fps = float(cap.get(cv2.CAP_PROP_FPS))
    original_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if math.isfinite(original_fps) and 1 <= original_fps <= 120 and original_count > 0:
        return cap, original_fps, original_count, False
    cap.release()

    ffmpeg_exe = shutil.which("ffmpeg")
    if not ffmpeg_exe:
        try:
            import imageio_ffmpeg
            ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
        except (ImportError, OSError, RuntimeError) as exc:
            raise RuntimeError(
                "비정상 FPS 영상 복구용 FFmpeg가 없습니다. "
                "ffmpeg 또는 imageio-ffmpeg를 설치해 주세요."
            ) from exc

    converted = Path(artifacts_dir) / "lip_video_cfr.mp4"
    command = [
        ffmpeg_exe, "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
        "-i", str(video_path), "-map", "0:v:0", "-an",
        "-vf", "fps=15", "-c:v", "mpeg4", "-q:v", "5", str(converted),
    ]
    try:
        finished = subprocess.run(command, capture_output=True, text=True,
                                  timeout=120, check=False)
    except (subprocess.TimeoutExpired, OSError) as exc:
        raise RuntimeError("영상 FPS 보정용 FFmpeg 실행에 실패했습니다.") from exc
    if finished.returncode != 0:
        raise RuntimeError("영상 FPS 보정에 실패했습니다: " + finished.stderr[-500:])

    cap = cv2.VideoCapture(str(converted))
    if not cap.isOpened():
        raise ValueError("FPS 보정 영상을 열지 못했습니다.")
    fps = float(cap.get(cv2.CAP_PROP_FPS))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if not (math.isfinite(fps) and 1 <= fps <= 120 and total_frames > 0):
        cap.release()
        raise ValueError("FPS 보정 후에도 정상적인 프레임 정보를 얻지 못했습니다.")

    LOGGER.info(
        "lip video normalized: original_fps=%s original_frames=%s "
        "normalized_fps=%s normalized_frames=%s",
        original_fps, original_count, fps, total_frames,
    )
    return cap, fps, total_frames, True


def process_video_by_time(
    video_path: str,
    start_time: float,
    end_time: float,
    output_dir: str = "speech_lip_frames",
    image_size=(96, 96),
    artifacts_dir=".",
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

    artifacts_dir = Path(artifacts_dir)
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    # 이전 실행 결과가 남아 있으면 삭제 후 새로 생성
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    # 비정상 FPS(예: Chrome WebM의 1000)를 바로 프레임 번호로 쓰지 않는다.
    cap, fps, total_frames, normalized = _open_video_with_valid_timestamps(
        video_path, artifacts_dir
    )

    # 음성 분석의 시간 범위는 그대로 사용하며, 영상 쪽에서만 시간-프레임 변환.
    start_frame = max(int(max(start_time, 0) * fps), 0)
    end_frame = min(int(max(end_time, 0) * fps), total_frames - 1)
    if start_frame >= total_frames or end_frame < start_frame:
        cap.release()
        raise ValueError(
            f"영상 분석 구간이 유효하지 않습니다: "
            f"{start_time:.2f}~{end_time:.2f}초, {fps:.2f} FPS, {total_frames}프레임"
        )

    # 분석 결과 저장용 리스트
    lip_crops = []
    lip_landmarks = []
    lip_features = []
    frame_numbers = []
    failed_frames = []
    frame_read_failures = 0
    face_detection_failures = 0

    # Save frame PNG/JPEG only for diagnostics; processing dozens of debug frames
    # is not necessary for the scores and can dominate disk I/O.
    save_debug = os.getenv("JAMO_SAVE_FRAMES", "0") == "1"
    frame_step = max(1, int(os.getenv("JAMO_FRAME_STEP", "1")))
    use_tracking = os.getenv("JAMO_FACE_TRACKING", "0") == "1"
    # 기존 안정 동작 방식 복원: 프레임마다 명시적으로 위치를 지정한다.
    # FPS 보정이 필요한 경우에는 위에서 CFR 영상으로 변환한 상태다.

    # FaceMesh 모델 생성
    with mp_face_mesh.FaceMesh(
        static_image_mode=not use_tracking,
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5
    ) as face_mesh:

        # 지정된 구간의 프레임을 하나씩 처리
        for frame_idx in range(start_frame, end_frame + 1, frame_step):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            ret, frame = cap.read()

            # 프레임을 읽지 못하면 실패 프레임으로 기록
            if not ret:
                failed_frames.append(frame_idx)
                frame_read_failures += 1
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
                face_detection_failures += 1
                continue

            # 성공한 프레임의 결과 저장
            lip_crops.append(crop)
            lip_landmarks.append(points)
            lip_features.append(features)
            frame_numbers.append(frame_idx)

            # 확인용 입술 crop 이미지와 debug 이미지 저장
            if save_debug:
                cv2.imwrite(f"{output_dir}/lip_{frame_idx:04d}.jpg", crop)
                cv2.imwrite(f"{output_dir}/debug_{frame_idx:04d}.jpg", debug)

    # 영상 객체 해제
    cap.release()
    LOGGER.info(
        "lip frames: fps=%s fps_normalized=%s attempted=%s "
        "read_failures=%s detection_failures=%s successes=%s",
        fps, normalized, len(frame_numbers) + len(failed_frames),
        frame_read_failures, face_detection_failures, len(frame_numbers),
    )

    # 리스트 형태의 결과를 numpy 배열로 변환
    lip_crops = np.array(lip_crops, dtype=np.uint8)
    lip_landmarks = np.array(lip_landmarks, dtype=np.int32)
    frame_numbers = np.array(frame_numbers, dtype=np.int32)
    failed_frames = np.array(failed_frames, dtype=np.int32)

    # 후속 입모양 점수 계산에 사용할 중간 결과 저장
    np.save(artifacts_dir / "speech_lip_frames.npy", lip_crops)
    np.save(artifacts_dir / "speech_lip_landmarks.npy", lip_landmarks)
    np.save(artifacts_dir / "speech_frame_numbers.npy", frame_numbers)
    np.save(artifacts_dir / "speech_failed_frames.npy", failed_frames)

    # 사람이 직접 확인할 수 있도록 landmark와 특징값을 txt로 저장
    with open(artifacts_dir / "speech_lip_landmarks.txt", "w", encoding="utf-8") as f:
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
        "fps_normalized": normalized,
        "total_frames": total_frames,
        "start_frame": start_frame,
        "end_frame": end_frame,
        "success_frame_count": len(lip_crops),
        "failed_frame_count": len(failed_frames),
        "frame_read_failure_count": frame_read_failures,
        "face_detection_failure_count": face_detection_failures,
        "output_dir": output_dir,
        "landmark_txt": str(artifacts_dir / "speech_lip_landmarks.txt"),
        "landmark_npy": str(artifacts_dir / "speech_lip_landmarks.npy"),
        "frames_npy": str(artifacts_dir / "speech_lip_frames.npy")
    }