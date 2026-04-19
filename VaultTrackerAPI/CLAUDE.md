# CLAUDE.md — VaultTrackerAPI

FastAPI + SQLAlchemy backend. All routes under `/api/v1`. Default DB is SQLite; set `DATABASE_URL` for PostgreSQL.

> **Architecture, auth, rate limiting, transaction chain, FIRE calculator, settings:** [`Documentation/system_design.md`](Documentation/system_design.md)

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

| Launch method | Backend target |
|---------------|---------------|
| Simulator (DEBUG) | `localhost:8000` |
| Real device (DEBUG) | Set `API_HOST = 192.168.x.x:8000` in Xcode scheme env vars |
| Archive (RELEASE) | `https://vaulttracker-api.onrender.com` |

### Git Hygiene

`VaultTrackerAPI/.env` is gitignored — never commit it. If `ALPHA_VANTAGE_API_KEY` or other secrets were ever tracked, rotate them.

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
```

`tests/conftest.py` uses in-memory SQLite and auth overrides — tests never touch `vaulttracker.db` or Firebase.

## Demo Portfolio Seed

Loads realistic demo holdings for `VaultTrackerWeb` or manual API exploration:

```bash
cd VaultTrackerAPI
./venv/bin/python scripts/seed_demo_portfolio.py --clear
```

- Default user: `firebase_id: "debug-user"` (matches `DEBUG_AUTH_ENABLED` + Bearer `vaulttracker-debug-user`)
- `--clear` deletes existing transactions/snapshots/assets/accounts before seeding — always use it on repeat runs to avoid duplicate buys
- Requires API running with `DEBUG_AUTH_ENABLED=true`; sign in with **debug** on `/login`
