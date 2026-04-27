# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

VaultTracker is a personal portfolio tracker with three sub-projects sharing the same Firebase Auth project and backend:

| Directory          | Stack                              | Purpose                          |
| ------------------ | ---------------------------------- | -------------------------------- |
| `VaultTrackerAPI/` | FastAPI + SQLAlchemy (Python)      | REST backend, deployed on Render |
| `VaultTrackerIOS/` | SwiftUI + Firebase SDK (Swift)     | iOS client                       |
| `VaultTrackerWeb/` | Next.js 15 + Tailwind (TypeScript) | Web client                       |

Each sub-project has its own `CLAUDE.md` with detailed context. Start there when working within a single sub-project.

## Sub-Project Entry Points

- **API:** `VaultTrackerAPI/CLAUDE.md` — commands, architecture, auth, DB options, iOS-API contract points
- **iOS:** `VaultTrackerIOS/VaultTracker/CLAUDE.md` — commands and rules; **architecture / features / tests:** `VaultTrackerIOS/VaultTracker/Documentation/system_design.md`
- **Web:** `VaultTrackerWeb/CLAUDE.md` — tech stack, project structure, household features
- **System design (all clients):** [`Documentation/VaultTracker System Design.md`](Documentation/VaultTracker%20System%20Design.md) — product flows, backend model/API, iOS and Web sections

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

Both API and iOS must agree on the debug token. In the API `.env`: `DEBUG_AUTH_ENABLED=true`. In iOS `AuthTokenProvider`: `isDebugSession = true` returns `"vaulttracker-debug-user"`. The web token is set in `src/lib/auth-debug.ts`. The backend maps this to a fixed `firebase_id` so DB rows persist across restarts.

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
./venv/bin/ruff format --check . && ./venv/bin/ruff check --select E,F,I .  # Lint
```

### iOS

Build and run via Xcode (`VaultTrackerIOS/VaultTracker.xcodeproj`). Tests run with `Cmd+U`.

```bash
cd VaultTrackerIOS/VaultTracker && swiftlint lint  # Lint
```

### Web (from `VaultTrackerWeb/`)

```bash
npm run dev    # Dev server at localhost:3000
npm run build  # Production build
npm test       # Vitest
npm run lint   # ESLint
npx prettier --check .  # Format check
```

## Best Practices

- **Avoid duplicating code.** Extract shared logic into helpers, service layers, hooks, or extensions.
- **Design for testability.** Keep deterministic logic in small units; push I/O to the edges.
- **Write tests that can fail.** Assert specific expected outcomes — no tautologies, no padding.
- **Design for scale.** Respect existing layering; avoid unbounded queries and N+1 paths.
- **Simplicity is best.** Make the minimal change needed. Smaller diffs are easier to review.
- **Security.** Never commit secrets. Scope every read/write by `user_id`. Don't leak stack traces.
- **Plan completion documentation.** Every implementation plan must end with a todo item to update `Documentation/VaultTracker System Design.md`.

## Cursor Agent Hooks

- **[`.cursor/hooks.json`](.cursor/hooks.json)** registers:
  - `beforeShellExecution` — blocks risky shell patterns (`rm -rf`, `git reset --hard`, forced push, curl piped to shell)
  - `preToolUse` — blocks edits to protected paths (`.env*`, `.git/*`, lockfiles, `*.pem`/`*.key`, `secrets/*`)
- Requires **`jq`** on your PATH.

## CI Jobs

**Layout:** A `changes` job uses [`dorny/paths-filter@v3`](https://github.com/dorny/paths-filter) to set `api` / `ios` / `web` flags from paths under `VaultTrackerAPI/**`, `VaultTrackerIOS/**`, and `VaultTrackerWeb/**`. For each stack, a **`lint-*` job runs first**; **`test-*` runs only if** the matching path flag is true **and** the corresponding lint job succeeded. Lint details: [`Documentation/Plans/2026-04-02-linting-design.md`](Documentation/Plans/2026-04-02-linting-design.md).

| Job        | What runs                                                                                                                                                                                                                                           |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lint-api` | Ubuntu, Python 3.11, Ruff (`ruff format --check`, `ruff check` E/F/I blocking + W/C90/N via reviewdog).                                                                                                                                             |
| `lint-ios` | macOS, Homebrew SwiftLint + reviewdog (`VaultTrackerIOS/VaultTracker`).                                                                                                                                                                             |
| `lint-web` | Ubuntu, Node 20, `npm ci`, Prettier `--check`, ESLint JSON + reviewdog.                                                                                                                                                                             |
| `test-api` | macOS, Python 3.11, `pip install -r requirements.txt`, `python -m pytest tests/ -v` in `VaultTrackerAPI/` (no secrets; SQLite tests).                                                                                                               |
| `test-ios` | macOS, `xcodebuild test` in `VaultTrackerIOS/`: project `VaultTracker.xcodeproj`, scheme `VaultTracker`, test plan `VaultTrackerUnitTests`, destination `platform=iOS Simulator,name=iPhone 17,OS=latest`, `TestResults.xcresult`. Unit tests only. |
| `test-web` | macOS, Node 20, `npm ci`, `npm test` in `VaultTrackerWeb/` (Vitest).                                                                                                                                                                                |

**Root-only edits** (e.g. `CLAUDE.md`, `.github/workflows/ci.yml`) match no path filter, so all lint and test jobs are skipped by design.

<!-- agent-harness:role:start -->
## Agent Harness — Role: coder
You are acting as the **coder** (Writes and modifies code).
Expected models: claude-sonnet, cursor-composer2
### Constraints
- Do NOT run git push.
- Do NOT install dependencies (npm install, pip install, etc.).

Available harness commands for this role:
  harness memory query "<topic>"   — retrieve relevant memories
  harness map drill "<module>"      — get detailed module map
  harness mistakes <file>            — check known pitfalls
  harness test-results [path]        — query test history
  harness rules check                — validate conventions

Read `.agent-harness/context/bootstrap.md` for full project context.
<!-- agent-harness:role:end -->
