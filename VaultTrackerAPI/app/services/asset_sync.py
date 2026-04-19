"""
Shared helpers for keeping Asset rows and NetWorthSnapshot rows aligned with
transactions.

Routers and TransactionService both use these so mark-to-market and snapshot
rules stay in one place.
"""

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.household_membership import HouseholdMembership
from app.models.household_networth_snapshot import HouseholdNetWorthSnapshot
from app.models.networth_snapshot import NetWorthSnapshot


def _household_total_net_worth(db: Session, household_id: str) -> float:
    """Sum each member's asset ``current_value`` (same basis as per-user snapshots)."""
    member_ids = [
        m.user_id
        for m in db.query(HouseholdMembership)
        .filter(HouseholdMembership.household_id == household_id)
        .all()
    ]
    if not member_ids:
        return 0.0
    assets = db.query(Asset).filter(Asset.user_id.in_(member_ids)).all()
    return sum(a.current_value or 0.0 for a in assets)


def _sync_household_networth_snapshot(
    db: Session, user_id: str, when: datetime
) -> None:
    """
    If the user is in a household, upsert a HouseholdNetWorthSnapshot at `when`
    with the combined member total (same timestamp as the triggering user row).

    ``HouseholdNetWorthSnapshot.date`` is ``DateTime(timezone=True)``, not a
    calendar date type: it intentionally stores the same UTC instant as the
    sibling ``NetWorthSnapshot`` row so upserts align on backdated trades and
    chart aggregation stays consistent with per-user history.
    """
    membership = (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == user_id)
        .first()
    )
    if membership is None:
        return
    hid = membership.household_id
    total = _household_total_net_worth(db, hid)
    existing = (
        db.query(HouseholdNetWorthSnapshot)
        .filter(
            HouseholdNetWorthSnapshot.household_id == hid,
            HouseholdNetWorthSnapshot.date == when,
        )
        .first()
    )
    if existing is not None:
        existing.value = total
    else:
        db.add(
            HouseholdNetWorthSnapshot(
                household_id=hid,
                date=when,
                value=total,
            )
        )


def record_networth_snapshot(
    db: Session,
    user_id: str,
    *,
    snapshot_at: datetime | None = None,
) -> None:
    """
    Sum current_value across all user assets and save a NetWorthSnapshot.
    Called after every transaction write so the chart always has fresh data.

    snapshot_at: Time for this snapshot row (UTC). Defaults to "now" (e.g. price
    refresh, delete). Pass the transaction's trade date after create/update so
    backdated trades produce distinct points on the net-worth chart.
    """
    assets = db.query(Asset).filter(Asset.user_id == user_id).all()
    net_worth = sum(a.current_value or 0.0 for a in assets)
    when = snapshot_at if snapshot_at is not None else datetime.now(timezone.utc)
    if when.tzinfo is None:
        when = when.replace(tzinfo=timezone.utc)
    else:
        when = when.astimezone(timezone.utc)
    snapshot = NetWorthSnapshot(user_id=user_id, value=net_worth, date=when)
    db.add(snapshot)
    _sync_household_networth_snapshot(db, user_id, when)


def update_asset_from_transaction(
    db: Session,
    asset: Asset,
    transaction_type: str,
    quantity: float,
    price_per_unit: float,
    is_reversal: bool = False,
) -> None:
    """
    Adjust an asset's quantity and recompute its current_value after a transaction.

    Pass `is_reversal=True` to undo the effect of an existing transaction (used
    during updates and deletes). After adjusting quantity, current_value is set to
    `quantity * price_per_unit` — mark-to-market, not a running cost-basis sum.
    """
    if is_reversal:
        if transaction_type == "buy":
            asset.quantity -= quantity
        else:
            asset.quantity += quantity
    else:
        if transaction_type == "buy":
            asset.quantity += quantity
        else:
            asset.quantity -= quantity

    asset.current_value = asset.quantity * price_per_unit
    asset.last_updated = datetime.now(timezone.utc)


def is_empty_position(asset: Asset) -> bool:
    """
    True when quantity and mark-to-market value are both zero (no visible holding).
    """
    return abs(asset.quantity or 0.0) < 1e-9 and abs(asset.current_value or 0.0) < 1e-9
