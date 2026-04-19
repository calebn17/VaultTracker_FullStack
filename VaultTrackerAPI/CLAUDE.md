# CLAUDE.md — VaultTrackerAPI

FastAPI + SQLAlchemy backend. All routes under `/api/v1`. Default DB is SQLite; set `DATABASE_URL` for PostgreSQL.

> **Architecture, auth, rate limiting, transaction chain, FIRE calculator, households, settings:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Collaboration Context

Primary maintainer is an **iOS developer** newer to FastAPI/Python. When reviewing changes, include:

1. **What** — which files changed and the new behavior
2. **Why** — the problem or tradeoff driving it
3. **iOS bridge** — analogies where helpful (FastAPI routes ≈ HTTP handlers, `Depends()` ≈ DI, Pydantic ≈ `Codable`, SQLAlchemy session ≈ unit of work)
4. **Pitfalls** — sync vs async, when `db.commit()` runs, CORS vs App Transport Security

Backend roadmap: [`Documentation/VaultTracker_Backend_2.0_Spec.md`](Documentation/VaultTracker_Backend_2.0_Spec.md)

## Local Development Setup

### Database Options

**PostgreSQL via Docker (matches production):**

```bash
docker compose -f docker-compose.postgres.yml up -d   # Start
docker compose -f docker-compose.postgres.yml down    # Stop (keeps data)
docker compose -f docker-compose.postgres.yml down -v # Full reset
```

Default `.env`: `DATABASE_URL=postgresql://vaulttracker:vaulttracker_dev_password@localhost:5432/vaulttracker`

**SQLite (no Docker):**

```
DATABASE_URL=sqlite:///./vaulttracker.db
```

### iOS Simulator vs Real Device

| Launch method       | Backend target                                              |
| ------------------- | ----------------------------------------------------------- |
| Simulator (DEBUG)   | `localhost:8000`                                            |
| Real device (DEBUG) | Set `API_HOST = 192.168.x.x:8000` in Xcode scheme env vars |
| Archive (RELEASE)   | `https://vaulttracker-api.onrender.com`                     |

**Real device fix:** `localhost` on a physical iPhone means the phone itself, not your Mac. Set `API_HOST` to your Mac's LAN IP in the Xcode scheme (System Settings → Wi-Fi → Details; both devices must be on the same Wi-Fi).

### Production vs Local `.env`

Your local `.env` is never deployed. Render injects its own environment variables (including the Neon `DATABASE_URL`) at runtime via the Render dashboard. The two environments are fully independent.

### Git Hygiene

`VaultTrackerAPI/.env` is ignored and must not be committed. If it was ever tracked, **rotate** any secrets that may exist in git history (for example `ALPHA_VANTAGE_API_KEY`) and keep real values only in an untracked local `.env`. Set `DEBUG=true` in `.env` when you need FastAPI debug behavior; the default in code is `DEBUG=false`.

## Commands

```bash
# One-time setup (from VaultTrackerAPI/)
python3.10 -m venv venv
./venv/bin/pip install -r requirements.txt

# Dev server
./venv/bin/uvicorn app.main:app --reload
open http://localhost:8000/docs

# Tests (always use venv interpreter)
./venv/bin/python -m pytest tests/ -v
./venv/bin/python -m pytest tests/test_analytics_dashboard_cache.py -q

# Ruff lint (mirrors CI lint-api)
./venv/bin/ruff format --check .
./venv/bin/ruff check --select E,F,I .
./venv/bin/ruff check --select W,C90,N .  # optional style/complexity

# Falsification check (prove tests can fail)
VT_BREAK_TESTS=1 ./venv/bin/python -m pytest tests/ -q
# Expect multiple failures. If suite passes, widen _vt_inject_broken_behavior_for_falsification_checks in conftest.py

# FIRE tests
./venv/bin/python -m pytest tests/test_fire.py tests/test_fire_api.py tests/test_fire_schemas.py tests/test_fire_profile_orm.py -q

# Household tests
./venv/bin/python -m pytest tests/test_households.py tests/test_household_fire.py -q

# Dashboard tests
./venv/bin/python -m pytest tests/test_dashboard_aggregate.py tests/test_dashboard_household.py tests/test_analytics_dashboard_cache.py -q

# Net worth tests
./venv/bin/python -m pytest tests/test_networth.py tests/test_household_networth.py -q
```

`tests/conftest.py` uses in-memory SQLite and auth overrides — tests never touch `vaulttracker.db` or Firebase.

## Demo Portfolio Seed

For **VaultTrackerWeb** (or manual API exploration), you can load realistic demo holdings and a long net-worth history without mocking the client. Script: [`scripts/seed_demo_portfolio.py`](scripts/seed_demo_portfolio.py).

- **Mechanism:** Inserts many backdated `SmartTransactionCreate` rows via `TransactionService.smart_create` — same write path as `POST /api/v1/transactions/smart` — so accounts, assets, transactions, and `NetWorthSnapshot` rows stay consistent with production rules.
- **Default user:** `firebase_id: "debug-user"` (matches `DEBUG_AUTH_ENABLED` + Bearer `vaulttracker-debug-user`). Override with `--firebase-id <uid>` if you need a different user row.
- **`--clear`:** Deletes that user's transactions, snapshots, assets, and accounts before seeding. Use it on repeat runs; seeding **without** `--clear` **duplicates** buys.

```bash
cd VaultTrackerAPI
./venv/bin/python scripts/seed_demo_portfolio.py --clear
```

Then run the API with `DEBUG_AUTH_ENABLED=true`, start the web app with `NEXT_PUBLIC_API_URL` pointing at the API, and sign in with **debug** on `/login`.
