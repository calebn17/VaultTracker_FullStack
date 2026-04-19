# app/routers/CLAUDE.md

Routers handle HTTP concerns only — parse request, auth check, call service or query DB, return response. Business logic lives in `app/services/`.

> **Transaction endpoint details, cache pattern, sync/async notes, households:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Router Map

| File              | Prefix          | Notes                                                                                                                                                                         |
| ----------------- | --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `accounts.py`     | `/accounts`     | Plain CRUD, no service layer                                                                                                                                                  |
| `assets.py`       | `/assets`       | Plain CRUD + optional `?category=` filter                                                                                                                                     |
| `transactions.py` | `/transactions` | Smart + legacy create/update/delete                                                                                                                                           |
| `dashboard.py`    | `/dashboard`    | `GET /` per-user aggregate; `GET /household` merged household view (membership required)                                                                                      |
| `networth.py`     | `/networth`     | `GET /history` per user; `GET /history/household` combined series; cached; `async def`                                                                                        |
| `analytics.py`    | `/analytics`    | `GET /` per user; `GET /household` aggregates all member assets/transactions (requires household); both cached (`analytics:{user_id}` / `analytics:household:{household_id}`) |
| `prices.py`       | `/prices`       | Delegates to `PriceService`; `async def`                                                                                                                                      |
| `users.py`        | `/users`        | Current user profile                                                                                                                                                          |
| `fire.py`         | `/fire`         | FIRE profile + projection                                                                                                                                                     |
| `households.py`   | `/households`   | Create, invite codes, join, leave, `GET /me`, `GET/PUT /me/fire-profile`; max 2 members in v1                                                                                 |
