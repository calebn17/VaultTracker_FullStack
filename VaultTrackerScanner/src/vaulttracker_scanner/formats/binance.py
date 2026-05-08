"""Binance spot trade history CSV (common export shape)."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime, timezone

from vaulttracker_scanner.models import RawParsedRow

_QUOTES_ORDERED = (
    "USDT",
    "USDC",
    "BUSD",
    "TUSD",
    "FDUSD",
    "BTC",
    "ETH",
    "BNB",
    "EUR",
    "TRY",
)


def base_asset_from_market(market: str) -> str:
    """Strip known quote assets from *Market* / pair (e.g. ``BTCUSDT`` -> ``BTC``)."""
    p = market.replace("/", "").upper().strip()
    for q in sorted(_QUOTES_ORDERED, key=len, reverse=True):
        if p.endswith(q) and len(p) > len(q):
            return p[: -len(q)]
    return p


def normalized_headers_match(norm_set: set[str]) -> bool:
    """Match typical Binance spot export with Date(UTC), Market, Side, Price, Amount."""
    if "price" not in norm_set:
        return False
    if "amount" not in norm_set and "executed" not in norm_set:
        return False
    if "market" not in norm_set and "pair" not in norm_set:
        return False
    if "side" not in norm_set and "type" not in norm_set:
        return False
    return "date(utc)" in norm_set


def _parse_side(raw: str) -> str | None:
    u = raw.strip().upper()
    if u == "SELL":
        return "sell"
    if u == "BUY":
        return "buy"
    return None


def _parse_when(raw: str) -> str | datetime:
    s = raw.strip()
    if not s:
        return s
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S.%f"):
        try:
            return datetime.strptime(s, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return s


def rows_from_normalized_rows(rows: list[Mapping[str, str]]) -> list[RawParsedRow]:
    """*rows* use normalized header keys."""
    out: list[RawParsedRow] = []

    for raw_row in rows:
        row = {k: ("" if v is None else str(v)).strip() for k, v in raw_row.items()}
        if not row:
            continue

        side_raw = row.get("side", "") or row.get("type", "")
        tx = _parse_side(side_raw) if side_raw else None
        if tx is None:
            continue

        market = (row.get("market", "") or row.get("pair", "")).strip()
        if not market:
            continue
        base = base_asset_from_market(market)

        amt_s = (
            row.get("amount", "") or row.get("executed", "") or row.get("quantity", "")
        ).replace(",", "")
        if not amt_s:
            continue
        try:
            quantity = abs(float(amt_s))
        except ValueError:
            continue
        if quantity <= 0:
            continue

        price_s = row.get("price", "").replace(",", "")
        if not price_s:
            continue
        try:
            price = float(price_s)
        except ValueError:
            continue
        if price <= 0:
            continue

        when_raw = row.get("date(utc)", "").strip()
        if not when_raw:
            continue
        date = _parse_when(when_raw)

        out.append(
            RawParsedRow(
                asset_name=base,
                symbol=base,
                category="crypto",
                quantity=quantity,
                price_per_unit=price,
                transaction_type=tx,
                account_name="Binance",
                account_type="cryptoExchange",
                date=date,
            ),
        )

    return out
