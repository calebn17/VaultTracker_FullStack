"""
Users router (/api/v1/users).

Currently exposes a single endpoint: DELETE /users/me/data, which wipes all
financial data for the authenticated user in FK dependency order —
transactions → snapshots → assets → accounts — while preserving the user row
itself. This endpoint is used by integration tests to reset state between runs.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.account import Account
from app.models.asset import Asset
from app.models.transaction import Transaction
from app.models.networth_snapshot import NetWorthSnapshot

router = APIRouter(prefix="/users", tags=["Users"])


@router.delete("/me/data", status_code=status.HTTP_204_NO_CONTENT)
async def clear_user_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete all financial data for the current user.
    Removes all transactions, assets, accounts, and net worth snapshots.
    The user account itself is preserved.
    """
    db.query(Transaction).filter(Transaction.user_id == current_user.id).delete()
    db.query(NetWorthSnapshot).filter(NetWorthSnapshot.user_id == current_user.id).delete()
    db.query(Asset).filter(Asset.user_id == current_user.id).delete()
    db.query(Account).filter(Account.user_id == current_user.id).delete()
    db.commit()
