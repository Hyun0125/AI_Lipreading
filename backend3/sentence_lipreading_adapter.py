"""Sentence-only adapter for the UNMODIFIED original Korean lipreader.

Restore the original predictor's CLI and preprocessing contract:
* prefer the original video when OpenCV reports a plausible FPS;
* repair abnormal browser FPS using LOSSLESS constant-30fps H.264;
* use the original predictor's --start/--end feature with speech boundaries
  estimated from the existing sentence audio WAV (when available);
* retain original 96x96 lip crop, default 6-second windows, hybrid decoder,
  pretrained checkpoint, and vendor implementation (all in word_lipreading).

No edits to backend3/ai/analyze.py or the original word_lipreading code.
"""
from __future__ import annotations

import json
import logging
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from uuid import uuid4

ROOT = Path(__file__).resolve().parent
LOG = logging.getLogger("uvicorn.error")


def _find_lipreader() -> Path | None:
    locations = []
    if os.environ.get("SENTENCE_LIPREADING_DIR"):
        locations.append(Path(os.environ["SENTENCE_LIPREADING_DIR"]))
    locations.extend([
        ROOT / "word_lipreading",
        ROOT / "combined_analysis" / "sentence_analysis" / "word_lipreading",
        ROOT / "sentence_analysis" / "word_lipreading",
    ])
    for folder in locations:
        if (folder / "predict_video.py").is_file():
            return folder.resolve()
    return None


def _missing_lipreader_files(folder: Path) -> list[str]:
    required = (
        "predict_video.py", "predict_korean.py", "korean_model.py",
        "checkpoints/multiview_lip.pt", "vendor/olkavs/avsr/utils/search.py",
        "vendor/olkavs/vocabulary/kor_grapheme.csv",
    )
    return [part for part in required if not (folder / part).is_file()]


def _ffmpeg_binary() -> str:
    selected = os.environ.get("FFMPEG_BINARY", "").strip()
    if selected:
        return selected
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError as exc:
        raise RuntimeError("30fps 영상 보정에 필요한 FFmpeg가 없습니다.") from exc


def _video_fps_and_duration(path: Path) -> tuple[float | None, float | None]:
    """Check the FPS that the ORIGINAL predictor will see through OpenCV."""
    import cv2  # only imported for sentence requests, never for jamo
    cap = cv2.VideoCapture(str(path))
    try:
        if not cap.isOpened():
            return None, None
        fps = float(cap.get(cv2.CAP_PROP_FPS))
        frames = float(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if not math.isfinite(fps) or fps <= 0:
            return None, None
        duration = frames / fps if math.isfinite(frames) and frames > 0 else None
        return fps, duration
    finally:
        cap.release()


def _speech_bounds(audio_path: str | Path | None) -> tuple[float, float] | None:
    """Match the existing voice_analysis audio_features VAD (librosa top_db=30).

    Only timestamps are passed to --start/--end: audio is NEVER passed to the
    lipreading model. Keep a margin to preserve consonant onset/release frames.
    """
    if not audio_path or os.environ.get("SENTENCE_LIPREADING_TRIM_SPEECH", "1") == "0":
        return None
    path = Path(audio_path)
    if not path.is_file():
        return None
    try:
        import librosa
        import numpy as np
        y, sr = librosa.load(str(path), sr=None, mono=True)
        if len(y) == 0 or not np.any(y):
            return None
        intervals = librosa.effects.split(y, top_db=30)
        if len(intervals) == 0:
            return None
        length = len(y) / sr
        # Use the first and last audible frames, including natural pauses.
        # Do not cut the sentence into disjoint clips or use reference words.
        start = max(0.0, float(intervals[0][0]) / sr - 0.18)
        end = min(length, float(intervals[-1][1]) / sr + 0.18)
        if end - start < 0.5:
            return None
        # Negligible trims add timing risk without improving alignment.
        if start < 0.08 and length - end < 0.08:
            return None
        return round(start, 3), round(end, 3)
    except Exception:
        LOG.exception("Sentence speech boundary detection failed; use full video")
        return None


def run_sentence_lipreading(
    video_path: str, *, audio_path: str | Path | None = None,
    start_seconds: float | None = None, end_seconds: float | None = None,
    timeout_seconds: int = 240,
) -> dict:
    """Run the original video-only model. Return a compatible JSON dictionary.

    Explicit start/end override the optional audio-derived timing. Speech audio
    is used only for temporal alignment, not for predicting the lip transcript.
    """
    started = time.perf_counter()
    output = ROOT / "outputs" / "sentence_lipreading" / uuid4().hex
    output.mkdir(parents=True, exist_ok=True)
    log_file = output / "execution.log"

    def response(status: str, **additional) -> dict:
        return {
            "status": status, "recognized_text": "", "segments": [],
            "audio_used": False,
            "elapsed_seconds": round(time.perf_counter() - started, 2),
            **additional,
        }

    folder = _find_lipreader()
    if folder is None:
        return response("unavailable", reason="원본 word_lipreading 폴더를 찾을 수 없습니다.")
    missing = _missing_lipreader_files(folder)
    if missing:
        return response("unavailable", reason="원본 립리딩 필수 파일 누락: " + ", ".join(missing))

    video = Path(video_path).resolve()
    if not video.is_file():
        return response("error", reason="업로드한 영상 파일이 없습니다.")

    try:
        raw_fps, _ = _video_fps_and_duration(video)
        # Original predict_korean.py uses OpenCV CAP_PROP_FPS. Chrome VP9/WebM
        # can advertise 1000fps and break its 6s windows. Convert ONLY then.
        needs_conversion = raw_fps is None or not 8 <= raw_fps <= 120
        input_video = video
        conversion_method = "original_unchanged"
        with log_file.open("w", encoding="utf-8") as log:
            log.write(f"original_video={video} opencv_fps={raw_fps}\n")
            if needs_conversion:
                input_video = output / "normalized_30fps_lossless.mp4"
                # CRF 0 = lossless after decoding the source, unlike the old
                # lossy MPEG-4 q:v=4 step. Use H.264 for OpenCV compatibility.
                cmd = [
                    _ffmpeg_binary(), "-hide_banner", "-loglevel", "error", "-y",
                    "-i", str(video), "-map", "0:v:0", "-an",
                    "-vf", "setpts=PTS-STARTPTS,fps=30",
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "0",
                    "-pix_fmt", "yuv420p", str(input_video),
                ]
                log.write("Converting abnormal FPS to lossless 30fps video.\n")
                log.flush()
                subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT,
                               check=True, timeout=min(timeout_seconds, 75))
                conversion_method = "lossless_30fps_h264"

        actual_fps, duration = _video_fps_and_duration(input_video)
        if actual_fps is None:
            return response("error", reason="립리딩 입력 영상을 열 수 없습니다.", log_path=str(log_file))

        bounds_source = "full_video"
        bounds = None
        if start_seconds is not None or end_seconds is not None:
            # Honor original CLI explicit --start / --end support.
            start = float(start_seconds or 0)
            end = float(end_seconds) if end_seconds is not None else None
            if not math.isfinite(start) or start < 0 or (end is not None and
                    (not math.isfinite(end) or end <= start)):
                return response("error", reason="유효하지 않은 립리딩 구간입니다.")
            bounds = (start, end)
            bounds_source = "explicit"
        else:
            detected = _speech_bounds(audio_path)
            if detected:
                bounds = detected
                bounds_source = "speech_vad"

        if bounds:
            start, end = bounds
            if duration is not None:
                if end is not None:
                    end = min(end, duration)
                if start >= duration or (end is not None and end - start < 0.3):
                    start, end, bounds_source = 0.0, None, "full_video"
            bounds = (start, end)

        python_exe = os.environ.get("LIPREADING_PYTHON", "").strip() or sys.executable
        command = [
            python_exe, str(folder / "predict_video.py"), str(input_video),
            "--output-dir", str(output / "lipreading"),
            # Explicitly preserve ORIGINAL model defaults and clip settings.
            "--decoder", "hybrid", "--segment-seconds", "6",
        ]
        if bounds:
            start, end = bounds
            if start > 0:
                command += ["--start", str(start)]
            if end is not None:
                command += ["--end", str(end)]

        env = os.environ.copy()
        env.update({
            "PYTHONIOENCODING": "utf-8", "PYTHONUTF8": "1",
            "MPLBACKEND": "Agg", "OMP_NUM_THREADS": "2",
            "NUMBA_CACHE_DIR": str(output / "numba_cache"),
            "MPLCONFIGDIR": str(output / "mpl_config"),
        })
        with log_file.open("a", encoding="utf-8") as log:
            log.write(f"inference_video={input_video} fps={actual_fps} \n")
            log.write(f"conversion={conversion_method} trim={bounds_source} bounds={bounds}\n")
            log.flush()
            proc = subprocess.run(command, cwd=str(folder), env=env,
                                  stdout=log, stderr=subprocess.STDOUT,
                                  check=False, timeout=timeout_seconds)

        result_file = output / "lipreading" / "result.json"
        if not result_file.is_file():
            return response("error", reason=f"립리딩 결과가 없습니다(종료코드 {proc.returncode}).",
                            log_path=str(log_file))
        data = json.loads(result_file.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return response("error", reason="립리딩 결과 JSON이 올바르지 않습니다.", log_path=str(log_file))
        raw_segments = data.get("segments")
        segments = raw_segments if isinstance(raw_segments, list) else []
        recognized = " ".join(str(seg.get("text", "")).strip()
                              for seg in segments if isinstance(seg, dict) and seg.get("text")).strip()
        if proc.returncode != 0 or data.get("status") not in ("completed", "no_text"):
            return response("error", reason=str(data.get("error") or f"립리딩 실행 실패(종료코드 {proc.returncode})"),
                            log_path=str(log_file), segments=segments)
        return response("completed" if recognized else "no_text",
                        recognized_text=recognized, segments=segments,
                        model=data.get("model", "한국어 입 모양 인식 모델"),
                        warning=data.get("warning", "실험용 영상 기반 문장 예측입니다."),
                        video_input_mode=conversion_method,
                        clip_selection=bounds_source,
                        audio_timing_used=(bounds_source == "speech_vad"),
                        source_video_fps=raw_fps,
                        log_path=str(log_file))
    except subprocess.TimeoutExpired:
        return response("error", reason="립리딩 분석 시간이 초과되었습니다.", log_path=str(log_file))
    except (OSError, subprocess.CalledProcessError, ValueError, json.JSONDecodeError) as exc:
        LOG.exception("Sentence lipreading adapter failed")
        return response("error", reason=f"립리딩 연결 오류: {type(exc).__name__}", log_path=str(log_file))
