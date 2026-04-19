"""
Users router (/api/v1/users).

Currently exposes a single endpoint: DELETE /users/me/data, which wipes all
financial data for the authenticated user in FK dependency order —
transactions → snapshots → assets → accounts — plus saved FIRE calculator
inputs (`fire_profiles`), while preserving the user row itself. Bulk SQLAlchemy
deletes do not run ORM cascades; `FIREProfile` rows are removed explicitly.
Invalidates per-user response caches (dashboard, analytics, net worth).
This endpoint is used by integration tests to reset state between runs.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.database import get_db
from app.dependencies import get_current_user
from app.models.account import Account
from app.models.asset import Asset
from app.models.fire_profile import FIREProfile
from app.models.networth_snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User
from app.rate_limit import coerce_json_response, limiter, rate_limit_write
from app.services.cache_service import invalidate_portfolio_caches

router = APIRouter(prefix="/users", tags=["Users"])


@router.delete("/me/data", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(rate_limit_write)
@coerce_json_response
async def clear_user_data(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Delete all financial data for the current user.
    Removes all transactions, assets, accounts, net worth snapshots, and the
    FIRE profile row (if any). The user account itself is preserved.
    """
    db.query(Transaction).filter(Transaction.user_id == current_user.id).delete()
    db.query(NetWorthSnapshot).filter(
        NetWorthSnapshot.user_id == current_user.id
    ).delete()
    db.query(Asset).filter(Asset.user_id == current_user.id).delete()
    db.query(Account).filter(Account.user_id == current_user.id).delete()
    db.query(FIREProfile).filter(FIREProfile.user_id == current_user.id).delete()
    db.commit()
    invalidate_portfolio_caches(db, current_user.id)
