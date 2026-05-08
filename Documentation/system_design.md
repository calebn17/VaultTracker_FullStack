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

## VaultTrackerScanner (personal ingest)

Not a deployed client — a **Python package** in `VaultTrackerScanner/` for bootstrapping history from CSV (and optional vision-assisted JSON) into the same API the apps use.

- **Flow:** `inbox/` → discover → parse → normalize → validate → preview → optional `POST /api/v1/transactions/smart` → `processed/` archive with `manifest.json` + payload JSON for recovery.
- **Auth:** Uses the same **debug Bearer** contract as iOS/Web dev (`vaulttracker-debug-user` → `debug-user` on the API). Typical target: `http://localhost:8000`.
- **Docs:** [`VaultTrackerScanner/README.md`](../VaultTrackerScanner/README.md), agent workflow [`VaultTrackerScanner/Documentation/Scan_Agent_Workflow.md`](../VaultTrackerScanner/Documentation/Scan_Agent_Workflow.md), Cursor skill [`.cursor/skills/vaulttracker-scan/SKILL.md`](../.cursor/skills/vaulttracker-scan/SKILL.md), plan [`Documentation/Plans/2026-05-02-scanner-design.md`](Plans/2026-05-02-scanner-design.md).
- **CI:** Not on the `api`/`ios`/`web` path filter today; scanner tests run locally (`pytest` / `ruff` from `VaultTrackerScanner/`).

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
