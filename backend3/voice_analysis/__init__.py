"""Independent voice analysis package."""

from .phoneme_comparison import compare_phonemes
from .etri_pronunciation import assess_pronunciation


def analyze_video(video_path, output_dir=None, media_base_url=None, reference_text=None, *, pronunciation_provider=None, etri_audio_format="wav"):
    """Analyze a video, save its artifacts, and return JSON-compatible results."""
    from .analyze import analyze_video as run_analysis

    return run_analysis(video_path, output_dir, media_base_url, reference_text,
                        pronunciation_provider=pronunciation_provider, etri_audio_format=etri_audio_format)
