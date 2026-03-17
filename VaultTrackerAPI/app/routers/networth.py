from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import asc

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.networth_snapshot import NetWorthSnapshot
from app.schemas.networth import NetWorthHistoryResponse, NetWorthSnapshotResponse

router = APIRouter(prefix="/networth", tags=["Net Worth"])


@router.get("/history", response_model=NetWorthHistoryResponse)
async def get_networth_history(
    period: str = Query("daily", description="Period filter: daily, weekly, monthly"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get the user's net worth history snapshots.

    The period parameter is accepted but currently returns all snapshots.
    In a production system, this would filter/aggregate based on the period.
    """
    snapshots = (
        db.query(NetWorthSnapshot)
        .filter(NetWorthSnapshot.user_id == current_user.id)
        .order_by(asc(NetWorthSnapshot.date))
        .all()
    )

    return NetWorthHistoryResponse(
        snapshots=[
            NetWorthSnapshotResponse(date=s.date, value=s.value)
            for s in snapshots
        ]
    )
