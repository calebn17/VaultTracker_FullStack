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

## Adding a New Service

1. Create `app/services/my_service.py` with a class.
2. Import and instantiate it inside the router function (or use `Depends` for shared state).
3. If the service writes to the DB, call `cache.invalidate_user(user.id)` after committing.
4. Add a row to the table above.
