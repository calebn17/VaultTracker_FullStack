# app/routers/CLAUDE.md

Routers handle HTTP concerns only — parse request, auth check, call service or query DB, return response. Business logic lives in `app/services/`.

> **Transaction endpoint details, cache pattern, sync/async notes, households:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Router Map

| File              | Prefix          | Notes                                                                                          |
| ----------------- | --------------- | ---------------------------------------------------------------------------------------------- |
| `accounts.py`     | `/accounts`     | Plain CRUD, no service layer                                                                   |
| `assets.py`       | `/assets`       | Plain CRUD + optional `?category=` filter                                                      |
| `transactions.py` | `/transactions` | Smart + legacy create/update/delete                                                            |
| `dashboard.py`    | `/dashboard`    | `GET /` per-user aggregate; `GET /household` merged household view (membership required)       |
| `networth.py`     | `/networth`     | History with `period=daily\|weekly\|monthly\|all`; cached; `async def`                         |
| `analytics.py`    | `/analytics`    | Delegates to `AnalyticsService`; cached                                                        |
| `prices.py`       | `/prices`       | Delegates to `PriceService`; `async def`                                                       |
| `users.py`        | `/users`        | Current user profile                                                                           |
| `fire.py`         | `/fire`         | FIRE profile + projection                                                                      |
| `households.py`   | `/households`   | Create household, invite codes, join by code, leave, `GET /me`; max 2 members in v1           |
