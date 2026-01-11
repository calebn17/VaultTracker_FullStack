from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.asset import Asset
from app.schemas.dashboard import DashboardResponse, CategoryTotals, GroupedHolding

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("", response_model=DashboardResponse)
async def get_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get aggregated dashboard data including total net worth,
    category breakdowns, and grouped holdings.
    """
    assets = db.query(Asset).filter(Asset.user_id == current_user.id).all()

    # Calculate category totals
    category_totals = {
        "crypto": 0.0,
        "stocks": 0.0,
        "cash": 0.0,
        "realEstate": 0.0,
        "retirement": 0.0,
    }

    grouped_holdings: dict[str, list[GroupedHolding]] = {
        "crypto": [],
        "stocks": [],
        "cash": [],
        "realEstate": [],
        "retirement": [],
    }

    for asset in assets:
        category = asset.category
        if category in category_totals:
            category_totals[category] += asset.current_value
            grouped_holdings[category].append(
                GroupedHolding(
                    id=asset.id,
                    name=asset.name,
                    symbol=asset.symbol,
                    quantity=asset.quantity,
                    current_value=asset.current_value,
                )
            )

    total_net_worth = sum(category_totals.values())

    return DashboardResponse(
        totalNetWorth=total_net_worth,
        categoryTotals=CategoryTotals(**category_totals),
        groupedHoldings=grouped_holdings,
    )
