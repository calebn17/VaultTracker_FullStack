# CI/CD Testing Pipeline Design

**Date:** 2026-03-29
**Status:** Approved

## Context

VaultTracker has three sub-projects sharing a monorepo: a FastAPI backend (`VaultTrackerAPI/`), an iOS app (`VaultTrackerIOS/`), and a Next.js web app (`VaultTrackerWeb/`). There is currently no CI pipeline. This spec covers the testing layer of a GitHub Actions CI/CD pipeline.

## Goals

- Run automated tests on every PR and push to `main`
- Only run tests for the sub-project(s) that actually changed (path-based filtering)
- All jobs run on `macos-latest` for environment consistency
- Unit tests only in this phase; e2e is a clearly defined future extension

## Architecture

### Trigger

```
on:
  pull_request:  branches: [main]
  push:          branches: [main]
```

### Job Graph

```
changes (ubuntu-latest)
  ├── outputs: api, ios, web (boolean flags)
  │
  ├── test-api   (macos-latest)  — if: api == true
  ├── test-ios   (macos-latest)  — if: ios == true
  └── test-web   (macos-latest)  — if: web == true
```

All three test jobs are independent and run in parallel when multiple flags are true.

### Change Detection

Uses `dorny/paths-filter@v3` to output per-sub-project boolean flags:

| Flag | Watches |
|------|---------|
| `api` | `VaultTrackerAPI/**` |
| `ios` | `VaultTrackerIOS/**` |
| `web` | `VaultTrackerWeb/**` |

Changes to root-level files (e.g., `CLAUDE.md`, `.github/workflows/ci.yml`) match no filter — all jobs skip. This is intentional.

### test-api

- Runner: `macos-latest`
- Setup: Python 3.11, `pip install -r requirements.txt`
- Command: `python -m pytest tests/ -v`
- Secrets required: none (in-memory SQLite via `conftest.py`, auth overrides in place)

### test-ios

- Runner: `macos-latest`
- Command: `xcodebuild test` using `VaultTracker.xctestplan`, scheme `VaultTracker`
- Destination: `platform=iOS Simulator,name=iPhone 16`
- Target: unit tests only (`VaultTrackerTests`); UI tests excluded

### test-web

- Runner: `macos-latest`
- Setup: Node.js 20, `npm ci`
- Command: `npm test` → maps to `vitest run`
- Secrets required: none

## Future Extension Points

**Web e2e (Playwright):** Add `test-web-e2e` job under the same `web` path filter. Spin up Next.js (`npm run build && npm start`), then run `npx playwright test`. `playwright.config.ts` already exists.

**iOS e2e (XCUITest):** Add `test-ios-e2e` job using the `VaultTrackerUITests` target (already scaffolded at `VaultTrackerIOS/VaultTrackerUITests/`). Same macOS runner, separate job so unit tests still pass fast.

## Verification Checklist

1. PR with only `VaultTrackerAPI/` changes → only `test-api` runs
2. PR with only `VaultTrackerWeb/` changes → only `test-web` runs
3. PR touching all three → all three jobs run in parallel
4. Deliberate test failure in one sub-project → that job fails, PR blocked
5. Change only to `CLAUDE.md` → all jobs skipped
