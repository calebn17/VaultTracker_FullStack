# app/routers/CLAUDE.md

Each file maps to one resource and one `/api/v1/<resource>` prefix. Routers only handle HTTP concerns (parse request, auth, call service or query DB directly, return response). Business logic lives in `app/services/`.

**iOS analogy:** Routers are like `URLSession` data task handlers — they receive a request, do minimal work, and return a shaped response. The heavy lifting is in the service layer.

## Router map

| File | Prefix | Notes |
|------|--------|-------|
| `accounts.py` | `/accounts` | Plain CRUD, no service layer needed |
| `assets.py` | `/assets` | Plain CRUD + optional `?category=` filter |
| `transactions.py` | `/transactions` | Smart + legacy create/update — see below |
| `dashboard.py` | `/dashboard` | Aggregation only; no service layer |
| `networth.py` | `/networth` | History with `period=daily|weekly|monthly|all`; responses cached |
| `analytics.py` | `/analytics` | Delegates to `AnalyticsService`; result is cached |
| `prices.py` | `/prices` | Delegates to `PriceService`; `GET /{symbol}` tries crypto first, then stock |
| `users.py` | `/users` | Returns current user profile |

## Transaction endpoints (smart + legacy)

**Create**

- `POST /transactions` — caller supplies `asset_id` + `account_id` (UUIDs must already exist). Used by the current iOS app.
- `POST /transactions/smart` — caller supplies names/symbols; `TransactionService.smart_create` resolves or creates the account + asset server-side (web / import flows).

**Update**

- `PUT /transactions/{id}` — partial update by UUID; reverses then reapplies on the **same** asset row.
- `PUT /transactions/{id}/smart` — full smart body; reverses on the **old** asset, then resolves account + asset from the payload like `smart_create` (`TransactionService.smart_update`).

All write paths call `update_asset_from_transaction` + `record_networth_snapshot` from `app/services/asset_sync.py`.

## Enriched transaction response

`GET /transactions` returns `EnrichedTransactionResponse` — each transaction row is joined with a nested `AssetSummary` and `AccountSummary` so the iOS client doesn't need separate lookups.

## Cache pattern in routers

Cached endpoints follow this pattern (see `analytics.py` as the canonical example):

```python
cache_key = f"<resource>:{user.id}"
cached = cache.get(cache_key)
if cached is not None:
    return ResponseSchema.model_validate(cached)
# ... compute result ...
cache.set(cache_key, result.model_dump(mode="python"))
return result
```

`mode="python"` on `model_dump` preserves Python types (e.g. `datetime`) rather than converting to JSON strings — required so `model_validate` round-trips correctly.

## sync vs async handlers

Most routers use `def` (synchronous). `prices.py` uses `async def` because `PriceService` makes async HTTP calls with `httpx`. `networth.py` also uses `async def`. Mixing sync/async in FastAPI is fine — FastAPI runs sync handlers in a thread pool automatically.
