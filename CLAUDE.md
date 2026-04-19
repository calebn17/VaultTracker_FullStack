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

> **System architecture, cross-cutting concerns (API contract, debug auth, environment switching), and CI job details:** [`Documentation/system_design.md`](Documentation/system_design.md)

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
