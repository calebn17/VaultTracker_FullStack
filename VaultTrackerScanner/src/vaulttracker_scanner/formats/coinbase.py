"""Coinbase retail transaction history CSV (header auto-detect)."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime

from vaulttracker_scanner.models import RawParsedRow


def normalized_headers_match(norm_set: set[str]) -> bool:
    """Heuristic match for Coinbase retail ``transaction history`` CSV."""
    if "transaction type" not in norm_set:
        return False
    if "asset" not in norm_set:
        return False
    if "quantity transacted" not in norm_set:
        return False
    price_keys = (
        "usd spot price at transaction",
        "usd spot price",
        "price at time of transaction (usd)",
        "price at transaction (usd)",
    )
    return any(pk in norm_set for pk in price_keys)


def _parse_tx_type(raw: str) -> str | None:
    lowered = raw.strip().lower()
    if "sell" in lowered:
        return "sell"
    if "buy" in lowered:
        return "buy"
    return None


def rows_from_normalized_rows(rows: list[Mapping[str, str]]) -> list[RawParsedRow]:
    """*rows* use normalized header keys (see ``csv_parser``)."""
    out: list[RawParsedRow] = []

    for raw_row in rows:
        row = {k: ("" if v is None else str(v)).strip() for k, v in raw_row.items()}
        if not row:
            continue

        tx_raw = row.get("transaction type", "")
        tx = _parse_tx_type(tx_raw) if tx_raw else None
        if tx is None:
            continue

        asset = row.get("asset", "").strip()
        if not asset:
            continue

        qty_s = row.get("quantity transacted", "").replace(",", "")
        if not qty_s:
            continue
        try:
            quantity = abs(float(qty_s))
        except ValueError:
            continue
        if quantity <= 0:
            continue

        price_s: str | None = None
        for pk in (
            "usd spot price at transaction",
            "usd spot price",
            "price at time of transaction (usd)",
            "price at transaction (usd)",
        ):
            v = row.get(pk, "").replace(",", "")
            if v:
                price_s = v
                break
        if not price_s:
            continue
        try:
            price = float(price_s)
        except ValueError:
            continue
        if price <= 0:
            continue

        ts_raw = row.get("timestamp", "").strip()
        date: str | datetime | None = ts_raw or None
        if ts_raw:
            try:
                date = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
            except ValueError:
                date = ts_raw

        out.append(
            RawParsedRow(
                asset_name=asset,
                symbol=asset.upper(),
                category="crypto",
                quantity=quantity,
                price_per_unit=price,
                transaction_type=tx,
                account_name="Coinbase",
                account_type="cryptoExchange",
                date=date,
            ),
        )

    return out
