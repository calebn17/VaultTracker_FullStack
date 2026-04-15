"""
Dashboard router (/api/v1/dashboard).

Aggregates all assets for the authenticated user into five category buckets:
crypto, stocks, cash, realEstate, retirement. The category key names are camelCase
and must stay in sync with what iOS DashboardMapper expects when parsing the
`groupedHoldings` dictionary. Totals per category and overall net worth are
computed server-side to avoid redundant client calculations.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.rate_limit import coerce_json_response, limiter, rate_limit_read
from app.schemas.dashboard import DashboardResponse
from app.services.cache_service import cache
from app.services.dashboard_aggregate import aggregate_dashboard

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("", response_model=DashboardResponse)
@limiter.limit(rate_limit_read)
@coerce_json_response
async def get_dashboard(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get aggregated dashboard data including total net worth,
    category breakdowns, and grouped holdings.
    """
    cache_key = f"dashboard:{current_user.id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return DashboardResponse.model_validate(cached)

    result = aggregate_dashboard(db, current_user.id)
    cache.set(cache_key, result.model_dump(mode="python"))
    return result
