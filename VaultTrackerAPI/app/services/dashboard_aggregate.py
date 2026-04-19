"""
Shared dashboard aggregation: category totals, net worth, grouped holdings.

Used by GET /dashboard and (later) FIRE projection so portfolio numbers stay
consistent. Category keys are fixed contract values (camelCase realEstate, etc.).
"""

from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.household_membership import HouseholdMembership
from app.models.user import User
from app.schemas.dashboard import (
    CategoryTotals,
    DashboardResponse,
    GroupedHolding,
    HouseholdDashboardResponse,
    HouseholdMemberDashboard,
)
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


def aggregate_household_dashboard(
    db: Session, household_id: str
) -> HouseholdDashboardResponse:
    """
    Build a merged household dashboard: sum members' totals plus each member's
    own `aggregate_dashboard` slice (join order preserved).
    """
    memberships = (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.household_id == household_id)
        .order_by(HouseholdMembership.joined_at.asc())
        .all()
    )

    merged = {
        "crypto": 0.0,
        "stocks": 0.0,
        "cash": 0.0,
        "realEstate": 0.0,
        "retirement": 0.0,
    }
    members: list[HouseholdMemberDashboard] = []

    for m in memberships:
        u = db.query(User).filter(User.id == m.user_id).first()
        if u is None:
            continue
        one = aggregate_dashboard(db, m.user_id)
        members.append(
            HouseholdMemberDashboard(
                userId=m.user_id,
                email=u.email,
                totalNetWorth=one.totalNetWorth,
                categoryTotals=one.categoryTotals,
                groupedHoldings=one.groupedHoldings,
            )
        )
        merged["crypto"] += one.categoryTotals.crypto
        merged["stocks"] += one.categoryTotals.stocks
        merged["cash"] += one.categoryTotals.cash
        merged["realEstate"] += one.categoryTotals.realEstate
        merged["retirement"] += one.categoryTotals.retirement

    total_net = sum(merged.values())
    return HouseholdDashboardResponse(
        householdId=household_id,
        totalNetWorth=total_net,
        categoryTotals=CategoryTotals(**merged),
        members=members,
    )
