import os
import shutil
import json
import logging
import re
from pathlib import Path
from uuid import uuid4
from datetime import datetime, timezone, timedelta

from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.concurrency import run_in_threadpool
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import null as sql_null, func, Index

from database import Base, engine, SessionLocal
from models import FeedbackResult
from review_api import router as review_router
from ai.analyze import analyze_pronunciation

Base.metadata.create_all(bind=engine)

# Existing feedback.db files also receive this index on the next server start.
# The index supports the COUNT query by (category, target_item), with optional
# user_id as the third filter column. No existing rows or tables are replaced.
Index(
    "ix_feedback_results_category_target_user",
    FeedbackResult.category,
    FeedbackResult.target_item,
    FeedbackResult.user_id,
).create(bind=engine, checkfirst=True)

LOG = logging.getLogger("uvicorn.error")

app = FastAPI()
app.include_router(review_router)
# Only generated sentence analysis outputs are served here (not private uploads).
MEDIA_ROOT = Path("outputs/voice_analysis")
MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(MEDIA_ROOT)), name="analysis-media")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

TEMP_UPLOAD_DIR = "uploads/temp"
SAVED_UPLOAD_DIR = "uploads/videos"

os.makedirs(TEMP_UPLOAD_DIR, exist_ok=True)
os.makedirs(SAVED_UPLOAD_DIR, exist_ok=True)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_korea_now():
    return datetime.now(timezone(timedelta(hours=9))).replace(tzinfo=None)


class SaveFeedbackRequest(BaseModel):
    user_id: int | None = None

    category: str
    target_item: str
    video_path: str

    voice_analysis: dict[str, object] | None = None

    target_pronunciation: str = ""
    whisper_result: str = ""
    is_correct: bool = False

    speech_start_time: float | None = 0.0
    speech_end_time: float | None = 0.0
    speech_duration: float | None = 0.0
    volume: float | None = 0.0
    energy_change: float | None = 0.0
    average_pitch: float | None = 0.0
    pitch_change: float | None = 0.0

    speed_score: float | None = 0.0
    duration_score: float | None = 0.0
    stability_score: float | None = 0.0
    pitch_score: float | None = 0.0
    volume_score: float | None = 0.0
    audio_total_score: float | None = 0.0

    average_mouth_open_ratio: float | None = 0.0
    max_mouth_open_ratio: float | None = 0.0
    min_mouth_open_ratio: float | None = 0.0
    lip_movement_change: float | None = 0.0
    average_mouth_open_score: float | None = 0.0
    max_mouth_open_score: float | None = 0.0
    lip_movement_score: float | None = 0.0
    visual_total_score: float | None = 0.0

    feedbacks: list[str] = Field(default_factory=list)


@app.get("/")
def root():
    return {
        "message": "Feedback backend is running"
    }


@app.post("/feedback/analyze")
async def analyze_feedback_video(
    category: str = Form(...),
    target_item: str = Form(...),
    video: UploadFile = File(...),
):
    if category not in ("자음", "모음", "문장"):
        raise HTTPException(status_code=422, detail="지원하지 않는 학습 유형입니다.")
    def safe(value):
        value = re.sub(r"[^가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9._-]", "_", value)
        return value[:40].strip("._") or "recording"

    stamp = get_korea_now().strftime("%Y%m%d_%H%M%S")
    filename = f"{safe(category)}_{safe(target_item)}_{stamp}_{uuid4().hex[:10]}_{safe(video.filename or 'recording.webm')}"
    temp_video_path = str(Path(TEMP_UPLOAD_DIR) / filename)
    try:
        with open(temp_video_path, "wb") as buffer:
            shutil.copyfileobj(video.file, buffer)
    finally:
        await video.close()
    LOG.info("uploaded category=%s bytes=%d", category, os.path.getsize(temp_video_path))
    try:
        # Keep the API event loop responsive while CPU-heavy inference runs.
        result = await run_in_threadpool(
            analyze_pronunciation, video_path=temp_video_path,
            category=category, target_item=target_item,
        )
    except ValueError as exc:
        LOG.warning("analysis validation failed category=%s: %s", category, exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except (FileNotFoundError, RuntimeError) as exc:
        LOG.exception("analysis failed category=%s", category)
        raise HTTPException(status_code=503, detail=f"분석에 실패했습니다: {exc}") from exc

    return result


@app.post("/feedback/save")
def save_feedback_result(
    request: SaveFeedbackRequest,
    db: Session = Depends(get_db),
):
    if not os.path.exists(request.video_path):
        return {
            "success": False,
            "message": "영상 파일을 찾을 수 없습니다."
        }

    now = get_korea_now()
    timestamp = now.strftime("%Y%m%d_%H%M%S")

    original_filename = os.path.basename(request.video_path)
    saved_filename = f"saved_{timestamp}_{uuid4().hex[:10]}_{original_filename}"

    saved_video_path = os.path.join(SAVED_UPLOAD_DIR, saved_filename)
    saved_video_path = saved_video_path.replace("\\", "/")

    shutil.copyfile(request.video_path, saved_video_path)

    # SQLAlchemy column defaults otherwise turn explicit None into numeric zero.
    # Flutter currently maps nullable sentence scores to 0.0; do not save those
    # display fallbacks as actual evaluation results.
    score_fields = {"speed_score", "duration_score", "stability_score", "pitch_score",
                    "volume_score", "audio_total_score", "average_mouth_open_score",
                    "max_mouth_open_score", "lip_movement_score", "visual_total_score"}
    visual_fields = {"average_mouth_open_ratio", "max_mouth_open_ratio", "min_mouth_open_ratio",
                     "lip_movement_change"}
    def scalar(field):
        if request.category == "문장" and field in score_fields | visual_fields:
            return sql_null()
        value = getattr(request, field)
        return sql_null() if value is None else value

    result = FeedbackResult(
        user_id=request.user_id,

        category=request.category,
        target_item=request.target_item,
        video_path=saved_video_path,

        voice_analysis=(
            json.dumps(request.voice_analysis, ensure_ascii=False)
            if request.voice_analysis is not None
            else None
        ),

        target_pronunciation=request.target_pronunciation,
        whisper_result=request.whisper_result,
        is_correct=request.is_correct,

        speech_start_time=scalar("speech_start_time"),
        speech_end_time=scalar("speech_end_time"),
        speech_duration=scalar("speech_duration"),
        volume=scalar("volume"),
        energy_change=scalar("energy_change"),
        average_pitch=scalar("average_pitch"),
        pitch_change=scalar("pitch_change"),

        speed_score=scalar("speed_score"),
        duration_score=scalar("duration_score"),
        stability_score=scalar("stability_score"),
        pitch_score=scalar("pitch_score"),
        volume_score=scalar("volume_score"),
        audio_total_score=scalar("audio_total_score"),

        average_mouth_open_ratio=scalar("average_mouth_open_ratio"),
        max_mouth_open_ratio=scalar("max_mouth_open_ratio"),
        min_mouth_open_ratio=scalar("min_mouth_open_ratio"),
        lip_movement_change=scalar("lip_movement_change"),
        average_mouth_open_score=scalar("average_mouth_open_score"),
        max_mouth_open_score=scalar("max_mouth_open_score"),
        lip_movement_score=scalar("lip_movement_score"),
        visual_total_score=scalar("visual_total_score"),

        feedbacks=json.dumps(request.feedbacks, ensure_ascii=False),
    )

    db.add(result)
    db.commit()
    db.refresh(result)

    return {
        "success": True,
        **feedback_result_to_dict(result),
        "message": "피드백 결과가 저장되었습니다."
    }


@app.get("/feedback/count")
def get_feedback_count(
    category: str,
    target_item: str,
    user_id: int | None = None,
    db: Session = Depends(get_db),
):
    """Return only the number of rows explicitly saved in feedback_results."""
    query = db.query(func.count(FeedbackResult.id)).filter(
        FeedbackResult.category == category,
        FeedbackResult.target_item == target_item,
    )
    if user_id is not None:
        query = query.filter(FeedbackResult.user_id == user_id)

    return {
        "category": category,
        "target_item": target_item,
        "count": int(query.scalar() or 0),
    }


@app.get("/feedback/results")
def get_feedback_results(
    category: str | None = None,
    target_item: str | None = None,
    db: Session = Depends(get_db),
):
    query = db.query(FeedbackResult)

    if category is not None:
        query = query.filter(FeedbackResult.category == category)

    if target_item is not None:
        query = query.filter(FeedbackResult.target_item == target_item)

    results = query.order_by(FeedbackResult.id.desc()).all()

    return [
        feedback_result_to_dict(result)
        for result in results
    ]


@app.get("/feedback/results/{result_id}")
def get_feedback_result(
    result_id: int,
    db: Session = Depends(get_db),
):
    result = (
        db.query(FeedbackResult)
        .filter(FeedbackResult.id == result_id)
        .first()
    )

    if result is None:
        return {
            "message": "결과를 찾을 수 없습니다."
        }

    return feedback_result_to_dict(result)


def feedback_result_to_dict(result: FeedbackResult):
    try:
        feedbacks = json.loads(result.feedbacks) if result.feedbacks else []
    except Exception:
        feedbacks = []

    # 새 AI 음성 분석 결과 불러오기
    voice_analysis = None

    try:
        if result.voice_analysis:
            voice_analysis = json.loads(result.voice_analysis)
    except (ValueError, TypeError):
        voice_analysis = None

    return {
        "id": result.id,
        "user_id": result.user_id,

        "category": result.category,
        "target_item": result.target_item,
        "video_path": result.video_path,
        "created_at": result.created_at.strftime("%Y-%m-%d %H:%M:%S")
        if result.created_at else "",

        "target_pronunciation": result.target_pronunciation,
        "whisper_result": result.whisper_result,
        "is_correct": result.is_correct,

        "speech_start_time": result.speech_start_time,
        "speech_end_time": result.speech_end_time,
        "speech_duration": result.speech_duration,
        "volume": result.volume,
        "energy_change": result.energy_change,
        "average_pitch": result.average_pitch,
        "pitch_change": result.pitch_change,

        "speed_score": result.speed_score,
        "duration_score": result.duration_score,
        "stability_score": result.stability_score,
        "pitch_score": result.pitch_score,
        "volume_score": result.volume_score,
        "audio_total_score": result.audio_total_score,

        "average_mouth_open_ratio": result.average_mouth_open_ratio,
        "max_mouth_open_ratio": result.max_mouth_open_ratio,
        "min_mouth_open_ratio": result.min_mouth_open_ratio,
        "lip_movement_change": result.lip_movement_change,
        "average_mouth_open_score": result.average_mouth_open_score,
        "max_mouth_open_score": result.max_mouth_open_score,
        "lip_movement_score": result.lip_movement_score,
        "visual_total_score": result.visual_total_score,

        "feedbacks": feedbacks,
        "voice_analysis": voice_analysis,
    }