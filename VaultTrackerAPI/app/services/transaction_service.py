"""
Smart transaction creation and update: resolve account + asset server-side, then write rows.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.asset import Asset
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.transaction import SmartTransactionCreate
from app.services.asset_sync import record_networth_snapshot, update_asset_from_transaction
from app.services.cache_service import cache


class SmartUpdateMissingLinkedAssetError(Exception):
    """Transaction row exists but its asset_id does not resolve — cannot reverse prior effect."""


def _resolve_account_and_asset(
    db: Session,
    user: User,
    data: SmartTransactionCreate,
) -> tuple[Account, Asset]:
    """Find or create account + asset for a smart payload (shared by smart_create / smart_update)."""
    account = (
        db.query(Account)
        .filter(Account.user_id == user.id, Account.name == data.account_name)
        .first()
    )
    if not account:
        account = Account(
            id=str(uuid.uuid4()),
            user_id=user.id,
            name=data.account_name,
            account_type=data.account_type,
        )
        db.add(account)
        db.flush()

    if data.category in ("crypto", "stocks", "retirement") and data.symbol:
        asset = (
            db.query(Asset)
            .filter(Asset.user_id == user.id, Asset.symbol == data.symbol)
            .first()
        )
    else:
        asset = (
            db.query(Asset)
            .filter(
                Asset.user_id == user.id,
                Asset.name == data.asset_name,
                Asset.category == data.category,
            )
            .first()
        )

    if not asset:
        asset = Asset(
            id=str(uuid.uuid4()),
            user_id=user.id,
            name=data.asset_name,
            symbol=data.symbol,
            category=data.category,
            quantity=0.0,
            current_value=0.0,
        )
        db.add(asset)
        db.flush()

    return account, asset


class TransactionService:
    def smart_create(self, data: SmartTransactionCreate, user: User, db: Session) -> Transaction:
        account, asset = _resolve_account_and_asset(db, user, data)

        when = data.date if data.date is not None else datetime.now(timezone.utc)
        transaction = Transaction(
            id=str(uuid.uuid4()),
            user_id=user.id,
            asset_id=asset.id,
            account_id=account.id,
            transaction_type=data.transaction_type,
            quantity=data.quantity,
            price_per_unit=data.price_per_unit,
            date=when,
        )
        db.add(transaction)

        update_asset_from_transaction(
            db,
            asset,
            data.transaction_type,
            data.quantity,
            data.price_per_unit,
        )
        record_networth_snapshot(db, user.id)
        db.commit()
        db.refresh(transaction)
        cache.invalidate_user(user.id)
        return transaction

    def smart_update(
        self,
        transaction_id: str,
        data: SmartTransactionCreate,
        user: User,
        db: Session,
    ) -> Transaction | None:
        """
        Reverse the existing transaction on its current asset, re-resolve account + asset
        from the smart payload (same rules as smart_create), then apply the new row fields.
        """
        tx = (
            db.query(Transaction)
            .filter(Transaction.id == transaction_id, Transaction.user_id == user.id)
            .first()
        )
        if not tx:
            return None

        old_asset = db.query(Asset).filter(Asset.id == tx.asset_id).first()
        if not old_asset:
            raise SmartUpdateMissingLinkedAssetError()

        update_asset_from_transaction(
            db,
            old_asset,
            tx.transaction_type,
            tx.quantity,
            tx.price_per_unit,
            is_reversal=True,
        )

        account, asset = _resolve_account_and_asset(db, user, data)

        when = data.date if data.date is not None else tx.date
        tx.account_id = account.id
        tx.asset_id = asset.id
        tx.transaction_type = data.transaction_type
        tx.quantity = data.quantity
        tx.price_per_unit = data.price_per_unit
        tx.date = when

        update_asset_from_transaction(
            db,
            asset,
            data.transaction_type,
            data.quantity,
            data.price_per_unit,
        )
        record_networth_snapshot(db, user.id)
        db.commit()
        db.refresh(tx)
        cache.invalidate_user(user.id)
        return tx
