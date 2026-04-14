---
title: Clearing Postgres DB
tags:
  - vaulttracker
  - backend
  - postgres
  - debugging
date: 2026-03-27
---

# Clearing Postgres DB — Synthesis

## The Gotcha

When you clear/wipe your Postgres database during development, the VaultTracker API may return `UndefinedTable` errors on the next request, even though the schema *should* exist.

## Root Cause

**Tables are created only on API startup**, not continuously. In `VaultTrackerAPI/app/main.py` (lines 28–32), the FastAPI lifespan context manager runs `Base.metadata.create_all()`:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create database tables on startup
    Base.metadata.create_all(bind=engine)
    yield
```

**The issue:** If the API process is still running when you wipe the database:
- The running process already executed `lifespan` once
- It doesn't re-run when the DB is cleared
- The empty database never gets `create_all()` executed against it
- Next request → `UndefinedTable` error

Same problem if you restart Postgres (`docker compose down -v`) but forget to restart the API.

## The Fix

1. **Restart the FastAPI server** after wiping the database
   - This re-runs `lifespan` and recreates the schema
2. **Verify** with a health check: `GET http://localhost:8000/health`
3. **Check logs** — no `UndefinedTable` errors on subsequent requests

## Key Takeaway

This is **expected behavior with the current design**: schema is ensured on API startup, not continuously validated. Just remember to restart the API after clearing the DB.
