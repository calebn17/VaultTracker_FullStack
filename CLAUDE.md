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

## Cursor agent hooks

- **[`.cursor/hooks.json`](.cursor/hooks.json)** registers:
  - **`beforeShellExecution`** — [`.cursor/hooks/block-dangerous.sh`](.cursor/hooks/block-dangerous.sh) blocks a small set of risky shell patterns (e.g. `rm -rf`, `git reset --hard`, forced push, curl/wget piped to shell).
  - **`preToolUse`** (Write / StrReplace / etc.) — [`.cursor/hooks/protect-files.sh`](.cursor/hooks/protect-files.sh) blocks edits to protected paths (e.g. `.env*`, `.git/*`, lockfiles, `*.pem` / `*.key`, `secrets/*`).
- Requires **`jq`** on your PATH. See [Cursor hooks](https://cursor.com/docs/hooks).

## Best practices

- **Avoid duplicating code.** When the same logic appears in more than one place, extract it into a shared helper, utility, or abstraction (service layer, hook, extension, etc.) so behavior stays consistent and fixes land in one place.

- **Write tests that can fail and that matter.** Each test should exercise real behavior: given a concrete **input**, assert a distinct **expected outcome** from the code under test. Skip tests added only to pad coverage or “have a test”—and avoid tautologies (e.g. comparing a literal to itself or re-stating constants without invoking production logic). If breaking the implementation would not plausibly turn the test red, the test is not doing useful work.

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
npm test       # Same as CI: Vitest (`vitest run`)
```

## GitHub Actions CI

Workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Full rationale and future extensions: [`Documentation/Plans/2026-03-29-ci-cd-testing-design.md`](Documentation/Plans/2026-03-29-ci-cd-testing-design.md).

**Triggers:** `pull_request` and `push` to `main`.

**Layout:** A `changes` job on `ubuntu-latest` uses [`dorny/paths-filter@v3`](https://github.com/dorny/paths-filter) to set `api` / `ios` / `web` flags from paths under `VaultTrackerAPI/**`, `VaultTrackerIOS/**`, and `VaultTrackerWeb/**`. For each stack, a **`lint-*` job runs first** (Ubuntu for API + Web, macOS for iOS); **`test-*` runs only if** the matching path flag is true **and** the corresponding lint job succeeded (`always()` + `needs.lint-*.result == 'success'`). Lint details and reviewdog behavior: [`Documentation/Plans/2026-04-02-linting-design.md`](Documentation/Plans/2026-04-02-linting-design.md).

**Root-only edits** (e.g. `CLAUDE.md`, `.github/workflows/ci.yml`) match no path filter, so all lint and test jobs are skipped by design.

| Job | What runs |
|-----|-----------|
| `lint-api` | Ubuntu, Python 3.11, Ruff (`ruff format --check`, `ruff check` E/F/I blocking + W/C90/N via reviewdog). |
| `lint-ios` | macOS, Homebrew SwiftLint + reviewdog (`VaultTrackerIOS/VaultTracker`). |
| `lint-web` | Ubuntu, Node 20, `npm ci`, Prettier `--check`, ESLint JSON + reviewdog. |
| `test-api` | macOS, Python 3.11, `pip install -r requirements.txt`, `python -m pytest tests/ -v` in `VaultTrackerAPI/` (no secrets; SQLite tests). |
| `test-ios` | macOS, `xcodebuild test` in `VaultTrackerIOS/`: project `VaultTracker.xcodeproj`, scheme `VaultTracker`, test plan `VaultTrackerUnitTests`, destination `platform=iOS Simulator,name=iPhone 17,OS=latest`, `TestResults.xcresult`. Unit tests only. |
| `test-web` | macOS, Node 20, `npm ci`, `npm test` in `VaultTrackerWeb/` (Vitest). |

**Planned extensions** (not in the workflow yet): Playwright e2e for web; XCUITest job for `VaultTrackerUITests` — see the CI testing design doc.
