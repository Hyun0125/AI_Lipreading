import shutil
import subprocess
from pathlib import Path


def get_ffmpeg_executable():
    executable = shutil.which("ffmpeg")
    if executable:
        return executable
    try:
        import imageio_ffmpeg
    except ImportError as exc:
        raise RuntimeError(
            "FFmpeg is unavailable. Run: pip install -r voice_analysis/requirements.txt"
        ) from exc
    return imageio_ffmpeg.get_ffmpeg_exe()


def extract_audio(video_path, output_path="audio.wav"):
    if not Path(video_path).is_file():
        raise FileNotFoundError(f"Video file not found: {video_path}")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    command = [
        get_ffmpeg_executable(), "-y", "-i", str(video_path),
        "-vn", "-ac", "1", "-ar", "16000",
        "-acodec", "pcm_s16le", str(output_path)
    ]
    subprocess.run(command, check=True)
    return output_path
