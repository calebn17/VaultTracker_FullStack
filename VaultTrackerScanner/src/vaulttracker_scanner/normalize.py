"""Map ``RawParsedRow`` / loose dicts to smart-transaction-shaped dicts."""

from __future__ import annotations

import re
from collections.abc import Mapping
from datetime import datetime, timezone
from typing import Any

from vaulttracker_scanner.models import AssetCategory, RawParsedRow

_ACCOUNT_TYPE_ALIASES: dict[str, str] = {
    "cryptoexchange": "cryptoExchange",
    "crypto exchange": "cryptoExchange",
    "exchange": "cryptoExchange",
    "brokerage": "brokerage",
    "broker": "brokerage",
    "stock": "brokerage",
    "stocks": "brokerage",
    "bank": "bank",
    "checking": "bank",
    "savings": "bank",
    "retirement": "retirement",
    "401k": "retirement",
    "ira": "retirement",
    "other": "other",
}

# Key: normalized lookup token -> API category literal
_CATEGORY_ALIASES: dict[str, AssetCategory] = {
    "crypto": "crypto",
    "cryptocurrency": "crypto",
    "stocks": "stocks",
    "stock": "stocks",
    "equities": "stocks",
    "stocks etfs": "stocks",
    "etf": "stocks",
    "etfs": "stocks",
    "cash": "cash",
    "fiat": "cash",
    "usd": "cash",
    "money market": "cash",
    "realestate": "realEstate",
    "real estate": "realEstate",
    "real_estate": "realEstate",
    "property": "realEstate",
    "home": "realEstate",
    "retirement": "retirement",
    "401k": "retirement",
    "ira": "retirement",
    "roth": "retirement",
}


class NormalizeError(ValueError):
    """Inputs cannot be coerced into a smart payload shape."""


def _slug_key(s: str) -> str:
    t = s.strip().lower()
    t = re.sub(r"[\s_/]+", " ", t)
    return t.strip()


def _normalize_category(raw: str | None) -> AssetCategory:
    if raw is None or not str(raw).strip():
        return "crypto"
    key = _slug_key(str(raw))
    if key in _CATEGORY_ALIASES:
        return _CATEGORY_ALIASES[key]
    raise NormalizeError(f"unknown category: {raw!r}")


def _normalize_account_type(raw: str | None) -> str:
    if raw is None or not str(raw).strip():
        return "other"
    key = _slug_key(str(raw))
    if key in _ACCOUNT_TYPE_ALIASES:
        return _ACCOUNT_TYPE_ALIASES[key]
    if raw in (
        "cryptoExchange",
        "brokerage",
        "bank",
        "retirement",
        "other",
    ):
        return raw
    raise NormalizeError(f"unknown account_type: {raw!r}")


def _normalize_transaction_type(raw: str | None) -> str:
    if raw is None or not str(raw).strip():
        raise NormalizeError("transaction_type is required")
    t = str(raw).strip().lower()
    if t in ("buy", "sell"):
        return t
    if "sell" in t:
        return "sell"
    if "buy" in t:
        return "buy"
    raise NormalizeError(f"transaction_type must be buy/sell, got {raw!r}")


def _normalize_date(value: str | datetime | None) -> datetime | None:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        dt = value
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt
    s = str(value).strip()
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        pass
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d"):
        try:
            parsed = datetime.strptime(s, fmt)
            return parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    raise NormalizeError(f"cannot parse date: {value!r}")


def _apply_cash_real_estate_encoding(
    category: AssetCategory,
    quantity: float | None,
    price_per_unit: float | None,
) -> tuple[float, float]:
    """Set ``quantity`` to total dollars, ``price_per_unit`` to ``1.0``."""
    if category not in ("cash", "realEstate"):
        if quantity is None or price_per_unit is None:
            raise NormalizeError("quantity and price_per_unit are required")
        q = float(quantity)
        p = float(price_per_unit)
        if q <= 0 or p <= 0:
            raise NormalizeError("quantity and price_per_unit must be positive")
        return q, p

    if quantity is None:
        raise NormalizeError("quantity is required for cash/realEstate")
    q = float(quantity)
    if q <= 0:
        raise NormalizeError("quantity must be positive")
    if price_per_unit is None:
        return q, 1.0
    p = float(price_per_unit)
    if p <= 0:
        raise NormalizeError("price_per_unit must be positive when set")
    if p == 1.0:
        return q, 1.0
    total = q * p
    return total, 1.0


def normalize_raw_row(row: RawParsedRow | Mapping[str, Any]) -> dict[str, Any]:
    """Return a dict suitable for ``SmartTransactionPayload.model_validate``."""
    if isinstance(row, Mapping):
        data = {k: row.get(k) for k in RawParsedRow.model_fields}
        parsed = RawParsedRow.model_validate(data)
    else:
        parsed = row

    category = _normalize_category(parsed.category)
    tx = _normalize_transaction_type(parsed.transaction_type)
    acct_type = _normalize_account_type(parsed.account_type)

    name = (parsed.asset_name or "").strip()
    sym_in = (parsed.symbol or "").strip()
    if not name and sym_in:
        name = sym_in
    if not name:
        raise NormalizeError("asset_name (or symbol) is required")

    quantity, price = _apply_cash_real_estate_encoding(
        category,
        parsed.quantity,
        parsed.price_per_unit,
    )

    symbol: str | None
    if sym_in:
        symbol = sym_in.upper()[:20]
    else:
        symbol = None

    acct_name = (parsed.account_name or "").strip()
    if not acct_name:
        raise NormalizeError("account_name is required")

    when = _normalize_date(parsed.date)

    return {
        "transaction_type": tx,
        "category": category,
        "asset_name": name[:200],
        "symbol": symbol,
        "quantity": quantity,
        "price_per_unit": price,
        "account_name": acct_name[:200],
        "account_type": acct_type,
        "date": when,
    }


def normalize_raw_rows(
    rows: list[RawParsedRow | Mapping[str, Any]],
) -> list[dict[str, Any]]:
    return [normalize_raw_row(r) for r in rows]
