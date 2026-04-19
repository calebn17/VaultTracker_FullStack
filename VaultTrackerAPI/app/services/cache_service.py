"""
In-memory caches with TTL. Replaceable with Redis later.

- `_data`: dashboard, analytics, net worth history (5-minute TTL).
- Symbol price caches: 15 min crypto, 60 min stocks (per spec rate limits).
"""

from __future__ import annotations

from typing import Any

from cachetools import TTLCache
from sqlalchemy.orm import Session


class CacheService:
    def __init__(self) -> None:
        self._data = TTLCache(maxsize=1000, ttl=300)
        self._crypto_prices = TTLCache(maxsize=500, ttl=900)
        self._stock_prices = TTLCache(maxsize=500, ttl=3600)

    def get(self, key: str) -> Any | None:
        return self._data.get(key)

    def set(self, key: str, value: Any) -> None:
        self._data[key] = value

    def invalidate_user(self, user_id: str) -> None:
        needle = f":{user_id}"
        for k in list(self._data.keys()):
            if needle in str(k):
                del self._data[k]

    def invalidate_household(self, household_id: str) -> None:
        """Clear cached household dashboard, analytics, and net-worth history."""
        self._data.pop(f"dashboard:household:{household_id}", None)
        self._data.pop(f"analytics:household:{household_id}", None)
        prefix = f"networth:history:household:{household_id}:"
        for k in list(self._data.keys()):
            if str(k).startswith(prefix):
                del self._data[k]

    def get_crypto_price(self, symbol: str) -> float | None:
        v = self._crypto_prices.get(symbol.upper())
        return float(v) if v is not None else None

    def set_crypto_price(self, symbol: str, price: float) -> None:
        self._crypto_prices[symbol.upper()] = price

    def get_stock_price(self, symbol: str) -> float | None:
        v = self._stock_prices.get(symbol.upper())
        return float(v) if v is not None else None

    def set_stock_price(self, symbol: str, price: float) -> None:
        self._stock_prices[symbol.upper()] = price


cache = CacheService()


def invalidate_portfolio_caches(db: Session, user_id: str) -> None:
    """
    Invalidate dashboard, analytics, and net-worth caches for this user.

    If the user belongs to a household, also clears the merged household
    dashboard cache so partner-visible totals stay fresh.
    """
    from app.models.household_membership import HouseholdMembership

    cache.invalidate_user(user_id)
    m = (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == user_id)
        .first()
    )
    if m is not None:
        cache.invalidate_household(m.household_id)
