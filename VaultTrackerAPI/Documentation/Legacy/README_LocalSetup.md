# VaultTrackerAPI — Local Development Setup
## Quick Links
- Docker + PostgreSQL guide: [Documentation/Docker_Postgres_Setup.md](../Docker_Postgres_Setup.md)

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.13 | Confirmed from `venv/pyvenv.cfg` |
| pip | bundled with Python 3.13 | — |
| PostgreSQL | optional | SQLite is used by default; see [Database Setup](#database-setup) |

---

## 1. Clone & Enter the Project

```bash
cd "path/to/iOS Development/VaultTrackerAPI"
```

---

## 2. Create & Activate a Virtual Environment

```bash
python3.13 -m venv venv
source venv/bin/activate   # macOS/Linux
# venv\Scripts\activate    # Windows
```

Your prompt should now show `(venv)`.

---

## 3. Install Dependencies

```bash
pip install -r requirements.txt
```

Key packages installed:

| Package | Purpose |
|---------|---------|
| `fastapi` | Web framework |
| `uvicorn` | ASGI server |
| `sqlalchemy` | ORM / database access |
| `pydantic` | Request/response validation |
| `python-dotenv` | `.env` file loading |
| `alembic` | Database migrations (if used) |

---

## 4. Configure Environment Variables

Create a `.env` file in the project root:

```bash
cp .env.example .env   # if an example exists, otherwise create manually
```

Minimum required variables:

```dotenv
APP_NAME=VaultTrackerAPI
DEBUG=true

# SQLite (default — zero config, tables auto-created on startup)
DATABASE_URL=sqlite:///./vaulttracker.db

# PostgreSQL alternative (uncomment and fill in if using Postgres)
# DATABASE_URL=postgresql://username:password@localhost:5432/vaulttracker
```

`DATABASE_URL` is read by `app/config.py`. If omitted, the app defaults to SQLite.

---

## 5. Database Setup

### Option A: SQLite (default, recommended for local dev)

No setup needed. Tables are created automatically via `Base.metadata.create_all()` when the server starts.

### Option B: PostgreSQL

1. Create the database:
   ```bash
   psql -U postgres
   CREATE DATABASE vaulttracker;
   \q
   ```

2. Set `DATABASE_URL` in `.env`:
   ```dotenv
   DATABASE_URL=postgresql://postgres:yourpassword@localhost:5432/vaulttracker
   ```

3. Tables are still auto-created on first startup.

---

## 6. Run the Server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

| Flag | Effect |
|------|--------|
| `--reload` | Auto-restarts on file changes |
| `--host 0.0.0.0` | Accessible from iOS simulator on the same machine |
| `--port 8000` | Matches `APIConfiguration.swift` dev base URL |

---

## 7. Verify It's Working

### Health check
```bash
curl http://localhost:8000/health
# Expected: {"status":"healthy"}
```

### Interactive API docs
Open in browser: `http://localhost:8000/docs`

### Test an authenticated endpoint

The dev server accepts a simple bearer token for testing (before Firebase JWT is enforced):

```bash
curl -H "Authorization: Bearer test-user-123" \
     http://localhost:8000/api/v1/dashboard
```

---

## 8. Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| `Address already in use` on port 8000 | Another process using the port | `lsof -i :8000` then `kill <PID>`, or use `--port 8001` |
| `ModuleNotFoundError: No module named 'fastapi'` | Virtual env not activated | Run `source venv/bin/activate` first |
| `sqlalchemy.exc.OperationalError` (Postgres) | DB not running or wrong credentials | Start Postgres, verify `DATABASE_URL` in `.env` |
| `401 Unauthorized` on all endpoints | Missing or malformed `Authorization` header | Include `Authorization: Bearer <token>` in every request |
| iOS app can't reach server | Simulator uses `localhost` correctly; physical device needs your Mac's LAN IP | Change `APIEnvironment.development` base URL in `APIConfiguration.swift` to your Mac's IP (e.g. `http://192.168.1.x:8000`) |

---

## 9. Firebase / JWT (Production Auth)

The current dev setup accepts any bearer token. To enable real Firebase JWT verification:

1. Add your Firebase service account JSON to the project
2. Set `FIREBASE_CREDENTIALS_PATH` (or equivalent) in `.env`
3. Update the auth middleware in `app/dependencies.py` (or equivalent) to call `firebase_admin.auth.verify_id_token(token)`

The iOS app (`AuthTokenProvider.swift`) already sends real Firebase ID tokens — no client changes needed.
