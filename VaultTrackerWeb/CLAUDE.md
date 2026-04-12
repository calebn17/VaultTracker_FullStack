# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

All seven implementation phases (scaffolding, auth/layout, dashboard, transactions, accounts, analytics, polish) are **complete**.

- **Tests** — Vitest (unit + component) and Playwright (E2E) are wired; suites live under `src/**/__tests__/` and `e2e/`. See [Testing](#testing) below and `Documentation/Testing Plan.md` for layout, scenarios, and rationale.
- **Deployment** — Not yet deployed to Vercel; no `vercel.json`, no production URL, and the API CORS allowlist has not been updated with a Vercel domain.

See `Documentation/Web App Spec.md` Phase 7 for the open checklist items (7.3–7.9).

## Commands

```bash
npm run dev           # Dev server at localhost:3000
npm run build         # Production build
npm run lint          # ESLint
npx prettier --check .  # Format check (same as CI lint-web)
npx prettier --write .  # Apply Prettier project-wide (respects .prettierignore)
npm run test          # Vitest (unit + component), single run
npm run test:watch    # Vitest watch mode
npm run test:coverage # Vitest with coverage
npm run test:e2e      # Playwright (starts dev server via playwright.config unless one is already running)
```

**CI (`lint-web`):** On pull requests, GitHub Actions runs `npm ci`, `prettier --check`, then ESLint with **JSON output piped to reviewdog** (check annotations + optional PR review comments). Fix blocking ESLint **errors** locally with `npm run lint` before pushing. Warnings (e.g. `no-console: warn`) do not fail ESLint’s exit code unless you tighten rules.

## Testing

**Docs:** `Documentation/Testing Plan.md` describes the pyramid (Vitest for pure logic/schemas/components, Playwright for full flows), setup assumptions, and file map.

**Vitest** (`vitest.config.ts`, `vitest.setup.ts`): runs in `jsdom`; path alias `@/` matches the app. The `e2e/` folder is **excluded** so Playwright specs are not picked up as Vitest tests.

**Where tests live**

| Area                 | Location                                                                                       |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| Unit                 | `src/lib/__tests__/*.test.ts`                                                                  |
| React Query hooks    | `src/lib/queries/__tests__/*.test.tsx`                                                         |
| Components / context | `src/components/__tests__/`, `src/components/layout/__tests__/`, `src/contexts/__tests__/`     |
| App routes           | `src/app/(authenticated)/**/__tests__/` (e.g. `fire/page.test.tsx`)                            |
| E2E                  | `e2e/*.spec.ts` (e.g. `auth`, `dashboard`, `analytics`, `transactions`, `accounts`, `profile`, `fire`) |

**Transaction form dialog:** `TransactionFormDialog` awaits `onSubmit` (sync or `Promise`). On success it calls `onOpenChange(false)`; if `onSubmit` rejects, the dialog stays open. Authenticated pages should use `mutateAsync` in `onSubmit`, show toasts in a `try`/`catch`, and `throw` after `toast.error` so the dialog does not close on failure.

**Playwright** (`playwright.config.ts`): `testDir` is `./e2e`, `baseURL` `http://localhost:3000`, `webServer` runs `npm run dev` unless `CI` is set (see `reuseExistingServer`). Install browsers once: `npx playwright install --with-deps chromium`.

**E2E and debug auth:** The debug session is **only in React memory** (not persisted). After debug sign-in on `/login`, navigating with `page.goto("/transactions")` performs a **full load** and clears that session, so guarded routes bounce to `/login`. E2E flows that need `/transactions` or `/accounts` should use **client navigation** (e.g. sidebar links **Transactions** / **Accounts**). To return to the dashboard from another route, use the **Home** link (not `page.goto("/dashboard")`).

**E2E and the API:** Create/delete transaction specs call the real backend (`/api/v1/transactions/...`). For them to pass you need the API running (e.g. local FastAPI), `DEBUG_AUTH_ENABLED=true` where applicable, and a reachable `NEXT_PUBLIC_API_URL` (or host) from the browser. **`analytics.spec.ts`** (price lookup) and **`profile.spec.ts`** (delete all data) stub selected API routes so they pass without mutating real data or depending on live price quotes. **`fire.spec.ts`** stubs `GET/PUT /api/v1/fire/profile` and `GET /api/v1/fire/projection` with JSON fixtures (reachable, unreachable, beyond_horizon) so FIRE flows pass without a running API.

**FIRE E2E navigation:** After debug login, open `/fire` via the header link **FIRE Calc** (client navigation), not `page.goto("/fire")`, so the debug session is preserved.

**Auth UI copy:** Login uses **Continue with Google** (when Firebase is configured). Success toasts for new transactions use **Transaction added** (not “created”).

## Tech Stack

- **Next.js 15** — App Router (not Pages Router)
- **TypeScript 5**
- **Tailwind CSS** — `darkMode: "class"` strategy
- **shadcn/ui** — pre-built components in `src/components/ui/`
- **TanStack React Query v5** — all server state
- **TanStack Table v8** — transactions table (sortable, filterable, paginated)
- **React Hook Form + Zod** — form validation
- **Recharts v2** — charts (LineChart, AreaChart, PieChart)
- **Firebase Auth Web SDK v10** — Google Sign-In popup
- **@sentry/nextjs** — production error monitoring; `tracesSampleRate: 0.1`
- **date-fns** — date formatting

## Architecture

### Authentication Flow

1. Firebase Auth (Google Sign-In popup) on client — initialized in `src/lib/firebase.ts`
2. Client retrieves Firebase JWT via `AuthContext.getToken()` (`src/contexts/auth-context.tsx`)
3. All API calls include `Authorization: Bearer <token>` header
4. On 401: force-refresh Firebase token and retry once; on second 401 sign out and redirect to `/login`

**Debug bypass:** Three parties must agree on the token — API (`.env`: `DEBUG_AUTH_ENABLED=true`), iOS (`AuthTokenProvider.isDebugSession`), and web (`src/lib/auth-debug.ts`). The web token is `"vaulttracker-debug-user"`, which maps to `firebase_id: "debug-user"` in the backend.

- `DEBUG_AUTH_AVAILABLE` and `DEBUG_AUTH_TOKEN` in `src/lib/auth-debug.ts` use `NODE_ENV === "development"` inlined at build time — the token string is not present in production bundles.
- `signInDebug` in `AuthContext` is `undefined` in production; the debug button in `login/page.tsx` is only rendered when `signInDebug` is defined.

### State Management

- **Server state:** React Query (`useQuery`/`useMutation`) — hooks in `src/lib/queries/`
- **Client state:** React Context — `AuthContext` (Firebase user + token, `src/contexts/auth-context.tsx`) and theme (dark/light, persisted to `localStorage`)

### Key Files

| File                                               | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/lib/logger.ts`                                | Logging facade — `info` dev-only (console); `warn`/`error` use console in dev and **Sentry** in production (`captureMessage` with `level: warning` for `warn`; `captureException` with `error ?? new Error(message)` and `{ extra }` for `error`, matching the logging design plan). Optional 4th arg `LoggerErrorSentryScope` (`tags` / `contexts`) wraps `captureException` in `Sentry.withScope` (used by route error fallback). Do not log PII. Repeat `captureException` on the **same error object** is ignored by the SDK (`__sentry_captured__`). |
| `instrumentation-client.ts`                        | Sentry client `Sentry.init` + `onRouterTransitionStart` (`@sentry/nextjs` v10; replaces legacy `sentry.client.config.ts`)                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `src/instrumentation.ts`                           | Next.js hook: loads `sentry.server.config` / `sentry.edge.config`; exports `onRequestError`                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `sentry.server.config.ts`                          | Node server Sentry init                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `sentry.edge.config.ts`                            | Edge runtime Sentry init                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `next.config.ts`                                   | Wrapped with `withSentryConfig` (optional `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` for source maps in CI)                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `src/lib/api-client.ts`                            | `ApiClient` class — wraps `fetch`, injects JWT, 401 retry; logs network `fetch` failures and `getToken` failures                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `src/lib/firebase.ts`                              | Firebase app initialization (client-only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `src/lib/auth-debug.ts`                            | Build-time debug auth constants (`DEBUG_AUTH_AVAILABLE`, `DEBUG_AUTH_TOKEN`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `src/types/api.ts`                                 | TypeScript mirrors of all backend Pydantic schemas (includes **FIRE** profile + `FireProjectionResponse` shapes)                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `src/lib/fire/fire-input-schema.ts`                | Zod `fireInputSchema` for FIRE profile PUT / form (matches API validation); tests in `src/lib/__tests__/fire-input-schema.test.ts`                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `src/contexts/auth-context.tsx`                    | `AuthProvider` + `useAuth()` hook; logs sign-in success (`uid` for tracing), failure, sign-out, forced token refresh (`warn` only when a `currentUser` exists), and `getIdToken` failures                                                                                                                                                                                                                                                                                                                                                                 |
| `src/contexts/api-client-context.tsx`              | `ApiClientProvider` + `useApiClient()` hook; reads base URL from env                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `src/components/route-error-fallback.tsx`          | Shared client UI for App Router error boundaries — `logger.error` with optional Sentry scope (tag `route_error_scope`) via logger’s 4th argument; WeakSet dedupes Strict Mode double effects; digest only when present                                                                                                                                                                                                                                                                                                                                    |
| `src/app/error.tsx`                                | Root error boundary (client); does not catch errors in the root layout (see `global-error.tsx`)                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `src/app/global-error.tsx`                         | Root layout render errors — required `<html>` / `<body>`, same fallback UI as segment boundaries                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `src/app/(authenticated)/error.tsx`                | Authenticated segment error boundary (client)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `src/lib/queries/`                                 | One file per resource: `use-dashboard.ts`, `use-fire.ts`, `use-accounts.ts`, `use-transactions.ts`, `use-assets.ts`, `use-networth.ts`, `use-analytics.ts`, `use-prices.ts`, `use-user.ts`                                                                                                                                                                                                                                                                                                                                                                |
| `src/components/dashboard/asset-detail-dialog.tsx` | Read-only modal: per-holding metrics and recent transactions (client filter on cached `useTransactions`); opened from `holdings-grid.tsx` and analytics category cards. **Cash** hides Quantity, Avg Cost / Unit, Unrealized P&L, and **Cost Basis** (current value is the meaningful figure). **Real estate** hides Quantity, Avg Cost / Unit, and Unrealized P&L but **still shows Cost Basis**. Recent transactions table lists at most five rows, newest first.                                                                                       |

### API Client Pattern

`ApiClient` is at `src/lib/api-client.ts`. Base URL is read as:

```typescript
process.env.NEXT_PUBLIC_API_URL ?? process.env.NEXT_PUBLIC_API_HOST ?? "http://localhost:8000";
```

Both env var names work; `NEXT_PUBLIC_API_URL` takes precedence.

### Route Structure

All authenticated routes live under `src/app/(authenticated)/` with an auth-guard layout (`layout.tsx`). When `user` is null after auth resolution, the layout renders `LoginGateRedirect` (uses `useLayoutEffect` + `router.replace`) instead of children. Client render errors in that segment are caught by `(authenticated)/error.tsx`; the root `app/error.tsx` covers child routes under the root layout. Errors in **`root/layout.tsx` itself** use `app/global-error.tsx` (Next.js replaces the root layout when it activates).

Unauthenticated routes: `/login` and `/` (redirects based on auth state).

| Route           | Purpose                                                                                                                     |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `/dashboard`    | Net worth chart, category bar, holdings grid (asset row opens read-only asset detail modal), price refresh                  |
| `/analytics`    | Bento grid: portfolio hero, category holding cards (opens asset detail), net worth chart, performance summary, price lookup |
| `/fire`         | FIRE calculator (inputs + projection UI — expand in later slices)                                                           |
| `/transactions` | Sortable table, add/edit/delete, CSV export                                                                                 |
| `/accounts`     | Account CRUD                                                                                                                |
| `/profile`      | User info, sign out, theme toggle, delete all data                                                                          |

### React Query Hook Pattern

```typescript
// src/lib/queries/use-dashboard.ts
export function useDashboard() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
  });
}
```

**Mutations must invalidate:** `["dashboard"]`, `["transactions"]`, `["networth"]`, `["analytics"]`, `["assets"]`

Delete mutations should also invalidate their own resource key (e.g. `["accounts"]`).

## API Contract (Breaking Changes)

These values are shared with the API and iOS — renaming anything here is a **breaking change**:

```typescript
type Category = "crypto" | "stocks" | "cash" | "realEstate" | "retirement";
type AccountType = "cryptoExchange" | "brokerage" | "bank" | "retirement" | "other";
type TransactionType = "buy" | "sell";
```

Defined in `src/types/api.ts`. Mirror of backend schemas in `VaultTrackerAPI/app/schemas/`.

### Category-Dependent Form Logic

- **Cash & Real Estate:** Hide `symbol` and `price_per_unit`; label quantity as "Amount ($)"; hardcode `price_per_unit = 1.0`
- **Crypto, Stocks, Retirement:** Show `symbol` (required), `quantity`, `price_per_unit`

### Transaction modal (Meridian reference)

Add/edit transaction UI lives in `src/components/transactions/transaction-form.tsx`. It follows the visual language of `Documentation/References/networth-tracker.html` (dark surfaces, Instrument Serif title, uppercase micro-labels, 2-column grid, lime primary actions, heavy modal shadow). `globals.css` dark theme variables are aligned with that reference.

**Dialog primitives:** `src/components/ui/dialog.tsx` `DialogContent` accepts optional **`overlayClassName`** (e.g. darker scrim + `backdrop-blur-md`) and **`closeButtonClassName`** (e.g. `top-6 right-6` when using large modal padding). Other dialogs keep defaults unless they pass these props.

**API values vs. display:** `TransactionType` remains `"buy" | "sell"` for payloads. The Type `<Select>` shows **Buy** / **Sell** via `TRANSACTION_TYPE_LABELS`, matching how Category uses `CATEGORY_LABELS`—do not render the raw enum string in the trigger.

## Environment

Copy `.env.local.example` → `.env.local`:

```
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
NEXT_PUBLIC_SENTRY_DSN=   # optional; from Sentry project settings
```

`NEXT_PUBLIC_API_HOST` is also accepted as a fallback for the API base URL.

**Sentry (optional):** Set `NEXT_PUBLIC_SENTRY_DSN` for production/staging. For readable stack traces in Sentry, configure `SENTRY_ORG`, `SENTRY_PROJECT`, and `SENTRY_AUTH_TOKEN` in CI (never commit the token). Local builds use `silent: true` in `withSentryConfig` to reduce noise.

Production API URL: `https://vaulttracker-api.onrender.com`. **Not yet deployed to Vercel** — when deploying, set the env vars in the Vercel dashboard and add the Vercel domain to the API's `ALLOWED_ORIGINS` in `VaultTrackerAPI/app/config.py` (or via the Render env var).
