"""Parse exchange CSVs into ``RawParsedRow`` (deterministic formats + column map)."""

from __future__ import annotations

import csv
from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Literal

from vaulttracker_scanner.formats import binance as fmt_binance
from vaulttracker_scanner.formats import coinbase as fmt_coinbase
from vaulttracker_scanner.models import RawParsedRow

FormatName = Literal["coinbase", "binance", "generic"]


class CsvParseError(ValueError):
    """Unknown format, missing columns, or unreadable file."""


@dataclass(frozen=True)
class CsvParseResult:
    rows: list[RawParsedRow]
    format_name: FormatName


def normalize_header(label: str) -> str:
    """Lowercase, strip, drop UTF-8 BOM if present on first column."""
    return label.strip().lower().lstrip("\ufeff")


def _read_normalized_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        raise CsvParseError(f"cannot read {path}: {exc}") from exc

    reader = csv.DictReader(text.splitlines())
    fieldnames = reader.fieldnames
    if not fieldnames:
        raise CsvParseError(f"no header row in {path}")

    norm_labels = [normalize_header(f) for f in fieldnames]
    rows: list[dict[str, str]] = []
    for raw in reader:
        row: dict[str, str] = {}
        for orig, nk in zip(fieldnames, norm_labels, strict=True):
            val = raw.get(orig)
            row[nk] = ("" if val is None else str(val)).strip()
        rows.append(row)

    return norm_labels, rows


def _norm_set(norm_labels: list[str]) -> set[str]:
    return {n for n in norm_labels if n}


def detect_format(norm_labels: list[str]) -> FormatName | None:
    norm = _norm_set(norm_labels)
    if fmt_coinbase.normalized_headers_match(norm):
        return "coinbase"
    if fmt_binance.normalized_headers_match(norm):
        return "binance"
    return None


def _parse_generic_row(
    row: Mapping[str, str],
    column_map: Mapping[str, str],
) -> RawParsedRow | None:
    """Map logical fields using CSV header names (matched normalized)."""

    def get_logical(logical: str) -> str:
        header = column_map.get(logical, "")
        if not header:
            return ""
        nk = normalize_header(header)
        return row.get(nk, "").strip()

    tx_raw = get_logical("transaction_type").lower()
    transaction_type: str | None
    if tx_raw in {"buy", "sell"}:
        transaction_type = tx_raw
    elif "sell" in tx_raw:
        transaction_type = "sell"
    elif "buy" in tx_raw:
        transaction_type = "buy"
    else:
        transaction_type = None
    if transaction_type is None:
        return None

    qty_s = get_logical("quantity").replace(",", "")
    price_s = get_logical("price_per_unit").replace(",", "")
    if not qty_s or not price_s:
        return None
    try:
        quantity = abs(float(qty_s))
        price = float(price_s)
    except ValueError:
        return None
    if quantity <= 0 or price <= 0:
        return None

    asset_name = get_logical("asset_name") or None
    symbol = get_logical("symbol") or None
    if not asset_name and symbol:
        asset_name = symbol
    if not asset_name:
        return None

    category = (get_logical("category") or "crypto").lower()
    if category not in {"crypto", "stocks", "cash", "realEstate", "retirement"}:
        category = "crypto"

    account_name = get_logical("account_name") or "Imported"
    at_raw = (get_logical("account_type") or "cryptoExchange").strip()
    if at_raw not in {
        "cryptoExchange",
        "brokerage",
        "bank",
        "retirement",
        "other",
    }:
        account_type = "cryptoExchange"
    else:
        account_type = at_raw

    date: str | datetime | None = get_logical("date") or None
    if date:
        try:
            date = datetime.fromisoformat(date.replace("Z", "+00:00"))
        except ValueError:
            pass

    return RawParsedRow(
        asset_name=asset_name,
        symbol=symbol,
        category=category,
        quantity=quantity,
        price_per_unit=price,
        transaction_type=transaction_type,
        account_name=account_name,
        account_type=account_type,
        date=date,
    )


def parse_csv(
    path: Path | str,
    *,
    format_hint: Literal["coinbase", "binance", "auto"] | None = "auto",
    column_map: dict[str, str] | None = None,
) -> CsvParseResult:
    """Parse a CSV into ``RawParsedRow`` list.

    Args:
        path: CSV file path.
        format_hint: Force Coinbase/Binance or ``\"auto\"`` / ``None`` to detect.
        column_map: For unknown layouts, map logical field names to CSV column
            titles. Logical keys: ``transaction_type``, ``quantity``,
            ``price_per_unit``, ``asset_name``, ``symbol`` (optional if name set),
            ``category``, ``account_name``, ``account_type``, ``date``.
    """
    p = Path(path).expanduser().resolve()
    if not p.is_file():
        raise CsvParseError(f"not a file: {p}")

    _norm_labels, rows = _read_normalized_rows(p)

    fmt: FormatName | None = None
    if format_hint in ("coinbase", "binance"):
        fmt = format_hint
    elif format_hint in (None, "auto"):
        fmt = detect_format(_norm_labels)

    if fmt == "coinbase":
        parsed = fmt_coinbase.rows_from_normalized_rows(rows)
        return CsvParseResult(rows=parsed, format_name="coinbase")

    if fmt == "binance":
        parsed = fmt_binance.rows_from_normalized_rows(rows)
        return CsvParseResult(rows=parsed, format_name="binance")

    if column_map:
        out: list[RawParsedRow] = []
        for row in rows:
            r = _parse_generic_row(row, column_map)
            if r is not None:
                out.append(r)
        return CsvParseResult(rows=out, format_name="generic")

    raise CsvParseError(
        f"unknown CSV layout for {p.name}; "
        f"try format_hint='coinbase'|'binance' or pass column_map={{...}}",
    )


def iter_csv_paths(
    manifest: Mapping[str, list[str]], *, root: Path | str
) -> Iterator[Path]:
    """Yield absolute paths for CSV entries from ``discover_manifest`` output."""
    base = Path(root).expanduser().resolve()
    for rel in manifest.get("csv", []):
        yield (base / rel).resolve()
