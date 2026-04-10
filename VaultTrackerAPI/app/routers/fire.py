"""
FIRE calculator routes (/api/v1/fire).
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.fire_profile import FIREProfile
from app.models.user import User
from app.schemas.fire import (
    FIREProfileInput,
    FIREProfileResponse,
    FIREProjectionResponse,
)
from app.services.fire_projection import build_fire_projection, profile_to_response

router = APIRouter(prefix="/fire", tags=["FIRE"])


@router.get("/profile", response_model=FIREProfileResponse)
async def get_fire_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = (
        db.query(FIREProfile)
        .filter(FIREProfile.user_id == current_user.id)
        .one_or_none()
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="FIRE profile not found"
        )
    return profile_to_response(row)


@router.put("/profile", response_model=FIREProfileResponse)
async def upsert_fire_profile(
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
        row.current_age = body.currentAge
        row.annual_income = body.annualIncome
        row.annual_expenses = body.annualExpenses
        row.target_retirement_age = body.targetRetirementAge
    db.commit()
    db.refresh(row)
    return profile_to_response(row)


@router.get("/projection", response_model=FIREProjectionResponse)
async def get_fire_projection(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    row = (
        db.query(FIREProfile)
        .filter(FIREProfile.user_id == current_user.id)
        .one_or_none()
    )
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="FIRE profile not found"
        )
    return build_fire_projection(db, row)
