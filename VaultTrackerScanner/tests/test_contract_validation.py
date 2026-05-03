"""Tests for SmartTransactionPayload and batch validate_smart_payloads."""

from __future__ import annotations

from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from vaulttracker_scanner.models import SmartTransactionPayload
from vaulttracker_scanner.validate import (
    validate_smart_payloads,
    validation_result_as_dict,
)


def _minimal_crypto_buy() -> dict:
    return {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 0.5,
        "price_per_unit": 50_000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
        "date": "2024-01-15T10:30:00Z",
    }


def test_smart_payload_valid_crypto() -> None:
    m = SmartTransactionPayload.model_validate(_minimal_crypto_buy())
    dumped = m.model_dump(mode="json")
    assert dumped["transaction_type"] == "buy"
    assert dumped["category"] == "crypto"
    assert dumped["symbol"] == "BTC"
    assert m.date == datetime(2024, 1, 15, 10, 30, tzinfo=timezone.utc)
    assert dumped["date"] is not None


def test_transaction_type_normalized_to_lower_case() -> None:
    raw = _minimal_crypto_buy()
    raw["transaction_type"] = "BUY"
    m = SmartTransactionPayload.model_validate(raw)
    assert m.transaction_type == "buy"


def test_cash_category_allows_missing_symbol() -> None:
    raw = {
        "transaction_type": "buy",
        "category": "cash",
        "asset_name": "USD",
        "quantity": 1000.0,
        "price_per_unit": 1.0,
        "account_name": "Bank",
        "account_type": "bank",
    }
    m = SmartTransactionPayload.model_validate(raw)
    assert m.symbol is None


def test_stocks_requires_non_blank_symbol() -> None:
    raw = {
        "transaction_type": "buy",
        "category": "stocks",
        "asset_name": "Apple Inc",
        "symbol": "   ",
        "quantity": 1.0,
        "price_per_unit": 100.0,
        "account_name": "Broker",
        "account_type": "brokerage",
    }
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_missing_symbol_crypto_fails() -> None:
    raw = _minimal_crypto_buy()
    del raw["symbol"]
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_invalid_transaction_type_rejected() -> None:
    raw = _minimal_crypto_buy()
    raw["transaction_type"] = "swap"
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_invalid_category_rejected() -> None:
    raw = _minimal_crypto_buy()
    raw["category"] = "equities"
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_invalid_account_type_rejected() -> None:
    raw = _minimal_crypto_buy()
    raw["account_type"] = "checking"
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_non_positive_quantity_rejected() -> None:
    raw = _minimal_crypto_buy()
    raw["quantity"] = 0.0
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_non_positive_price_rejected() -> None:
    raw = _minimal_crypto_buy()
    raw["price_per_unit"] = -1.0
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_invalid_date_string_rejected() -> None:
    raw = _minimal_crypto_buy()
    raw["date"] = "not-a-date"
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_asset_name_max_length() -> None:
    raw = _minimal_crypto_buy()
    raw["asset_name"] = "x" * 201
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_retirement_requires_symbol() -> None:
    raw = {
        "transaction_type": "buy",
        "category": "retirement",
        "asset_name": "Vanguard 401k",
        "quantity": 10.0,
        "price_per_unit": 100.0,
        "account_name": "Fidelity",
        "account_type": "retirement",
    }
    with pytest.raises(ValidationError):
        SmartTransactionPayload.model_validate(raw)


def test_real_estate_allows_missing_symbol() -> None:
    raw = {
        "transaction_type": "buy",
        "category": "realEstate",
        "asset_name": "123 Main St",
        "quantity": 1.0,
        "price_per_unit": 500_000.0,
        "account_name": "Property",
        "account_type": "other",
    }
    m = SmartTransactionPayload.model_validate(raw)
    assert m.symbol is None


def test_validate_smart_payloads_mixed_batch() -> None:
    good = _minimal_crypto_buy()
    bad = dict(good)
    bad["symbol"] = None  # invalid for crypto
    missing = {"transaction_type": "buy", "category": "crypto"}

    valid, errors = validate_smart_payloads([good, bad, missing])
    assert len(valid) == 1
    assert any(e.index == 1 for e in errors)
    assert any(e.index == 2 for e in errors)

    blob = validation_result_as_dict(valid, errors)
    assert "valid" in blob and "errors" in blob
    assert len(blob["errors"]) >= 2
