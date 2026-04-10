"""
Shared dashboard aggregation: category totals, net worth, grouped holdings.

Used by GET /dashboard and (later) FIRE projection so portfolio numbers stay
consistent. Category keys are fixed contract values (camelCase realEstate, etc.).
"""

from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.schemas.dashboard import CategoryTotals, DashboardResponse, GroupedHolding
from app.services.asset_sync import is_empty_position


def aggregate_dashboard(db: Session, user_id: str) -> DashboardResponse:
    """Load the user's non-empty asset positions and build a dashboard response."""
    assets = db.query(Asset).filter(Asset.user_id == user_id).all()

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
            if is_empty_position(asset):
                continue
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
