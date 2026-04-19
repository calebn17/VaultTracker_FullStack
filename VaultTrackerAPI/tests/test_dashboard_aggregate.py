"""Direct tests for dashboard aggregation helper (no HTTP)."""

from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.household import Household
from app.models.household_membership import HouseholdMembership
from app.models.user import User
from app.services.dashboard_aggregate import (
    aggregate_dashboard,
    aggregate_household_dashboard,
)


def test_aggregate_dashboard_sums_categories_and_skips_empty_positions(
    db_session: Session,
) -> None:
    # Two funded assets count toward totals; a dust position (both fields < 1e-9)
    # is omitted.
    user = User(firebase_id="dash-agg-user")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    db_session.add_all(
        [
            Asset(
                user_id=user.id,
                name="Apple",
                symbol="AAPL",
                category="stocks",
                quantity=10.0,
                current_value=1000.0,
            ),
            Asset(
                user_id=user.id,
                name="Bitcoin",
                symbol="BTC",
                category="crypto",
                quantity=0.5,
                current_value=500.0,
            ),
            Asset(
                user_id=user.id,
                name="Dust stock",
                symbol="ZZZ",
                category="stocks",
                # Non-zero but below is_empty_position epsilon — not counted or listed.
                quantity=5e-10,
                current_value=5e-10,
            ),
        ]
    )
    db_session.commit()

    out = aggregate_dashboard(db_session, user.id)

    assert out.totalNetWorth == 1500.0
    assert out.categoryTotals.stocks == 1000.0
    assert out.categoryTotals.crypto == 500.0
    assert out.categoryTotals.cash == 0.0
    names = {h.name for h in out.groupedHoldings["stocks"]}
    assert names == {"Apple"}
    assert {h.name for h in out.groupedHoldings["crypto"]} == {"Bitcoin"}


def test_aggregate_dashboard_ignores_unknown_category(db_session: Session) -> None:
    # Assets with a category outside the five buckets do not affect totals.
    user = User(firebase_id="dash-agg-unknown-cat")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)

    db_session.add(
        Asset(
            user_id=user.id,
            name="Odd",
            symbol=None,
            category="other",
            quantity=1.0,
            current_value=999.0,
        )
    )
    db_session.commit()

    out = aggregate_dashboard(db_session, user.id)
    assert out.totalNetWorth == 0.0
    assert sum(len(v) for v in out.groupedHoldings.values()) == 0


def test_aggregate_household_dashboard_merges_members(db_session: Session) -> None:
    u1 = User(firebase_id="hh-u1")
    u2 = User(firebase_id="hh-u2")
    db_session.add_all([u1, u2])
    db_session.commit()
    db_session.refresh(u1)
    db_session.refresh(u2)

    h = Household()
    db_session.add(h)
    db_session.flush()
    db_session.add_all(
        [
            HouseholdMembership(household_id=h.id, user_id=u1.id),
            HouseholdMembership(household_id=h.id, user_id=u2.id),
        ]
    )
    db_session.add_all(
        [
            Asset(
                user_id=u1.id,
                name="BTC",
                symbol="BTC",
                category="crypto",
                quantity=1.0,
                current_value=100.0,
            ),
            Asset(
                user_id=u2.id,
                name="Cash",
                symbol=None,
                category="cash",
                quantity=1.0,
                current_value=50.0,
            ),
        ]
    )
    db_session.commit()

    out = aggregate_household_dashboard(db_session, h.id)
    assert out.householdId == h.id
    assert out.totalNetWorth == 150.0
    assert out.categoryTotals.crypto == 100.0
    assert out.categoryTotals.cash == 50.0
    assert len(out.members) == 2
    assert {m.userId for m in out.members} == {u1.id, u2.id}
    by_id = {m.userId: m for m in out.members}
    assert by_id[u1.id].totalNetWorth == 100.0
    assert by_id[u2.id].totalNetWorth == 50.0
