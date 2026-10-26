import os
import numpy as np
import soundfile as sf
from moviepy import VideoFileClip


def extract_audio_from_video(
    video_path: str,
    audio_path: str = "extracted_audio.wav",
    fps: int = 16000,
):
    """
    영상 파일에서 오디오를 추출하여 wav 파일로 저장한다.
    영상에 오디오 트랙이 없으면 0값으로 된 무음 wav 파일을 생성한다.
    """

    if os.path.exists(audio_path):
        return audio_path

    clip = VideoFileClip(video_path)

    # 영상에 음성 트랙이 없는 경우
    # 기존처럼 오류를 내지 않고, 영상 길이만큼 무음 wav 생성
    if clip.audio is None:
        duration = clip.duration
        silent_audio = np.zeros(int(duration * fps), dtype=np.float32)

        sf.write(audio_path, silent_audio, fps)

        clip.close()
        return audio_path

    clip.audio.write_audiofile(audio_path, fps=fps)
    clip.close()

    return audio_path