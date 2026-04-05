"""
Shared helpers for keeping Asset rows and NetWorthSnapshot rows aligned with
transactions.

Routers and TransactionService both use these so mark-to-market and snapshot
rules stay in one place.
"""

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.networth_snapshot import NetWorthSnapshot


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
