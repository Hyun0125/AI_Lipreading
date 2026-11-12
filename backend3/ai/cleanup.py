import os
import shutil

#이전 파일 삭제

FILES_TO_DELETE = [
    "extracted_audio.wav",
    "trimmed_audio.wav",
    "speech_segment.txt",
    "speech_lip_landmarks.txt",

    "score.txt",
    "lip_score.txt",
    "audio_result.json",


    "final_result.txt",
    "final_result.json",

    "speech_lip_frames.npy",
    "speech_lip_landmarks.npy",
    "speech_frame_numbers.npy",
    "speech_failed_frames.npy",
]


FOLDERS_TO_DELETE = [
    "speech_lip_frames",
]


def cleanup_previous_outputs():
    for file_path in FILES_TO_DELETE:
        if os.path.exists(file_path):
            os.remove(file_path)

    for folder_path in FOLDERS_TO_DELETE:
        if os.path.exists(folder_path):
            shutil.rmtree(folder_path)


if __name__ == "__main__":
    cleanup_previous_outputs()