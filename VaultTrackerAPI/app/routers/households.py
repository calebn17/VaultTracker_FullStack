"""
Household routes (/api/v1/households).

Create a household, issue invite codes, and join with a code (v1: max 2 members).
"""

import secrets
import string
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.database import get_db
from app.dependencies import get_current_user, require_current_household
from app.models.household import Household
from app.models.household_invite_code import TTL_SECONDS, HouseholdInviteCode
from app.models.household_membership import HouseholdMembership
from app.models.user import User
from app.rate_limit import (
    coerce_json_response,
    limiter,
    rate_limit_read,
    rate_limit_write,
)
from app.schemas.household import (
    HouseholdInviteCodeResponse,
    HouseholdJoinRequest,
    HouseholdMemberResponse,
    HouseholdResponse,
)

_CODE_ALPHABET = string.ascii_uppercase + string.digits
_CODE_LENGTH = 8
_MAX_MEMBERS_V1 = 2

router = APIRouter(prefix="/households", tags=["Households"])


def _normalize_invite_code(raw: str) -> str:
    return "".join(raw.split()).upper()


def _random_invite_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))


def _member_count(db: Session, household_id: str) -> int:
    return (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.household_id == household_id)
        .count()
    )


def _as_utc_aware(dt: datetime) -> datetime:
    """SQLite often returns naive datetimes even for `DateTime(timezone=True)`."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


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


@router.post("/invite-codes", response_model=HouseholdInviteCodeResponse)
@limiter.limit(rate_limit_write)
@coerce_json_response
async def create_invite_code(
    request: Request,
    household: Household = Depends(require_current_household),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Issue a single-use invite code for this household (caller must be a member).

    Returns **409** when the household already has the maximum member count (v1: 2).
    """
    if _member_count(db, household.id) >= _MAX_MEMBERS_V1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Household is full",
        )

    expires_at = datetime.now(timezone.utc) + timedelta(seconds=TTL_SECONDS)
    for _ in range(32):
        code = _random_invite_code()
        if (
            db.query(HouseholdInviteCode)
            .filter(HouseholdInviteCode.code == code)
            .first()
            is not None
        ):
            continue
        row = HouseholdInviteCode(
            household_id=household.id,
            code=code,
            created_by_user_id=current_user.id,
            expires_at=expires_at,
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return HouseholdInviteCodeResponse(code=code, expiresAt=row.expires_at)

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Could not allocate an invite code",
    )


@router.post("/join", response_model=HouseholdResponse)
@limiter.limit(rate_limit_write)
@coerce_json_response
async def join_household(
    request: Request,
    body: HouseholdJoinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Join a household using a valid, unused, non-expired invite code."""
    if (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == current_user.id)
        .first()
        is not None
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already a member of a household",
        )

    code = _normalize_invite_code(body.code)
    if not code:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invite code is required",
        )

    row = db.query(HouseholdInviteCode).filter(HouseholdInviteCode.code == code).first()
    now = datetime.now(timezone.utc)
    expires_at = _as_utc_aware(row.expires_at) if row is not None else None
    if (
        row is None
        or row.used_at is not None
        or expires_at is None
        or expires_at <= now
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invite code",
        )

    if _member_count(db, row.household_id) >= _MAX_MEMBERS_V1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Household is full",
        )

    household = db.query(Household).filter(Household.id == row.household_id).first()
    if household is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invite code",
        )

    membership = HouseholdMembership(
        household_id=household.id,
        user_id=current_user.id,
    )
    db.add(membership)
    row.used_at = now
    row.used_by_user_id = current_user.id
    db.commit()

    db.refresh(household)
    return _household_to_response(db, household)


@router.delete("/me/membership", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(rate_limit_write)
@coerce_json_response
async def leave_household(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Leave the current household.

    Deletes this user's membership. If no members remain, deletes the
    household row (cascading invite codes and memberships).
    """
    membership = (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == current_user.id)
        .first()
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not a member of a household",
        )
    household_id = membership.household_id
    db.delete(membership)
    db.flush()
    if _member_count(db, household_id) == 0:
        household = db.query(Household).filter(Household.id == household_id).first()
        if household is not None:
            db.delete(household)
    db.commit()


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
