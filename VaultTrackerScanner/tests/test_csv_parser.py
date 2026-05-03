"""Tests for CSV parsing (Coinbase, Binance, generic column_map)."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import pytest

from vaulttracker_scanner.csv_parser import (
    CsvParseError,
    detect_format,
    iter_csv_paths,
    parse_csv,
)
from vaulttracker_scanner.discover import discover_manifest

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def test_detect_coinbase_headers() -> None:
    labels = [
        "timestamp",
        "transaction type",
        "asset",
        "quantity transacted",
        "usd spot price at transaction",
    ]
    assert detect_format(labels) == "coinbase"


def test_detect_binance_headers() -> None:
    labels = ["date(utc)", "market", "side", "price", "amount", "total"]
    assert detect_format(labels) == "binance"


def test_parse_coinbase_sample() -> None:
    path = FIXTURES / "coinbase_sample.csv"
    result = parse_csv(path)
    assert result.format_name == "coinbase"
    assert len(result.rows) == 2  # Receive skipped

    buy = result.rows[0]
    assert buy.transaction_type == "buy"
    assert buy.symbol == "BTC"
    assert buy.quantity == 0.5
    assert buy.price_per_unit == 50_000.0
    assert buy.account_name == "Coinbase"
    assert buy.date == datetime(2024, 1, 15, 10, 30, tzinfo=timezone.utc)

    sell = result.rows[1]
    assert sell.transaction_type == "sell"
    assert sell.quantity == 0.1
    assert sell.price_per_unit == 48_000.0


def test_parse_binance_sample() -> None:
    path = FIXTURES / "binance_sample.csv"
    result = parse_csv(path)
    assert result.format_name == "binance"
    assert len(result.rows) == 2
    assert result.rows[0].transaction_type == "buy"
    assert result.rows[0].symbol == "BTC"
    assert result.rows[0].quantity == 0.5
    assert result.rows[0].price_per_unit == 50_000.0
    assert result.rows[1].transaction_type == "sell"
    assert result.rows[1].symbol == "ETH"


def test_parse_unknown_without_map_raises() -> None:
    path = FIXTURES / "unknown_sample.csv"
    with pytest.raises(CsvParseError, match="unknown CSV layout"):
        parse_csv(path)


def test_parse_unknown_with_column_map() -> None:
    path = FIXTURES / "unknown_sample.csv"
    result = parse_csv(
        path,
        column_map={
            "transaction_type": "Action",
            "quantity": "Units",
            "price_per_unit": "Rate",
            "asset_name": "Coin",
            "date": "When",
        },
    )
    assert result.format_name == "generic"
    assert len(result.rows) == 1
    r = result.rows[0]
    assert r.transaction_type == "buy"
    assert r.asset_name == "BTC"
    assert r.quantity == 0.25
    assert r.price_per_unit == 51_000.0
    assert r.account_name == "Imported"


def test_parse_utf8_bom_coinbase(tmp_path) -> None:
    path = tmp_path / "bom.csv"
    inner = (
        "Timestamp,Transaction Type,Asset,Quantity Transacted,"
        "USD Spot Price at Transaction\n"
        "2024-01-15T10:30:00Z,Buy,BTC,1,10000\n"
    )
    path.write_bytes("\ufeff".encode("utf-8") + inner.encode("utf-8"))
    result = parse_csv(path)
    assert result.format_name == "coinbase"
    assert len(result.rows) == 1


def test_iter_csv_paths_from_manifest(tmp_path) -> None:
    (tmp_path / "x.csv").write_text("a")
    m = discover_manifest(tmp_path)
    paths = list(iter_csv_paths(m, root=tmp_path))
    assert len(paths) == 1
    assert paths[0].name == "x.csv"
