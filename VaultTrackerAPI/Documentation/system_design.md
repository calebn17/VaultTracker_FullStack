# VaultTrackerAPI System Design

## Project Layout

```
app/
  main.py          # App factory, router mounts, lifespan (create_all), SlowAPI + CORS order
  rate_limit.py    # SlowAPI limiter, key func (JWT sub / IP), 429 handler, coerce_json_response
  config.py        # Pydantic Settings, reads .env
  database.py      # SQLAlchemy engine + SessionLocal + Base
  dependencies.py  # get_current_user — the auth dependency
  models/          # SQLAlchemy ORM models
  schemas/         # Pydantic request/response models
  routers/         # accounts, assets, transactions, networth, dashboard, fire, users, analytics, prices
  services/        # asset_sync, transaction_service, analytics_service, price_service, cache_service,
                   # dashboard_aggregate, fire_service, fire_projection
```

Tables are created automatically via `Base.metadata.create_all` in the lifespan handler — no migration scripts.

## Authentication

Every protected route injects `Depends(get_current_user)` ([app/dependencies.py](../app/dependencies.py)). When `FIREBASE_CREDENTIALS_PATH` points to a service account JSON, Bearer tokens are verified with **Firebase Admin** and `uid` becomes `firebase_id`. Users are auto-created on first request.

**Debug bypass:** `DEBUG_AUTH_ENABLED=true` in `.env` + Bearer `vaulttracker-debug-user` maps to `firebase_id: "debug-user"`. Must stay disabled outside local dev. Must match `AuthTokenProvider.debugToken` in iOS and `DEBUG_AUTH_TOKEN` in web.

## Rate Limiting

[app/rate_limit.py](../app/rate_limit.py) registers a SlowAPI `Limiter` with callable tier strings from settings so tests can monkeypatch limits. Routers use `@limiter.limit(...)` with `Request` on each handler and `@coerce_json_response`. `GET /` and `GET /health` are exempt. Storage is cleared in `tests/conftest.py` via `reset_rate_limit_storage()`.

| Setting               | Default     | Applies to                             |
| --------------------- | ----------- | -------------------------------------- |
| `RATE_LIMIT_READ`     | `60/minute` | GET API routes                         |
| `RATE_LIMIT_WRITE`    | `30/minute` | Mutations                              |
| `RATE_LIMIT_EXTERNAL` | `10/minute` | Price refresh + `GET /prices/{symbol}` |

## Transaction Endpoints

| Method   | Path                       | Description                                                            |
| -------- | -------------------------- | ---------------------------------------------------------------------- |
| `POST`   | `/transactions`            | Legacy — caller supplies `asset_id` + `account_id` UUIDs               |
| `POST`   | `/transactions/smart`      | Smart — names/symbols; resolves or creates account + asset server-side |
| `PUT`    | `/transactions/{id}`       | Legacy partial update; reverses then reapplies on same asset row       |
| `PUT`    | `/transactions/{id}/smart` | Smart update; reverses on old asset, re-resolves from payload          |
| `DELETE` | `/transactions/{id}`       | Reverses asset effect and deletes row                                  |

## Transaction → Asset → Snapshot Chain

The core invariant: **any write to `transactions` must keep the parent `Asset` and a `NetWorthSnapshot` in sync** (helpers in [app/services/asset_sync.py](../app/services/asset_sync.py)):

1. `update_asset_from_transaction` adjusts `asset.quantity` and resets `asset.current_value = quantity * price_per_unit` (mark-to-market, not cost-basis).
2. `record_networth_snapshot` sums `current_value` across all user assets and writes a new row.
3. Both are called inside the same DB transaction before `db.commit()`.

**Update:** reverses old effect (`is_reversal=True`) then applies new values.

**Delete + backdated correction:** computes `delta` and applies it to every `NetWorthSnapshot` whose `date >= tx.date`, then appends a fresh snapshot at "now".

**Missing-asset guard:** If the `Asset` row is missing at update time, returns **409 Conflict**. `TransactionService.smart_update` raises `SmartUpdateMissingLinkedAssetError`; covered by tests and `VT_BREAK_TESTS` falsification fixture.

## FIRE Calculator

| Path                           | Role                                                              |
| ------------------------------ | ----------------------------------------------------------------- |
| `GET/PUT /api/v1/fire/profile` | Persisted inputs (one row per user, `user_id` unique)             |
| `GET /api/v1/fire/projection`  | Live projection from saved profile + `aggregate_dashboard` totals |

**Files:** `app/routers/fire.py`, `app/models/fire_profile.py`, `app/schemas/fire.py`, `app/services/fire_service.py` (constants + math), `app/services/fire_projection.py` (response assembly).

`DELETE /api/v1/users/me/data` bulk-deletes `fire_profiles` for the user (cascade alone does not run on bulk delete).

## Settings Reference

| Variable                    | Default                       | Notes                                       |
| --------------------------- | ----------------------------- | ------------------------------------------- |
| `DATABASE_URL`              | `sqlite:///./vaulttracker.db` | Use `postgresql://...` for Neon/Render      |
| `DEBUG`                     | `false`                       | FastAPI debug flag                          |
| `DEBUG_AUTH_ENABLED`        | `false`                       | Enables debug token bypass                  |
| `ALLOWED_ORIGINS`           | localhost 3000/8000           | Comma-separated CORS origins                |
| `FIREBASE_CREDENTIALS_PATH` | (empty)                       | Service account JSON; required for real JWT |
| `ALPHA_VANTAGE_API_KEY`     | (empty)                       | Stock quotes (`/prices`, refresh)           |
| `RATE_LIMIT_READ`           | `60/minute`                   | SlowAPI read tier                           |
| `RATE_LIMIT_WRITE`          | `30/minute`                   | SlowAPI write tier                          |
| `RATE_LIMIT_EXTERNAL`       | `10/minute`                   | Price refresh + public price lookup         |
