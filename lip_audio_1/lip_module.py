import numpy as np
from targets import TARGETS


def calculate_lip_score(
    target_char,
    landmark_path="speech_lip_landmarks.npy"
):
    """
    입술 랜드마크 좌표를 기반으로 입모양 점수를 계산한다.
    저장은 하지 않고 계산 결과만 반환한다.
    """

    if target_char not in TARGETS:
        raise ValueError(f"지원하지 않는 글자입니다: {target_char}")

    target_info = TARGETS[target_char]["visual"]

    target_avg = target_info["target_avg"]
    target_max = target_info["target_max"]
    target_movement = target_info["target_movement"]

    data = np.load(landmark_path)

    ratios = []

    for frame in data:
        left = frame[np.argmin(frame[:, 0])]
        right = frame[np.argmax(frame[:, 0])]
        top = frame[np.argmin(frame[:, 1])]
        bottom = frame[np.argmax(frame[:, 1])]

        mouth_width = right[0] - left[0]
        mouth_height = bottom[1] - top[1]

        if mouth_width != 0:
            ratios.append(mouth_height / mouth_width)

    ratios = np.array(ratios)

    if len(ratios) == 0:
        return {
            "target_char": target_char,
            "error": "입술 좌표가 추출된 프레임이 없습니다.",
            "avg_ratio": 0,
            "max_ratio": 0,
            "min_ratio": 0,
            "movement_range": 0,
            "avg_score": 0,
            "max_score": 0,
            "movement_score": 0,
            "final_score": 0
        }

    avg_ratio = np.mean(ratios)
    max_ratio = np.max(ratios)
    min_ratio = np.min(ratios)
    movement_range = max_ratio - min_ratio

    avg_score = 100 - abs(avg_ratio - target_avg) * 100
    max_score = 100 - abs(max_ratio - target_max) * 100
    movement_score = 100 - abs(movement_range - target_movement) * 200

    avg_score = max(0, min(100, avg_score))
    max_score = max(0, min(100, max_score))
    movement_score = max(0, min(100, movement_score))

    final_score = (
        avg_score * 0.4
        + max_score * 0.3
        + movement_score * 0.3
    )

    return {
        "target_char": target_char,
        "avg_ratio": float(avg_ratio),
        "max_ratio": float(max_ratio),
        "min_ratio": float(min_ratio),
        "movement_range": float(movement_range),
        "avg_score": float(avg_score),
        "max_score": float(max_score),
        "movement_score": float(movement_score),
        "final_score": float(final_score)
    }