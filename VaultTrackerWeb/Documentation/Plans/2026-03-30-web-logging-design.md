# VaultTrackerWeb Logging Design

**Date:** 2026-03-30

---

## Context

VaultTrackerWeb has no logging infrastructure. Errors are surfaced only as toasts or React Query error states — silent in production and invisible beyond the browser. Adding a layered logging system will make bugs traceable during development and automatically captured in production via Sentry.

**Current state:**

- One bare `console.error` call in `login/page.tsx`
- No error boundaries (component crashes can silently white-screen)
- No structured API request/error logging
- No production monitoring

---

## Goals

- Give developers structured, readable logs during local development
- Capture unhandled errors and API failures automatically in production
- Add React error boundaries so crashes never produce a blank page
- Log auth lifecycle events (sign-in, sign-out, token refresh, 401 retries) for tracing auth bugs
- Keep all Sentry coupling in one place so it's easy to swap or remove

---

## Architecture

### Logger module (`src/lib/logger.ts`)

A single `logger` singleton exported from one file. Three methods:

```
logger.info(message, context?)          // dev → console.log;  prod → no-op
logger.warn(message, context?)          // dev → console.warn; prod → Sentry.captureMessage (warning)
logger.error(message, error?, context?) // dev → console.error; prod → Sentry.captureException
```

**Rules:**

- Never throws
- Never logs PII (no tokens, no personal data)
- `info` is dev-only — suppressed in production to avoid noise
- `warn` and `error` go to Sentry in production
- Sentry is only imported inside this file — no Sentry calls elsewhere in the codebase

### Instrumentation points

| File                                | What is logged                                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `src/lib/api-client.ts`             | Every request: method, endpoint, duration (`info`); every `ApiError`: status + message (`error`); 401 retry (`warn`) |
| `src/contexts/auth-context.tsx`     | Sign-in success/failure, sign-out, force-token-refresh after 401, token refresh failure                              |
| `src/app/(authenticated)/error.tsx` | All authenticated-route render crashes → `logger.error` + fallback UI                                                |
| `src/app/error.tsx`                 | Root-level render crashes → `logger.error` + fallback UI                                                             |
| `src/app/login/page.tsx`            | Replace bare `console.error` with `logger.error`                                                                     |

---

## Phased Plan

### Phase 1 — Logger foundation + API observability

**New file:** `src/lib/logger.ts`

- `info`: dev-only, writes to `console.log` with structured context
- `warn`: `console.warn` in dev; no-op stub in prod (Sentry wired in Phase 3)
- `error`: `console.error` in dev; no-op stub in prod (Sentry wired in Phase 3)

**Modify:** `src/lib/api-client.ts`

- Record `Date.now()` before fetch; call `logger.info` with method/endpoint/duration on success
- Call `logger.error('API error', error, { status, endpoint })` before throwing `ApiError`
- Call `logger.warn('401 — retrying with refreshed token', { endpoint })` in the 401-retry path

### Phase 2 — React error boundaries + auth event logging

**New files:** `src/app/(authenticated)/error.tsx` and `src/app/error.tsx`

- Both are `'use client'` components using Next.js App Router error boundary convention
- On mount: call `logger.error` with the error and React's `digest`
- Render: "Something went wrong" heading + "Try again" button that calls `reset()`

**Modify:** `src/contexts/auth-context.tsx`

- Sign-in success: `logger.info('User signed in', { uid })`
- Sign-in failure: `logger.error('Sign-in failed', error)`
- Sign-out: `logger.info('User signed out')`
- Force-refresh after 401: `logger.warn('Force-refreshing token after 401')`
- Token refresh failure: `logger.error('Token refresh failed', error)`

**Modify:** `src/app/login/page.tsx`

- Replace `signInWithGoogle().catch(console.error)` with `signInWithGoogle().catch(e => logger.error('Google sign-in failed', e))`

### Phase 3 — Sentry production integration

**Install:** `@sentry/nextjs`

**New files:**

- `sentry.client.config.ts` — init with DSN, `tracesSampleRate: 0.1`
- `sentry.server.config.ts` — same
- `sentry.edge.config.ts` — same

**Modify:** `next.config.ts` — wrap with `withSentryConfig`

**Modify:** `.env.local.example` — add `NEXT_PUBLIC_SENTRY_DSN=your_sentry_dsn_here`

**Modify:** `src/lib/logger.ts` — replace no-op prod stubs with real Sentry calls:

- `warn` prod path: `Sentry.captureMessage(message, 'warning')`
- `error` prod path: `Sentry.captureException(error ?? new Error(message), { extra: context })`

---

## Critical Files

| File                                | Action                                 |
| ----------------------------------- | -------------------------------------- |
| `src/lib/logger.ts`                 | Create                                 |
| `src/lib/api-client.ts`             | Modify — add request/error/401 logging |
| `src/contexts/auth-context.tsx`     | Modify — add auth lifecycle logging    |
| `src/app/login/page.tsx`            | Modify — replace bare console.error    |
| `src/app/(authenticated)/error.tsx` | Create                                 |
| `src/app/error.tsx`                 | Create                                 |
| `sentry.client.config.ts`           | Create                                 |
| `sentry.server.config.ts`           | Create                                 |
| `sentry.edge.config.ts`             | Create                                 |
| `next.config.ts`                    | Modify — wrap with withSentryConfig    |
| `.env.local.example`                | Modify — add NEXT_PUBLIC_SENTRY_DSN    |

---

## Testing

| Test file                                                   | What is tested                                                                                                                                                                |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/lib/__tests__/logger.test.ts` (create)                 | `info` is a no-op in prod; `warn` calls `Sentry.captureMessage` in prod and `console.warn` in dev; `error` calls `Sentry.captureException` in prod and `console.error` in dev |
| `src/lib/__tests__/api-client.test.ts` (extend)             | `logger.error` called on non-2xx; `logger.warn` called on 401 retry; `logger.info` called on success                                                                          |
| `src/components/__tests__/error-boundary.test.tsx` (create) | Throwing component renders fallback UI; `logger.error` is called                                                                                                              |
| `src/contexts/__tests__/auth-context.test.tsx` (extend)     | `logger.info` on sign-in success; `logger.error` on sign-in failure                                                                                                           |

All tests mock `logger` via `vi.mock('@/lib/logger')`, consistent with the existing Vitest mock patterns in the codebase.

---

## Verification

1. `npm test` — all Vitest tests pass including new logger, error boundary, and extended ApiClient/auth tests
2. Dev smoke test: `npm run dev`, trigger an API error, confirm structured log appears in browser console
3. Error boundary smoke test: temporarily throw in a page component, confirm fallback UI renders
4. Production build: `npm run build` passes with no TypeScript or Sentry config errors
5. Sentry smoke test: set `NEXT_PUBLIC_SENTRY_DSN`, trigger an error in a production-mode build, confirm it appears in the Sentry dashboard
