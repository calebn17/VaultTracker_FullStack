"""Tests for processed/ archive layout and recovery loaders."""

from __future__ import annotations

import json
from datetime import datetime, timezone

import pytest

from vaulttracker_scanner.archive import (
    ArchiveError,
    SourceArchiveEntry,
    load_flat_payloads_for_reimport,
    load_payload_lists_from_manifest,
    read_manifest,
    write_archive,
)


def test_write_archive_copies_sources_and_payloads(tmp_path) -> None:
    processed = tmp_path / "processed"
    src = tmp_path / "coinbase_export.csv"
    content = "Timestamp,Type\n2024-01-01,BUY\n"
    src.write_text(content, encoding="utf-8")

    payloads = [
        {
            "transaction_type": "buy",
            "category": "crypto",
            "asset_name": "BTC",
            "symbol": "BTC",
            "quantity": 0.1,
            "price_per_unit": 40_000.0,
            "account_name": "CB",
            "account_type": "cryptoExchange",
            "date": "2024-01-01T00:00:00Z",
        },
    ]
    record_ids = ["abc-123"]

    fixed = datetime(2026, 5, 2, 14, 30, 5, tzinfo=timezone.utc)
    archive_path = write_archive(
        processed,
        [
            SourceArchiveEntry(
                source_path=src,
                format_name="coinbase_csv",
                payloads=payloads,
                record_ids=record_ids,
            ),
        ],
        timestamp=fixed,
    )

    assert archive_path.name == "2026-05-02T14-30-05"
    assert (archive_path / "sources" / "coinbase_export.csv").read_text(
        encoding="utf-8"
    ) == content
    payload_file = archive_path / "payloads" / "coinbase_export.json"
    loaded = json.loads(payload_file.read_text(encoding="utf-8"))
    assert loaded == payloads

    manifest = read_manifest(archive_path)
    assert manifest.timestamp.isoformat() == fixed.isoformat()
    assert len(manifest.files) == 1
    fe = manifest.files[0]
    assert fe.source == "sources/coinbase_export.csv"
    assert fe.payload == "payloads/coinbase_export.json"
    assert fe.format == "coinbase_csv"
    assert fe.transactions_inserted == 1
    assert fe.record_ids == record_ids


def test_duplicate_basenames_get_unique_destinations(tmp_path) -> None:
    processed = tmp_path / "processed"
    dir_a = tmp_path / "a"
    dir_b = tmp_path / "b"
    dir_a.mkdir()
    dir_b.mkdir()
    f1 = dir_a / "export.csv"
    f2 = dir_b / "export.csv"
    f1.write_text("a", encoding="utf-8")
    f2.write_text("b", encoding="utf-8")

    common_payload = [
        {
            "transaction_type": "buy",
            "category": "crypto",
            "asset_name": "BTC",
            "symbol": "BTC",
            "quantity": 1,
            "price_per_unit": 1,
            "account_name": "X",
            "account_type": "cryptoExchange",
        },
    ]

    when = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    archive_path = write_archive(
        processed,
        [
            SourceArchiveEntry(f1, "fmt", common_payload, ["id1"]),
            SourceArchiveEntry(f2, "fmt", common_payload, ["id2"]),
        ],
        timestamp=when,
    )

    assert (archive_path / "sources" / "export.csv").read_text() == "a"
    assert (archive_path / "sources" / "export_1.csv").read_text() == "b"
    names = {f.source for f in read_manifest(archive_path).files}
    assert names == {"sources/export.csv", "sources/export_1.csv"}
    assert {f.payload for f in read_manifest(archive_path).files} == {
        "payloads/export.json",
        "payloads/export_1.json",
    }


def test_load_flat_payloads_matches_written(tmp_path) -> None:
    processed = tmp_path / "processed"
    s1 = tmp_path / "one.csv"
    s1.write_text("1")
    p1 = [
        {
            "transaction_type": "buy",
            "category": "cash",
            "asset_name": "USD",
            "quantity": 100,
            "price_per_unit": 1,
            "account_name": "B",
            "account_type": "bank",
        }
    ]
    p2 = [
        {
            "transaction_type": "sell",
            "category": "crypto",
            "asset_name": "ETH",
            "symbol": "ETH",
            "quantity": 2,
            "price_per_unit": 2000,
            "account_name": "C",
            "account_type": "cryptoExchange",
        }
    ]
    archive_path = write_archive(
        processed,
        [
            SourceArchiveEntry(s1, "a", p1, ["r1"]),
            SourceArchiveEntry(s1, "b", p2, ["r2"]),
        ],
        timestamp=datetime(2025, 6, 1, 0, 0, 0, tzinfo=timezone.utc),
    )

    flat = load_flat_payloads_for_reimport(archive_path)
    assert flat == p1 + p2

    pairs = load_payload_lists_from_manifest(archive_path)
    assert len(pairs) == 2
    assert pairs[0][1] == p1
    assert pairs[1][1] == p2


def test_read_manifest_missing_raises(tmp_path) -> None:
    with pytest.raises(ArchiveError, match="missing manifest"):
        read_manifest(tmp_path)


def test_write_archive_rejects_empty_entries(tmp_path) -> None:
    with pytest.raises(ArchiveError, match="at least one"):
        write_archive(tmp_path / "processed", [])
