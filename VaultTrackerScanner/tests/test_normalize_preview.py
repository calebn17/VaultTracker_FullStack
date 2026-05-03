"""Tests for normalization, validation alignment, and preview text."""

from __future__ import annotations

from datetime import datetime, timezone

import pytest

from vaulttracker_scanner.models import RawParsedRow, SmartTransactionPayload
from vaulttracker_scanner.normalize import (
    NormalizeError,
    normalize_raw_row,
    normalize_raw_rows,
)
from vaulttracker_scanner.preview import format_preview_table
from vaulttracker_scanner.validate import validate_smart_payloads


def test_normalize_category_and_tx_aliases() -> None:
    row = RawParsedRow(
        asset_name="Bitcoin",
        symbol="btc",
        category="Crypto",
        quantity=0.5,
        price_per_unit=50_000.0,
        transaction_type="BUY",
        account_name="Coinbase",
        account_type="crypto exchange",
        date="2024-01-15T10:30:00Z",
    )
    out = normalize_raw_row(row)
    assert out["transaction_type"] == "buy"
    assert out["category"] == "crypto"
    assert out["symbol"] == "BTC"
    assert out["account_type"] == "cryptoExchange"
    assert out["quantity"] == 0.5
    assert out["price_per_unit"] == 50_000.0
    assert out["date"] == datetime(2024, 1, 15, 10, 30, tzinfo=timezone.utc)
    SmartTransactionPayload.model_validate(out)


def test_normalize_stocks_etfs_category() -> None:
    row = RawParsedRow(
        asset_name="Apple Inc",
        symbol="AAPL",
        category="Stocks/ETFs",
        quantity=10,
        price_per_unit=150.0,
        transaction_type="buy",
        account_name="Broker",
        account_type="brokerage",
    )
    out = normalize_raw_row(row)
    assert out["category"] == "stocks"
    SmartTransactionPayload.model_validate(out)


def test_cash_fold_quantity_times_price() -> None:
    row = RawParsedRow(
        asset_name="USD",
        category="cash",
        quantity=100.0,
        price_per_unit=5.0,
        transaction_type="buy",
        account_name="Bank",
        account_type="bank",
        symbol=None,
    )
    out = normalize_raw_row(row)
    assert out["quantity"] == 500.0
    assert out["price_per_unit"] == 1.0
    SmartTransactionPayload.model_validate(out)


def test_cash_dollars_only_price_omitted() -> None:
    row = RawParsedRow(
        asset_name="USD",
        category="cash",
        quantity=2500.0,
        price_per_unit=None,
        transaction_type="buy",
        account_name="Bank",
        account_type="bank",
    )
    out = normalize_raw_row(row)
    assert out["quantity"] == 2500.0
    assert out["price_per_unit"] == 1.0


def test_real_estate_encoding() -> None:
    row = RawParsedRow(
        asset_name="Condo",
        category="real estate",
        quantity=1.0,
        price_per_unit=400_000.0,
        transaction_type="buy",
        account_name="Self",
        account_type="other",
    )
    out = normalize_raw_row(row)
    assert out["category"] == "realEstate"
    assert out["quantity"] == 400_000.0
    assert out["price_per_unit"] == 1.0


def test_unknown_category_raises() -> None:
    row = RawParsedRow(
        asset_name="X",
        category="collectibles",
        quantity=1,
        price_per_unit=1,
        transaction_type="buy",
        account_name="A",
        account_type="other",
    )
    with pytest.raises(NormalizeError, match="unknown category"):
        normalize_raw_row(row)


def test_normalize_then_validate_mixed_preview() -> None:
    good = RawParsedRow(
        asset_name="Bitcoin",
        symbol="BTC",
        category="crypto",
        quantity=0.5,
        price_per_unit=50_000.0,
        transaction_type="buy",
        account_name="Coinbase",
        account_type="cryptoExchange",
        date="2024-01-15T00:00:00Z",
    )
    bad = RawParsedRow(
        asset_name="Apple Inc",
        symbol=None,
        category="stocks",
        quantity=1,
        price_per_unit=100.0,
        transaction_type="buy",
        account_name="IB",
        account_type="brokerage",
        date=None,
    )
    normalized = normalize_raw_rows([good, bad])
    _valid, errors = validate_smart_payloads(normalized)
    preview = format_preview_table(normalized, errors)
    expected = "\n".join(
        [
            "| # | Asset | Symbol | Qty | Price | Account | Type | Date |",
            "|---|-------|--------|-----|-------|---------|------|------|",
            "| 1 | Bitcoin | BTC | 0.5 | 50000 | Coinbase | buy | 2024-01-15 |",
            "| 2 | Apple Inc |  | 1 | 100 | IB | buy |  |",
            "",
            "Validation errors:",
        ],
    )
    assert preview.startswith(expected)
    assert "[1]" in preview
    assert "symbol" in preview
