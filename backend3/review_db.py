"""Review queue database model (independent from pronunciation results)."""
from datetime import datetime, timedelta, timezone

from sqlalchemy import Column, DateTime, Integer, String
from database import Base


def korea_now():
    return datetime.now(timezone(timedelta(hours=9))).replace(tzinfo=None)


class ReviewQueueEntry(Base):
    __tablename__ = "review_queue_entries"

    id = Column(Integer, primary_key=True)
    # Currently this is a single-user prototype: one row per Hangul phoneme.
    phoneme = Column(String(8), unique=True, nullable=False, index=True)
    created_at = Column(DateTime, default=korea_now, nullable=False)
    # Date in Asia/Seoul. Only one successful review per phoneme per day.
    last_reviewed_on = Column(String(10), nullable=True)
