# app/services/CLAUDE.md

Business logic layer. Routers handle HTTP; services handle everything else.

> **asset_sync invariant, cache rules, price routing, smart transaction flow:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Files and Responsibilities

| File                     | What it does                                                                      |
| ------------------------ | --------------------------------------------------------------------------------- |
| `asset_sync.py`          | Shared helpers — mark-to-market valuation and snapshot recording                  |
| `transaction_service.py` | Smart transaction creation: resolves account + asset by name                      |
| `price_service.py`       | Fetches live prices from CoinGecko (crypto) and Alpha Vantage (stocks/retirement) |
| `cache_service.py`       | In-memory TTL cache; replaceable with Redis without changing callers              |
| `analytics_service.py`   | Portfolio allocation percentages and gain/loss performance                        |
| `dashboard_aggregate.py` | Shared dashboard totals (used by dashboard router + FIRE projection)              |
| `fire_service.py`        | FIRE constants + pure math                                                        |
| `fire_projection.py`     | FIRE response assembly                                                            |

## `asset_sync.py` — the central invariant

`update_asset_from_transaction` and `record_networth_snapshot` are called together after every transaction write (create, update, delete). **Both must always be called — never one without the other.**

- `update_asset_from_transaction`: adjusts `asset.quantity`, then sets `asset.current_value = quantity × price_per_unit` (mark-to-market — the latest price revalues the whole position, not just the new units).
- Pass `is_reversal=True` to undo an existing transaction (used by PUT and DELETE).
- `record_networth_snapshot`: sums `current_value` across all user assets and writes a new row (per-user chart). If the user is in a household, also upserts `HouseholdNetWorthSnapshot` at the same timestamp for the combined household chart.

## Cache rules

The singleton `cache` object (imported from `cache_service.py`) has three separate TTL buckets:

| Cache            | TTL    | Used for                                                                                                      |
| ---------------- | ------ | ------------------------------------------------------------------------------------------------------------- |
| `_data`          | 5 min  | dashboard, analytics, networth — keys contain `":<user_id>"` (e.g. `"analytics:<user_id>"`, `"dashboard:household:{id}"`) |
| `_crypto_prices` | 15 min | CoinGecko prices keyed by uppercase symbol                                                                    |
| `_stock_prices`  | 60 min | Alpha Vantage prices keyed by uppercase symbol                                                                |

**Invalidation:** Use `invalidate_portfolio_caches(db, user_id)` from `cache_service.py` after any write that changes asset values (transactions, price refresh, `DELETE /users/me/data`). It deletes all `_data` keys containing `":<user_id>"` **and** clears `dashboard:household:{id}` if that user is in a household. For join/leave household routes, also call `cache.invalidate_household`. Price symbol caches expire by TTL only — they are never cleared by write paths.

## Price service routing

`PriceService` dispatches to CoinGecko vs Alpha Vantage based on `asset.category`:

- `"crypto"` → CoinGecko (no API key required; symbol must be in `CRYPTO_MAP`)
- `"stocks"` or `"retirement"` → Alpha Vantage (requires `ALPHA_VANTAGE_API_KEY` in `.env`; returns `None` silently if key is absent)
- `"cash"` / `"realEstate"` → skipped (no symbol)

The `CRYPTO_MAP` dict maps uppercase ticker → CoinGecko coin ID. Adding a new crypto requires adding an entry there.

## Smart transaction (`transaction_service.py`)

`TransactionService.smart_create` accepts names instead of UUIDs and resolves them server-side:

1. Find account by `(user_id, account_name)` → create if missing
2. Find asset by `(user_id, symbol)` for tickered categories, or by `(user_id, name, category)` for cash/real-estate → create if missing
3. Write the transaction, call `update_asset_from_transaction` + `record_networth_snapshot`, commit, then `invalidate_portfolio_caches`

`db.flush()` is used (not `db.commit()`) after creating account/asset so their IDs are available before the transaction row is inserted, but everything commits atomically at the end.

## Adding a New Service

1. Create `app/services/my_service.py` with a class.
2. Import and instantiate it inside the router function (or use `Depends` for shared state).
3. If the service writes to the DB, call `invalidate_portfolio_caches(db, user.id)` after committing.
4. Add a row to the table above.
