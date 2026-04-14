"""
FIRE calculator routes (/api/v1/fire).
"""

from fastapi import APIRouter, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.database import get_db
from app.dependencies import get_current_user
from app.models.fire_profile import FIREProfile
from app.models.user import User
from app.rate_limit import (
    coerce_json_response,
    limiter,
    rate_limit_read,
    rate_limit_write,
)
from app.schemas.fire import (
    FIREProfileInput,
    FIREProfileResponse,
    FIREProjectionResponse,
)
from app.services.fire_projection import build_fire_projection, profile_to_response

router = APIRouter(prefix="/fire", tags=["FIRE"])

# Defaults aligned with web FIRE form; see seed_demo_portfolio.ensure_demo_fire_profile.
_DEFAULT_FIRE_AGE = 30
_DEFAULT_FIRE_INCOME = 0.0
_DEFAULT_FIRE_EXPENSES = 0.0


def _get_or_create_fire_profile(db: Session, user_id: str) -> FIREProfile:
    row = db.query(FIREProfile).filter(FIREProfile.user_id == user_id).one_or_none()
    if row is not None:
        return row
    row = FIREProfile(
        user_id=user_id,
        current_age=_DEFAULT_FIRE_AGE,
        annual_income=_DEFAULT_FIRE_INCOME,
        annual_expenses=_DEFAULT_FIRE_EXPENSES,
        target_retirement_age=None,
    )
    db.add(row)
    try:
        db.commit()
        db.refresh(row)
        return row
    except IntegrityError:
        db.rollback()
        row = db.query(FIREProfile).filter(FIREProfile.user_id == user_id).one_or_none()
        if row is None:
            raise
        return row


def _apply_fire_profile_input(row: FIREProfile, body: FIREProfileInput) -> None:
    row.current_age = body.currentAge
    row.annual_income = body.annualIncome
    row.annual_expenses = body.annualExpenses
    row.target_retirement_age = body.targetRetirementAge


@router.get("/profile", response_model=FIREProfileResponse)
@limiter.limit(rate_limit_read)
@coerce_json_response
async def get_fire_profile(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = _get_or_create_fire_profile(db, current_user.id)
    return profile_to_response(row)


@router.put("/profile", response_model=FIREProfileResponse)
@limiter.limit(rate_limit_write)
@coerce_json_response
async def upsert_fire_profile(
    request: Request,
    body: FIREProfileInput,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = (
        db.query(FIREProfile)
        .filter(FIREProfile.user_id == current_user.id)
        .one_or_none()
    )
    if row is None:
        row = FIREProfile(
            user_id=current_user.id,
            current_age=body.currentAge,
            annual_income=body.annualIncome,
            annual_expenses=body.annualExpenses,
            target_retirement_age=body.targetRetirementAge,
        )
        db.add(row)
    else:
        _apply_fire_profile_input(row, body)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        row = (
            db.query(FIREProfile)
            .filter(FIREProfile.user_id == current_user.id)
            .one_or_none()
        )
        if row is None:
            raise
        _apply_fire_profile_input(row, body)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise
    except Exception:
        db.rollback()
        raise

    db.refresh(row)
    return profile_to_response(row)


@router.get("/projection", response_model=FIREProjectionResponse)
@limiter.limit(rate_limit_read)
@coerce_json_response
async def get_fire_projection(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = _get_or_create_fire_profile(db, current_user.id)
    return build_fire_projection(db, row)
