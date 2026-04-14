---
tags:
  - vaultTracker
  - python
  - backend
title: VaultTracker Backend V2 Summary
---

## High-level technical summary (VaultTracker API / Backend 2.0)

### Architecture

- Service layer was introduced under `app/services/`: domain logic moved out of routers where it made sense (`TransactionService`, `AnalyticsService`, `PriceService`, shared `asset_sync` for mark-to-market + net-worth snapshots, `cache_service` for read-through caching).
- Routers stay thin: HTTP, auth, validation, call services or DB, return Pydantic models.

### Infrastructure & security

- Database: Engine setup is URL-driven (`DATABASE_URL`). SQLite keeps `check_same_thread=False`; PostgreSQL uses `pool_pre_ping`. `psycopg2-binary` added for Postgres.
- Auth: Firebase Admin verifies ID tokens when `FIREBASE_CREDENTIALS_PATH` is set; `DEBUG_AUTH_ENABLED` + debug Bearer token still bypasses verification for local dev. Misconfiguration yields 503 with a clear message instead of silently treating raw strings as `firebase_id`.
- CORS: No longer `*`; comma-separated `ALLOWED_ORIGINS` (defaults include local web + Swagger hosts).

### API behavior

- `POST /api/v1/transactions/smart`: One payload can resolve or create account + asset, then create a transaction and run the same asset + net-worth snapshot pipeline as the legacy POST.
- `GET /api/v1/transactions`: Returns enriched rows (nested asset/account summaries + `total_value`) while keeping IDs for older clients.
- `GET /api/v1/analytics`: Server-side allocation by category and a simple performance block from transaction history + current values.
- `GET /api/v1/networth/history`: `period` is implemented: daily / weekly (ISO week) / monthly / all, with unknown values falling back to the full series for compatibility.
- `/api/v1/prices`: `GET /{symbol}` (crypto via CoinGecko map, then stocks via Alpha Vantage) and `POST /refresh` to revalue holdings and append a snapshot when updates occur.

### Caching

- In-memory TTL (`cachetools`): one pool for dashboard/analytics/net-worth responses; separate TTLs for crypto vs stock price lookups.
- Invalidation on user-scoped writes: transactions (including smart create) and price refresh call `invalidate_user` so cached dashboard/analytics/history keys drop.

### Dependencies

- Added: `firebase-admin`, `psycopg2-binary`, `httpx`, `cachetools`, `pytest`.

### Testing

- `pytest` + `TestClient`, in-memory SQLite (`StaticPool`) and overrides for `get_db` / `get_current_user` so tests don’t touch real DB or Firebase.
- Coverage: health, smart + legacy transactions, net worth periods (incl. weekly/monthly), analytics shape, dashboard cache fill/invalidate, prices with mocked HTTP.
- `VT_BREAK_TESTS=1`: optional injected regressions to prove the suite fails when core behavior breaks.

### Documentation & repo hygiene

- Backend 2.0 spec added; legacy docs moved under `Documentation/Legacy/`.
- `.env.example`, root `CLAUDE.md`, Cursor rule (collaboration + checklist sync with the spec), and scoped `CLAUDE.md` under `app/routers/` and `app/services/`.

Net effect: the backend is closer to a real service layer (resolution and analytics on the server), production-oriented auth and CORS, optional Postgres, external pricing, caching, and automated regression tests instead of relying only on Swagger.