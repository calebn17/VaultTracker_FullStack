"""
Live pricing: CoinGecko (crypto) and Alpha Vantage (stocks / retirement tickers).
"""

from __future__ import annotations

from datetime import datetime, timezone

import httpx
from sqlalchemy.orm import Session

from app.config import settings
from app.models.asset import Asset
from app.models.user import User
from app.services.asset_sync import record_networth_snapshot
from app.services.cache_service import cache


class PriceService:
    COINGECKO_BASE = "https://api.coingecko.com/api/v3"
    ALPHA_VANTAGE_BASE = "https://www.alphavantage.co/query"

    CRYPTO_MAP = {
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "SOL": "solana",
        "ADA": "cardano",
        "DOT": "polkadot",
        "DOGE": "dogecoin",
        "XRP": "ripple",
        "AVAX": "avalanche-2",
        "MATIC": "matic-network",
        "LINK": "chainlink",
        "UNI": "uniswap",
        "ATOM": "cosmos",
    }

    async def get_crypto_price(self, symbol: str, *, use_cache: bool = True) -> float | None:
        if use_cache:
            cached = cache.get_crypto_price(symbol)
            if cached is not None:
                return cached
        coin_id = self.CRYPTO_MAP.get(symbol.upper())
        if not coin_id:
            return None
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(
                f"{self.COINGECKO_BASE}/simple/price",
                params={"ids": coin_id, "vs_currencies": "usd"},
            )
            resp.raise_for_status()
            data = resp.json()
        price = data.get(coin_id, {}).get("usd")
        if price is None:
            return None
        p = float(price)
        cache.set_crypto_price(symbol, p)
        return p

    async def get_stock_price(self, symbol: str, *, use_cache: bool = True) -> float | None:
        if use_cache:
            cached = cache.get_stock_price(symbol)
            if cached is not None:
                return cached
        key = (settings.alpha_vantage_api_key or "").strip()
        if not key:
            return None
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(
                self.ALPHA_VANTAGE_BASE,
                params={
                    "function": "GLOBAL_QUOTE",
                    "symbol": symbol,
                    "apikey": key,
                },
            )
            resp.raise_for_status()
            data = resp.json()
        quote = data.get("Global Quote") or {}
        price_str = quote.get("05. price")
        if not price_str:
            return None
        price = float(price_str)
        cache.set_stock_price(symbol, price)
        return price

    async def refresh_user_assets(self, user: User, db: Session) -> dict:
        assets = (
            db.query(Asset)
            .filter(Asset.user_id == user.id, Asset.symbol.isnot(None))
            .all()
        )

        updated: list[dict] = []
        skipped: list[str] = []
        errors: list[dict] = []

        for asset in assets:
            try:
                if asset.category == "crypto":
                    new_price = await self.get_crypto_price(asset.symbol or "", use_cache=False)
                elif asset.category in ("stocks", "retirement"):
                    new_price = await self.get_stock_price(asset.symbol or "", use_cache=False)
                else:
                    skipped.append(asset.name)
                    continue

                if new_price is not None:
                    old_value = asset.current_value or 0.0
                    asset.current_value = (asset.quantity or 0.0) * new_price
                    asset.last_updated = datetime.now(timezone.utc)
                    updated.append(
                        {
                            "asset_id": asset.id,
                            "symbol": asset.symbol,
                            "old_value": old_value,
                            "new_value": asset.current_value,
                            "price": new_price,
                        }
                    )
                else:
                    errors.append(
                        {
                            "symbol": asset.symbol or "",
                            "error": "No price returned (unknown symbol or missing API key)",
                        }
                    )
            except Exception as e:  # noqa: BLE001 — collect per-asset errors for API response
                errors.append({"symbol": asset.symbol, "error": str(e)})

        if updated:
            record_networth_snapshot(db, user.id)
            db.commit()
            cache.invalidate_user(user.id)

        return {"updated": updated, "skipped": skipped, "errors": errors}
