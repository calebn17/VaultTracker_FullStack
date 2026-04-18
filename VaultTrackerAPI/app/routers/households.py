"""
Household routes (/api/v1/households).

Create a household; join flow caps membership at 2 in a later endpoint.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.database import get_db
from app.dependencies import get_current_user, require_current_household
from app.models.household import Household
from app.models.household_membership import HouseholdMembership
from app.models.user import User
from app.rate_limit import (
    coerce_json_response,
    limiter,
    rate_limit_read,
    rate_limit_write,
)
from app.schemas.household import HouseholdMemberResponse, HouseholdResponse

router = APIRouter(prefix="/households", tags=["Households"])


def _household_to_response(db: Session, household: Household) -> HouseholdResponse:
    rows = (
        db.query(HouseholdMembership, User)
        .join(User, HouseholdMembership.user_id == User.id)
        .filter(HouseholdMembership.household_id == household.id)
        .order_by(HouseholdMembership.joined_at.asc())
        .all()
    )
    members = [HouseholdMemberResponse(userId=u.id, email=u.email) for _m, u in rows]
    return HouseholdResponse(
        id=household.id,
        createdAt=household.created_at,
        members=members,
    )


@router.post("", response_model=HouseholdResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(rate_limit_write)
@coerce_json_response(json_status_code=201)
async def create_household(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new household and add the caller as the first member."""
    existing = (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == current_user.id)
        .first()
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already a member of a household",
        )

    household = Household()
    db.add(household)
    db.flush()
    membership = HouseholdMembership(
        household_id=household.id,
        user_id=current_user.id,
    )
    db.add(membership)
    db.commit()
    db.refresh(household)

    return _household_to_response(db, household)


@router.get("/me", response_model=HouseholdResponse)
@limiter.limit(rate_limit_read)
@coerce_json_response
async def get_my_household(
    request: Request,
    household: Household = Depends(require_current_household),
    db: Session = Depends(get_db),
):
    """Return the caller's household and members (404 if not in any household)."""
    return _household_to_response(db, household)
