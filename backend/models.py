from sqlalchemy import Column, Integer, String, Float, Boolean, Text, DateTime
from datetime import datetime
from zoneinfo import ZoneInfo

from database import Base

def get_korea_now():
    return datetime.now(ZoneInfo("Asia/Seoul"))

class FeedbackResult(Base):
    __tablename__ = "feedback_results"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)

    category = Column(String, nullable=False)
    target_item = Column(String, nullable=False)
    video_path = Column(Text, nullable=False)
    created_at = Column(DateTime, default=get_korea_now)

    # 기본 정보
    target_pronunciation = Column(String, default="")
    whisper_result = Column(String, default="")
    is_correct = Column(Boolean, default=False)

    # Librosa 음성 분석
    speech_start_time = Column(Float, default=0.0)
    speech_end_time = Column(Float, default=0.0)
    speech_duration = Column(Float, default=0.0)
    volume = Column(Float, default=0.0)
    energy_change = Column(Float, default=0.0)
    average_pitch = Column(Float, default=0.0)
    pitch_change = Column(Float, default=0.0)

    # Librosa 음성 평가 점수
    speed_score = Column(Float, default=0.0)
    duration_score = Column(Float, default=0.0)
    stability_score = Column(Float, default=0.0)
    pitch_score = Column(Float, default=0.0)
    volume_score = Column(Float, default=0.0)
    audio_total_score = Column(Float, default=0.0)

    # 입모양 분석 점수
    average_mouth_open_ratio = Column(Float, default=0.0)
    max_mouth_open_ratio = Column(Float, default=0.0)
    min_mouth_open_ratio = Column(Float, default=0.0)
    lip_movement_change = Column(Float, default=0.0)
    average_mouth_open_score = Column(Float, default=0.0)
    max_mouth_open_score = Column(Float, default=0.0)
    lip_movement_score = Column(Float, default=0.0)
    visual_total_score = Column(Float, default=0.0)

    # JSON 문자열로 저장
    feedbacks = Column(Text, default="[]")