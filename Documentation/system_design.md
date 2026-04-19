# VaultTracker System Design

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

All clients authenticate with Firebase and pass the JWT as a Bearer token. The backend verifies it with Firebase Admin SDK.

## Cross-Cutting Concerns

### API–iOS–Web Contract

Renaming any of the following is a **breaking change** that requires updating all three sides simultaneously:

- Dashboard category keys: `crypto`, `stocks`, `cash`, `realEstate`, `retirement`
- `account_type` values: `cryptoExchange`, `brokerage`, `bank`, `retirement`, `other`
- `transaction_type` values: `"buy"`, `"sell"`

The iOS `DashboardMapper`, `AccountMapper`, and `TransactionMapper` in `VaultTrackerIOS/VaultTracker/API/Mappers/` mirror the API schemas in `VaultTrackerAPI/app/schemas/`. The web `src/types/api.ts` mirrors the same schemas.

### Debug Auth Bypass

All three parties must agree on the token:

- **API** (`.env`): `DEBUG_AUTH_ENABLED=true` — maps Bearer `vaulttracker-debug-user` to `firebase_id: "debug-user"`
- **iOS** (`AuthTokenProvider`): `isDebugSession = true` returns `"vaulttracker-debug-user"`
- **Web** (`src/lib/auth-debug.ts`): `DEBUG_AUTH_TOKEN = "vaulttracker-debug-user"`, only bundled when `NODE_ENV === "development"`

DB rows persist across restarts because the backend always uses the same fixed `firebase_id`.

### Environment Switching

| Client | Dev target                                       | Prod target                             | Switch mechanism         |
| ------ | ------------------------------------------------ | --------------------------------------- | ------------------------ |
| iOS    | `localhost:8000` (or `API_HOST` env var)         | `https://vaulttracker-api.onrender.com` | Compile-time `#if DEBUG` |
| Web    | `NEXT_PUBLIC_API_URL` (default `localhost:8000`) | Vercel env var                          | Build-time env var       |
| API    | SQLite (default)                                 | PostgreSQL on Neon                      | `DATABASE_URL` in `.env` |

**Real device:** Set `API_HOST = 192.168.x.x:8000` in Xcode scheme environment variables (same Wi-Fi required).

## GitHub Actions CI

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

**Triggers:** `pull_request` and `push` to `main`.

**Layout:** A `changes` job uses `dorny/paths-filter@v3` to set `api`/`ios`/`web` flags. Lint runs first; tests run only if lint passes. Root-only edits skip all jobs by design.

| Job        | What runs                                                                                              |
| ---------- | ------------------------------------------------------------------------------------------------------ |
| `lint-api` | Ubuntu, Python 3.11, Ruff (`ruff format --check`, `ruff check` E/F/I blocking + W/C90/N via reviewdog) |
| `lint-ios` | macOS, Homebrew SwiftLint + reviewdog                                                                  |
| `lint-web` | Ubuntu, Node 20, Prettier `--check`, ESLint JSON + reviewdog                                           |
| `test-api` | macOS, Python 3.11, `pytest tests/ -v` (SQLite, no secrets)                                            |
| `test-ios` | macOS, `xcodebuild test`, scheme `VaultTracker`, plan `VaultTrackerUnitTests`, iPhone 17 simulator     |
| `test-web` | macOS, Node 20, Vitest                                                                                 |

**Planned extensions:** Playwright e2e for web; XCUITest job for `VaultTrackerUITests`.
