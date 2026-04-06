from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import asc
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.networth_snapshot import NetWorthSnapshot
from app.models.user import User
from app.schemas.networth import NetWorthHistoryResponse, NetWorthSnapshotResponse
from app.services.cache_service import cache

router = APIRouter(prefix="/networth", tags=["Net Worth"])


def _utc_date(dt: datetime):
    if dt.tzinfo is None:
        return dt.date()
    return dt.astimezone(timezone.utc).date()


def _aggregate_snapshots(
    snapshots: list[NetWorthSnapshot], period: str
) -> list[NetWorthSnapshotResponse]:
    p = period.lower().strip()
    if p == "all":
        return [NetWorthSnapshotResponse(date=s.date, value=s.value) for s in snapshots]

    if p == "daily":
        grouped: dict = {}
        for s in snapshots:
            day = _utc_date(s.date)
            grouped[day] = s
        out = sorted(grouped.items(), key=lambda kv: kv[0])
        return [NetWorthSnapshotResponse(date=v.date, value=v.value) for _, v in out]

    if p == "weekly":
        # Last snapshot per ISO calendar week (UTC).
        grouped = {}
        for s in snapshots:
            d = s.date
            if d.tzinfo is None:
                y, w, _ = d.isocalendar()
            else:
                y, w, _ = d.astimezone(timezone.utc).isocalendar()
            grouped[(y, w)] = s
        out = sorted(grouped.items(), key=lambda kv: (kv[0][0], kv[0][1]))
        return [NetWorthSnapshotResponse(date=v.date, value=v.value) for _, v in out]

    if p == "monthly":
        grouped = {}
        for s in snapshots:
            d = _utc_date(s.date)
            key = (d.year, d.month)
            grouped[key] = s
        out = sorted(grouped.items(), key=lambda kv: (kv[0][0], kv[0][1]))
        return [NetWorthSnapshotResponse(date=v.date, value=v.value) for _, v in out]

    # Unknown period — return full series (backward compatible).
    return [NetWorthSnapshotResponse(date=s.date, value=s.value) for s in snapshots]


@router.get("/history", response_model=NetWorthHistoryResponse)
async def get_networth_history(
    period: str = Query(
        "daily", description="daily | weekly | monthly | all (unknown → all snapshots)"
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cache_key = f"networth:history:{current_user.id}:{period.lower().strip()}"
    cached = cache.get(cache_key)
    if cached is not None:
        return NetWorthHistoryResponse.model_validate(cached)

    snapshots = (
        db.query(NetWorthSnapshot)
        .filter(NetWorthSnapshot.user_id == current_user.id)
        .order_by(asc(NetWorthSnapshot.date))
        .all()
    )

    items = _aggregate_snapshots(snapshots, period)
    result = NetWorthHistoryResponse(snapshots=items)
    cache.set(cache_key, result.model_dump(mode="python"))
    return result
