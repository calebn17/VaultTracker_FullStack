# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

VaultTracker is a personal portfolio tracker with three sub-projects sharing the same Firebase Auth project and backend:

| Directory | Stack | Purpose |
|---|---|---|
| `VaultTrackerAPI/` | FastAPI + SQLAlchemy (Python) | REST backend, deployed on Render |
| `VaultTrackerIOS/` | SwiftUI + Firebase SDK (Swift) | iOS client |
| `VaultTrackerWeb/` | Next.js 15 + Tailwind (TypeScript) | Web client (in progress) |

Each sub-project has its own `CLAUDE.md` with detailed context. Start there when working within a single sub-project.

## Sub-Project Entry Points

- **API:** `VaultTrackerAPI/CLAUDE.md` — commands, architecture, auth, DB options, iOS-API contract points
- **iOS:** `VaultTrackerIOS/VaultTracker/CLAUDE.md` — architecture diagram, tab structure, refactor plan status
- **Web:** `VaultTrackerWeb/Documentation/TECHNICAL_PLAN.md` — tech stack, project structure

## System Architecture

```
Firebase Auth (shared)
      │
      ├── iOS (VaultTrackerIOS)     ──┐
      │   SwiftUI + Firebase SDK    │
      │                             │  Bearer token (Firebase JWT)
      └── Web (VaultTrackerWeb)     │
          Next.js + Firebase SDK    ├──> VaultTracker REST API (VaultTrackerAPI)
                                   │    FastAPI /api/v1/*
                                   │    SQLite (local) / PostgreSQL on Neon (prod)
                                   └──> Render (production host)
```

All clients authenticate with Firebase and pass the JWT as a Bearer token to the backend. The backend verifies it with Firebase Admin SDK.

## Cross-Cutting Concerns

### API–iOS Contract

Renaming any of the following is a **breaking change** that requires updating both sides simultaneously:

- Dashboard category keys: `crypto`, `stocks`, `cash`, `realEstate`, `retirement`
- `account_type` values: `cryptoExchange`, `brokerage`, `bank`, `retirement`, `other`
- `transaction_type` values: `"buy"`, `"sell"`

The iOS `DashboardMapper`, `AccountMapper`, and `TransactionMapper` in `VaultTrackerIOS/VaultTracker/API/Mappers/` mirror the API schemas in `VaultTrackerAPI/app/schemas/`.

### Debug Auth Bypass

Both API and iOS must agree on the debug token. In the API `.env`: `DEBUG_AUTH_ENABLED=true`. In iOS `AuthTokenProvider`: `isDebugSession = true` returns `"vaulttracker-debug-user"`. The backend maps this to a fixed `firebase_id` so DB rows persist across restarts.

### Environment Switching

- **iOS:** Compile-time `#if DEBUG` → `development` (reads `API_HOST` env var, default `localhost:8000`) / `production` (`https://vaulttracker-api.onrender.com`). No source change needed before archiving.
- **API:** `.env` `DATABASE_URL` selects SQLite (default/local) or PostgreSQL (production on Neon via Render).
- **Real device:** Set `API_HOST = 192.168.x.x:8000` in Xcode scheme environment variables (same Wi-Fi required).

## Quick Commands

### API (from `VaultTrackerAPI/`)
```bash
source venv/bin/activate
uvicorn app.main:app --reload          # Dev server at localhost:8000
./venv/bin/python -m pytest tests/ -v  # All tests
./venv/bin/python -m pytest tests/test_transactions.py -q  # Single file
```

### iOS
Build and run via Xcode (`VaultTrackerIOS/VaultTracker.xcodeproj`). Tests run with `Cmd+U`.

### Web (from `VaultTrackerWeb/`)
```bash
npm run dev    # Dev server at localhost:3000
npm run build  # Production build
```
