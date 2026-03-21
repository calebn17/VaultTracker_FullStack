"""
Smart transaction creation: resolve account + asset server-side, then post one row.
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


class TransactionService:
    def smart_create(self, data: SmartTransactionCreate, user: User, db: Session) -> Transaction:
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
