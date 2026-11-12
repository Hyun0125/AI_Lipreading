"""Review queue CRUD + automatic daily completion via existing SQLite DB."""
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import SessionLocal
from review_db import ReviewQueueEntry

router = APIRouter(prefix="/review/queue", tags=["review-queue"])

CONSONANTS = set("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
VOWELS = set("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
ALLOWED_PHONEMES = CONSONANTS | VOWELS


class IncludeRequest(BaseModel):
    included: bool


class ReviewedRequest(BaseModel):
    reviewed: bool


def get_review_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _today():
    return datetime.now(timezone(timedelta(hours=9))).date().isoformat()


def _validate(phoneme: str) -> str:
    if phoneme not in ALLOWED_PHONEMES:
        raise HTTPException(status_code=422, detail="지원하지 않는 자음 또는 모음입니다.")
    return phoneme


@router.get("")
def get_review_queue(db: Session = Depends(get_review_db)):
    today = _today()
    rows = db.query(ReviewQueueEntry).order_by(ReviewQueueEntry.phoneme).all()
    return {
        "items": [
            {"phoneme": row.phoneme, "reviewed_today": row.last_reviewed_on == today}
            for row in rows
        ]
    }


@router.put("/{phoneme}")
def set_review_included(
    phoneme: str,
    body: IncludeRequest,
    db: Session = Depends(get_review_db),
):
    phoneme = _validate(phoneme)
    row = db.query(ReviewQueueEntry).filter_by(phoneme=phoneme).one_or_none()
    if body.included:
        if row is None:
            db.add(ReviewQueueEntry(phoneme=phoneme))
    elif row is not None:
        db.delete(row)
    db.commit()
    return {"phoneme": phoneme, "included": body.included}


@router.put("/{phoneme}/reviewed")
def set_reviewed_today(
    phoneme: str,
    body: ReviewedRequest,
    db: Session = Depends(get_review_db),
):
    phoneme = _validate(phoneme)
    row = db.query(ReviewQueueEntry).filter_by(phoneme=phoneme).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="복습 목록에 없는 발음입니다.")
    if body.reviewed:
        row.last_reviewed_on = _today()
    elif row.last_reviewed_on == _today():
        row.last_reviewed_on = None
    db.commit()
    return {"phoneme": phoneme, "reviewed_today": row.last_reviewed_on == _today()}


@router.post("/{phoneme}/complete")
def complete_review_after_practice(
    phoneme: str,
    db: Session = Depends(get_review_db),
):
    phoneme = _validate(phoneme)
    row = db.query(ReviewQueueEntry).filter_by(phoneme=phoneme).one_or_none()
    if row is None or row.last_reviewed_on == _today():
        return {"marked": False}
    row.last_reviewed_on = _today()
    db.commit()
    return {"marked": True}
