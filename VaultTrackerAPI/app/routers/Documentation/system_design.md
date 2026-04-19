# Routers — System Design

## Router Map

| File              | Prefix          | Notes                                                                   |
| ----------------- | --------------- | ----------------------------------------------------------------------- |
| `accounts.py`     | `/accounts`     | Plain CRUD, no service layer                                            |
| `assets.py`       | `/assets`       | Plain CRUD + optional `?category=` filter                               |
| `transactions.py` | `/transactions` | Smart + legacy create/update/delete                                     |
| `dashboard.py`    | `/dashboard`    | `GET /` per-user aggregate; `GET /household` merged household view (membership required)  |
| `networth.py`     | `/networth`     | `GET /history` per user; `GET /history/household` combined series; cached; `async def` |
| `analytics.py`    | `/analytics`    | Delegates to `AnalyticsService`; cached                                 |
| `prices.py`       | `/prices`       | Delegates to `PriceService`; `async def`                                |
| `users.py`        | `/users`        | Current user profile                                                    |
| `fire.py`         | `/fire`         | FIRE profile + projection                                               |
| `households.py`   | `/households`   | Create household, invite codes, join by code, leave, `GET /me`; max 2 members in v1 |

## Transaction Endpoints (Smart + Legacy)

**Create**

- `POST /transactions` — caller supplies `asset_id` + `account_id` (UUIDs must already exist). Used by the iOS app.
- `POST /transactions/smart` — caller supplies names/symbols; `TransactionService.smart_create` resolves or creates the account + asset server-side.

**Update**

- `PUT /transactions/{id}` — partial update by UUID; reverses then reapplies on the **same** asset row.
- `PUT /transactions/{id}/smart` — full smart body; reverses on the **old** asset, then resolves account + asset from the payload like `smart_create` (`TransactionService.smart_update`).

All write paths call `update_asset_from_transaction` + `record_networth_snapshot` from `app/services/asset_sync.py`.

## Enriched Transaction Response

`GET /transactions` returns `EnrichedTransactionResponse` — each row is joined with a nested `AssetSummary` and `AccountSummary` so clients don't need separate lookups.

## Cache Pattern

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

## sync vs async Handlers

Most routers use `def` (synchronous). `prices.py` and `networth.py` use `async def` because they make async HTTP calls with `httpx`. FastAPI runs sync handlers in a thread pool automatically — mixing is fine.
