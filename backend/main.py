import os
import shutil
import json
from datetime import datetime, timezone, timedelta

from fastapi import FastAPI, UploadFile, File, Form, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import Base, engine, SessionLocal
from models import FeedbackResult
from ai.analyze import analyze_pronunciation

Base.metadata.create_all(bind=engine)

app = FastAPI()

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

    speech_start_time: float = 0.0
    speech_end_time: float = 0.0
    speech_duration: float = 0.0
    volume: float = 0.0
    energy_change: float = 0.0
    average_pitch: float = 0.0
    pitch_change: float = 0.0

    speed_score: float = 0.0
    duration_score: float = 0.0
    stability_score: float = 0.0
    pitch_score: float = 0.0
    volume_score: float = 0.0
    audio_total_score: float = 0.0

    average_mouth_open_ratio: float = 0.0
    max_mouth_open_ratio: float = 0.0
    min_mouth_open_ratio: float = 0.0
    lip_movement_change: float = 0.0
    average_mouth_open_score: float = 0.0
    max_mouth_open_score: float = 0.0
    lip_movement_score: float = 0.0
    visual_total_score: float = 0.0

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
    now = get_korea_now()
    timestamp = now.strftime("%Y%m%d_%H%M%S")

    safe_category = category.replace("/", "_").replace("\\", "_")
    safe_item = target_item.replace("/", "_").replace("\\", "_")

    original_filename = video.filename or "recorded_video.mp4"
    safe_filename = original_filename.replace("/", "_").replace("\\", "_")

    filename = f"{safe_category}_{safe_item}_{timestamp}_{safe_filename}"

    temp_video_path = os.path.join(TEMP_UPLOAD_DIR, filename)
    temp_video_path = temp_video_path.replace("\\", "/")

    with open(temp_video_path, "wb") as buffer:
        shutil.copyfileobj(video.file, buffer)

    result = analyze_pronunciation(
        video_path=temp_video_path,
        category=category,
        target_item=target_item,
    )

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
    saved_filename = f"saved_{timestamp}_{original_filename}"

    saved_video_path = os.path.join(SAVED_UPLOAD_DIR, saved_filename)
    saved_video_path = saved_video_path.replace("\\", "/")

    shutil.copyfile(request.video_path, saved_video_path)

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

        speech_start_time=request.speech_start_time,
        speech_end_time=request.speech_end_time,
        speech_duration=request.speech_duration,
        volume=request.volume,
        energy_change=request.energy_change,
        average_pitch=request.average_pitch,
        pitch_change=request.pitch_change,

        speed_score=request.speed_score,
        duration_score=request.duration_score,
        stability_score=request.stability_score,
        pitch_score=request.pitch_score,
        volume_score=request.volume_score,
        audio_total_score=request.audio_total_score,

        average_mouth_open_ratio=request.average_mouth_open_ratio,
        max_mouth_open_ratio=request.max_mouth_open_ratio,
        min_mouth_open_ratio=request.min_mouth_open_ratio,
        lip_movement_change=request.lip_movement_change,
        average_mouth_open_score=request.average_mouth_open_score,
        max_mouth_open_score=request.max_mouth_open_score,
        lip_movement_score=request.lip_movement_score,
        visual_total_score=request.visual_total_score,

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