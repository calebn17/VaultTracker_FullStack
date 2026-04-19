# Services — System Design

## `asset_sync.py` — Central Invariant

`update_asset_from_transaction` and `record_networth_snapshot` are called together after every transaction write. **Both must always be called — never one without the other.**

- `update_asset_from_transaction`: adjusts `asset.quantity`, then sets `asset.current_value = quantity × price_per_unit` (mark-to-market — the latest price revalues the whole position).
- Pass `is_reversal=True` to undo an existing transaction (used by PUT and DELETE).
- `record_networth_snapshot`: sums `current_value` across all user assets and writes a new row — drives the net-worth chart.

## Cache Rules

The singleton `cache` object (from `cache_service.py`) has three TTL buckets:

| Cache | TTL | Used for |
|-------|-----|---------|
| `_data` | 5 min | dashboard, analytics, networth — keys always contain `":<user_id>"` |
| `_crypto_prices` | 15 min | CoinGecko prices keyed by uppercase symbol |
| `_stock_prices` | 60 min | Alpha Vantage prices keyed by uppercase symbol |

**Invalidation:** `cache.invalidate_user(user_id)` deletes all `_data` entries containing `":<user_id>"`. Call after any write that changes asset values. Does **not** clear price caches.

## Price Service Routing

`PriceService` dispatches based on `asset.category`:

- `"crypto"` → CoinGecko (no API key; symbol must be in `CRYPTO_MAP`)
- `"stocks"` / `"retirement"` → Alpha Vantage (requires `ALPHA_VANTAGE_API_KEY`; returns `None` silently if absent)
- `"cash"` / `"realEstate"` → skipped (no symbol)

Adding a new crypto: add an entry to `CRYPTO_MAP` in `price_service.py` (uppercase ticker → CoinGecko coin ID).

## Smart Transaction Flow (`transaction_service.py`)

`TransactionService.smart_create` accepts names instead of UUIDs:
1. Find account by `(user_id, account_name)` → create if missing
2. Find asset by `(user_id, symbol)` for tickered categories, or `(user_id, name, category)` for cash/real-estate → create if missing
3. Write transaction, call `update_asset_from_transaction` + `record_networth_snapshot`, commit, then `cache.invalidate_user`

`db.flush()` (not `db.commit()`) after creating account/asset so IDs are available before the transaction row is inserted — everything commits atomically at the end.
