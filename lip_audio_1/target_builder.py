import os
import json
import numpy as np

from audio_module import find_speech_segment_from_video
from video_preprocess import process_video_by_time


REFERENCE_ROOT = "reference_videos"
OUTPUT_JSON = "generated_targets.json"

VIDEO_EXTENSIONS = (".mp4", ".mov", ".avi", ".mkv")


def extract_features_from_landmarks(landmark_path="speech_lip_landmarks.npy"):
    """
    speech_lip_landmarks.npy 파일을 읽어서
    한 영상의 입모양 특징값을 계산한다.
    """

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

    # 입술 좌표가 하나도 추출되지 않은 경우
    if len(ratios) == 0:
        return None

    return {
        "avg_ratio": float(np.mean(ratios)),
        "max_ratio": float(np.max(ratios)),
        "min_ratio": float(np.min(ratios)),
        "movement_range": float(np.max(ratios) - np.min(ratios))
    }


def build_target_for_folder(target_char, folder_path):
    """
    특정 발음 폴더 안의 기준 영상들을 분석해서
    해당 발음의 평균 기준값을 생성한다.
    """

    video_files = [
        file for file in os.listdir(folder_path)
        if file.lower().endswith(VIDEO_EXTENSIONS)
    ]

    video_files.sort()

    if len(video_files) == 0:
        print(f"{target_char}: 영상 파일 없음")
        return None

    feature_list = []

    for video_file in video_files:
        video_path = os.path.join(folder_path, video_file)

        print(f"처리 중: {target_char} / {video_file}")

        try:
            # 1. 음성 구간 탐지
            audio_result = find_speech_segment_from_video(video_path)

            # 2. 입술 움직임 누락 방지를 위해 앞뒤 0.5초 여유 추가
            start_time = max(audio_result["speech_start_time"] - 0.5, 0)
            end_time = audio_result["speech_end_time"] + 0.5

            # 3. 해당 구간의 입술 랜드마크 추출
            video_result = process_video_by_time(
                video_path=video_path,
                start_time=start_time,
                end_time=end_time
            )

            # 4. 입술 좌표 추출 성공 프레임이 없는 경우 건너뛰기
            if video_result["success_frame_count"] == 0:
                print(f"입술 좌표 추출 실패: {video_file}")
                continue

            # 5. 입모양 특징값 계산
            features = extract_features_from_landmarks("speech_lip_landmarks.npy")

            if features is None:
                print(f"입모양 특징 계산 실패: {video_file}")
                continue

            feature_list.append(features)

        except Exception as e:
            print(f"처리 실패: {target_char} / {video_file}")
            print("오류 내용:", e)
            continue

    # 사용 가능한 기준 영상이 하나도 없는 경우
    if len(feature_list) == 0:
        print(f"{target_char}: 사용 가능한 기준 영상이 없습니다.")
        return None

    avg_values = {
        "target_avg": float(np.mean([f["avg_ratio"] for f in feature_list])),
        "target_max": float(np.mean([f["max_ratio"] for f in feature_list])),
        "target_movement": float(np.mean([f["movement_range"] for f in feature_list]))
    }

    return {
        "visual": avg_values,
        "audio_aliases": [target_char],
        "sample_count": len(feature_list),
        "samples": feature_list
    }


def build_all_targets():
    """
    reference_videos 폴더 안의 모든 발음 폴더를 분석하여
    generated_targets.json 파일을 생성한다.
    """

    if not os.path.exists(REFERENCE_ROOT):
        raise FileNotFoundError(f"{REFERENCE_ROOT} 폴더가 없습니다.")

    targets = {}

    for target_char in os.listdir(REFERENCE_ROOT):
        folder_path = os.path.join(REFERENCE_ROOT, target_char)

        if not os.path.isdir(folder_path):
            continue

        result = build_target_for_folder(target_char, folder_path)

        if result is not None:
            targets[target_char] = result

    if len(targets) == 0:
        print("생성된 기준값이 없습니다.")
        print("reference_videos 폴더 안에 기준 영상을 넣어주세요.")
        return

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(targets, f, ensure_ascii=False, indent=4)

    print("완료")
    print("저장 파일:", OUTPUT_JSON)


if __name__ == "__main__":
    build_all_targets()