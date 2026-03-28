#!/usr/bin/env python3
"""
Seed realistic demo holdings and transaction history for local web/iOS visualization.

Uses TransactionService.smart_create (same path as the API) so assets, snapshots,
and caches stay consistent. Intended for the debug user (firebase_id=debug-user)
or any firebase_id you pass.

Usage (from VaultTrackerAPI/):
  ./venv/bin/python scripts/seed_demo_portfolio.py
  ./venv/bin/python scripts/seed_demo_portfolio.py --clear
  ./venv/bin/python scripts/seed_demo_portfolio.py --firebase-id debug-user --clear

Requires DATABASE_URL in .env (or default SQLite at ./vaulttracker.db).
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Allow `python scripts/seed_demo_portfolio.py` without PYTHONPATH
_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.account import Account
from app.models.asset import Asset
from app.models.networth_snapshot import NetWorthSnapshot
from app.models.transaction import Transaction
from app.models.user import User
from app.schemas.transaction import SmartTransactionCreate
from app.services.cache_service import cache
from app.services.transaction_service import TransactionService


DEFAULT_FIREBASE_ID = "debug-user"


def clear_user_financial_data(db: Session, user_id: str) -> None:
    """Mirror DELETE /api/v1/users/me/data."""
    db.query(Transaction).filter(Transaction.user_id == user_id).delete()
    db.query(NetWorthSnapshot).filter(NetWorthSnapshot.user_id == user_id).delete()
    db.query(Asset).filter(Asset.user_id == user_id).delete()
    db.query(Account).filter(Account.user_id == user_id).delete()
    db.commit()
    cache.invalidate_user(user_id)


def get_or_create_user(db: Session, firebase_id: str) -> User:
    user = db.query(User).filter(User.firebase_id == firebase_id).first()
    if user:
        return user
    user = User(firebase_id=firebase_id)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def build_demo_transactions() -> list[SmartTransactionCreate]:
    """
    Chronological smart transactions: cash, real estate, then ~28 weeks of crypto,
    stocks, and retirement buys with distinct timestamps for net-worth history.
    """
    now = datetime.now(timezone.utc).replace(microsecond=0)
    raw: list[SmartTransactionCreate] = []

    def push(
        *,
        dt: datetime,
        transaction_type: str,
        category: str,
        asset_name: str,
        symbol: str | None,
        quantity: float,
        price_per_unit: float,
        account_name: str,
        account_type: str,
    ) -> None:
        raw.append(
            SmartTransactionCreate(
                transaction_type=transaction_type,
                category=category,
                asset_name=asset_name,
                symbol=symbol,
                quantity=quantity,
                price_per_unit=price_per_unit,
                account_name=account_name,
                account_type=account_type,
                date=dt,
            )
        )

    # Baseline liquidity (oldest first among opening moves)
    push(
        dt=now - timedelta(days=362),
        transaction_type="buy",
        category="cash",
        asset_name="Chase Checking",
        symbol=None,
        quantity=18_000.0,
        price_per_unit=1.0,
        account_name="Chase",
        account_type="bank",
    )
    push(
        dt=now - timedelta(days=360),
        transaction_type="buy",
        category="cash",
        asset_name="High-Yield Savings",
        symbol=None,
        quantity=12_500.0,
        price_per_unit=1.0,
        account_name="Chase",
        account_type="bank",
    )
    push(
        dt=now - timedelta(days=352),
        transaction_type="buy",
        category="realEstate",
        asset_name="Condo — Austin",
        symbol=None,
        quantity=335_000.0,
        price_per_unit=1.0,
        account_name="Wells Fargo",
        account_type="other",
    )

    # ~28 weeks of layered buys (weekly cadence → dense net-worth snapshots)
    start = now - timedelta(days=196)
    for w in range(28):
        week_start = start + timedelta(weeks=w)
        btc_price = 41_800.0 + w * 420.0 + (w % 6) * 95.0
        push(
            dt=week_start,
            transaction_type="buy",
            category="crypto",
            asset_name="Bitcoin",
            symbol="BTC",
            quantity=0.010 + (w % 4) * 0.003,
            price_per_unit=btc_price,
            account_name="Coinbase",
            account_type="cryptoExchange",
        )
        if w % 2 == 0:
            eth_price = 2_180.0 + w * 38.0
            push(
                dt=week_start + timedelta(hours=2),
                transaction_type="buy",
                category="crypto",
                asset_name="Ethereum",
                symbol="ETH",
                quantity=0.22 + (w % 3) * 0.04,
                price_per_unit=eth_price,
                account_name="Coinbase",
                account_type="cryptoExchange",
            )
        if w % 3 == 0:
            sol_price = 98.0 + w * 1.8
            push(
                dt=week_start + timedelta(hours=4),
                transaction_type="buy",
                category="crypto",
                asset_name="Solana",
                symbol="SOL",
                quantity=1.8 + w * 0.12,
                price_per_unit=sol_price,
                account_name="Coinbase",
                account_type="cryptoExchange",
            )
        if w % 2 == 1:
            if w % 4 == 1:
                push(
                    dt=week_start + timedelta(hours=6),
                    transaction_type="buy",
                    category="stocks",
                    asset_name="Apple Inc.",
                    symbol="AAPL",
                    quantity=2.0,
                    price_per_unit=172.0 + w * 0.65,
                    account_name="Fidelity Brokerage",
                    account_type="brokerage",
                )
            else:
                push(
                    dt=week_start + timedelta(hours=6),
                    transaction_type="buy",
                    category="stocks",
                    asset_name="Microsoft Corporation",
                    symbol="MSFT",
                    quantity=1.5,
                    price_per_unit=378.0 + w * 0.55,
                    account_name="Fidelity Brokerage",
                    account_type="brokerage",
                )
        if w % 4 == 0:
            push(
                dt=week_start + timedelta(hours=8),
                transaction_type="buy",
                category="retirement",
                asset_name="Vanguard S&P 500 ETF",
                symbol="VOO",
                quantity=2.5,
                price_per_unit=482.0 + w * 0.25,
                account_name="Fidelity 401(k)",
                account_type="retirement",
            )
        if w % 7 == 0 and w > 0:
            push(
                dt=week_start + timedelta(hours=10),
                transaction_type="buy",
                category="stocks",
                asset_name="NVIDIA Corporation",
                symbol="NVDA",
                quantity=1.0,
                price_per_unit=118.0 + w * 0.4,
                account_name="Fidelity Brokerage",
                account_type="brokerage",
            )

    raw.sort(key=lambda r: r.date or now)
    return raw


def run_seed(firebase_id: str, clear_first: bool) -> None:
    db = SessionLocal()
    try:
        user = get_or_create_user(db, firebase_id)
        if clear_first:
            clear_user_financial_data(db, user.id)
            print(f"Cleared existing data for firebase_id={firebase_id!r} (user id={user.id}).")

        txs = build_demo_transactions()
        svc = TransactionService()
        for i, row in enumerate(txs, start=1):
            svc.smart_create(row, user, db)
            if i % 20 == 0 or i == len(txs):
                print(f"  Applied {i}/{len(txs)} transactions…")

        print(
            f"Done. Seeded {len(txs)} smart transactions for firebase_id={firebase_id!r} "
            f"(user id={user.id}). Open the web app with debug sign-in and refresh the dashboard."
        )
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed demo portfolio data via smart_create.")
    parser.add_argument(
        "--firebase-id",
        default=DEFAULT_FIREBASE_ID,
        help=f"User firebase_id to seed (default: {DEFAULT_FIREBASE_ID!r})",
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Delete existing transactions, snapshots, assets, and accounts for this user first.",
    )
    args = parser.parse_args()
    run_seed(args.firebase_id, args.clear)


if __name__ == "__main__":
    main()
