"""
Transaction CRUD router (/api/v1/transactions).

Every write operation (create, update, delete) calls `update_asset_from_transaction`
to keep the parent asset in sync. Asset value is tracked mark-to-market:
    current_value = quantity * latest_price_per_unit
This is not a cost-basis sum — the most recent price_per_unit supplied by the
client is used to revalue the entire position each time a transaction is recorded.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.dependencies import get_current_user
from app.models.account import Account
from app.models.asset import Asset
from app.models.networth_snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.transaction import (
    AccountSummary,
    AssetSummary,
    EnrichedTransactionResponse,
    SmartTransactionCreate,
    TransactionCreate,
    TransactionResponse,
    TransactionUpdate,
)
from app.services.asset_sync import (
    record_networth_snapshot,
    update_asset_from_transaction,
)
from app.services.cache_service import cache
from app.services.transaction_service import (
    SmartUpdateMissingLinkedAssetError,
    TransactionService,
)

router = APIRouter(prefix="/transactions", tags=["Transactions"])


def _to_enriched(t: Transaction) -> EnrichedTransactionResponse:
    a = t.asset
    ac = t.account
    return EnrichedTransactionResponse(
        id=t.id,
        user_id=t.user_id,
        asset_id=t.asset_id,
        account_id=t.account_id,
        transaction_type=t.transaction_type,
        quantity=t.quantity,
        price_per_unit=t.price_per_unit,
        total_value=t.quantity * t.price_per_unit,
        date=t.date,
        asset=AssetSummary(
            id=a.id,
            name=a.name,
            symbol=a.symbol,
            category=a.category,
        ),
        account=AccountSummary(
            id=ac.id,
            name=ac.name,
            account_type=ac.account_type,
        ),
    )


@router.get("", response_model=list[EnrichedTransactionResponse])
async def get_transactions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List transactions with nested asset and account summaries."""
    rows = (
        db.query(Transaction)
        .options(joinedload(Transaction.asset), joinedload(Transaction.account))
        .filter(Transaction.user_id == current_user.id)
        .order_by(desc(Transaction.date))
        .all()
    )
    return [_to_enriched(t) for t in rows]


@router.post(
    "/smart", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED
)
async def create_smart_transaction(
    body: SmartTransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Create account/asset if needed, then record one transaction
    (server-side resolution).
    """
    service = TransactionService()
    tx = service.smart_create(body, current_user, db)
    return tx


@router.post(
    "", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED
)
async def create_transaction(
    transaction: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Create a new transaction.
    This will automatically update the related asset's quantity and value.
    """
    asset = (
        db.query(Asset)
        .filter(
            Asset.id == transaction.asset_id,
            Asset.user_id == current_user.id,
        )
        .first()
    )

    if not asset:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asset not found",
        )

    account = (
        db.query(Account)
        .filter(
            Account.id == transaction.account_id,
            Account.user_id == current_user.id,
        )
        .first()
    )

    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    when = (
        transaction.date if transaction.date is not None else datetime.now(timezone.utc)
    )
    db_transaction = Transaction(
        user_id=current_user.id,
        asset_id=transaction.asset_id,
        account_id=transaction.account_id,
        transaction_type=transaction.transaction_type,
        quantity=transaction.quantity,
        price_per_unit=transaction.price_per_unit,
        date=when,
    )
    db.add(db_transaction)

    update_asset_from_transaction(
        db,
        asset,
        transaction.transaction_type,
        transaction.quantity,
        transaction.price_per_unit,
    )

    record_networth_snapshot(db, current_user.id, snapshot_at=when)
    db.commit()
    db.refresh(db_transaction)
    cache.invalidate_user(current_user.id)
    return db_transaction


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a specific transaction by ID."""
    transaction = (
        db.query(Transaction)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id,
        )
        .first()
    )

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )
    return transaction


@router.put("/{transaction_id}/smart", response_model=TransactionResponse)
async def update_smart_transaction(
    transaction_id: str,
    body: SmartTransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Update a transaction using the same smart payload as POST /smart
    (re-resolves account + asset).
    """
    service = TransactionService()
    try:
        tx = service.smart_update(transaction_id, body, current_user, db)
    except SmartUpdateMissingLinkedAssetError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Transaction references a missing asset",
        ) from None
    if not tx:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )
    return tx


@router.put("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: str,
    transaction_update: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update an existing transaction."""
    transaction = (
        db.query(Transaction)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id,
        )
        .first()
    )

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    asset = db.query(Asset).filter(Asset.id == transaction.asset_id).first()
    if not asset:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Transaction references a missing asset",
        )

    update_asset_from_transaction(
        db,
        asset,
        transaction.transaction_type,
        transaction.quantity,
        transaction.price_per_unit,
        is_reversal=True,
    )

    update_data = transaction_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(transaction, field, value)

    update_asset_from_transaction(
        db,
        asset,
        transaction.transaction_type,
        transaction.quantity,
        transaction.price_per_unit,
    )

    record_networth_snapshot(db, current_user.id, snapshot_at=transaction.date)
    db.commit()
    db.refresh(transaction)
    cache.invalidate_user(current_user.id)
    return transaction


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a transaction and reverse its effect on the asset."""
    transaction = (
        db.query(Transaction)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id,
        )
        .first()
    )

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    asset = db.query(Asset).filter(Asset.id == transaction.asset_id).first()
    if asset:
        update_asset_from_transaction(
            db,
            asset,
            transaction.transaction_type,
            transaction.quantity,
            transaction.price_per_unit,
            is_reversal=True,
        )

    db.delete(transaction)
    if asset:
        db.flush()
        remaining = (
            db.query(Transaction).filter(Transaction.asset_id == asset.id).count()
        )
        if remaining == 0:
            db.delete(asset)

    # Capture fields before the session expunges the deleted object.
    tx_date = transaction.date
    tx_type = transaction.transaction_type
    tx_qty = transaction.quantity
    tx_price = transaction.price_per_unit
    if tx_date.tzinfo is None:
        tx_date = tx_date.replace(tzinfo=timezone.utc)
    else:
        tx_date = tx_date.astimezone(timezone.utc)

    # The delta this transaction added to every snapshot on or after its date.
    # A "buy" of qty@price added qty*price to net worth; reverting removes it.
    # A "sell" subtracted qty*price; reverting adds it back.
    delta = tx_qty * tx_price
    if tx_type == "buy":
        delta = -delta  # remove the asset's contribution

    # Adjust all historical snapshots that were recorded on or after the trade
    # date so the curve shape is preserved with corrected absolute values.
    affected_snaps = (
        db.query(NetWorthSnapshot)
        .filter(
            NetWorthSnapshot.user_id == current_user.id,
            NetWorthSnapshot.date >= tx_date,
        )
        .all()
    )
    for snap in affected_snaps:
        snap.value = max(0.0, snap.value + delta)

    record_networth_snapshot(db, current_user.id)
    db.commit()
    cache.invalidate_user(current_user.id)
