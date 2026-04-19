# CLAUDE.md — VaultTrackerWeb

Next.js 15 App Router web client for VaultTracker.

> **Architecture, auth flow, state management, key files, API contract, testing notes, security headers, Sentry:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Status

All seven implementation phases are **complete**. Not yet deployed to Vercel — see `Documentation/Web App Spec.md` Phase 7 (items 7.3–7.9) for open checklist.

## Commands

```bash
npm run dev           # Dev server at localhost:3000
npm run build         # Production build
npm run lint          # ESLint
npx prettier --check .  # Format check (same as CI lint-web)
npx prettier --write .  # Apply Prettier project-wide
npm run test          # Vitest (unit + component), single run
npm run test:watch    # Vitest watch mode
npm run test:coverage # Vitest with coverage
npm run test:e2e      # Playwright (starts dev server automatically)
```

**CI (`lint-web`):** On pull requests, GitHub Actions runs `npm ci`, `prettier --check`, then ESLint with **JSON output piped to reviewdog** (check annotations + optional PR review comments). Fix blocking ESLint **errors** locally with `npm run lint` before pushing. Warnings (e.g. `no-console: warn`) do not fail ESLint's exit code unless you tighten rules.

## Tech Stack

- **Next.js 15** — App Router
- **TypeScript 5**
- **Tailwind CSS** — `darkMode: "class"`
- **shadcn/ui** — `src/components/ui/`
- **TanStack React Query v5** — server state
- **TanStack Table v8** — transactions table
- **React Hook Form + Zod** — form validation
- **Recharts v2** — charts
- **Firebase Auth Web SDK v10** — Google Sign-In
- **@sentry/nextjs** — production error monitoring
- **date-fns** — date formatting

## Route Structure

| Route           | Purpose                                                                                                                     |
| --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `/dashboard`    | Net worth chart, category bar, holdings grid (asset row opens read-only asset detail modal), price refresh                  |
| `/analytics`    | Bento grid: portfolio hero, category holding cards (opens asset detail), net worth chart, performance summary, price lookup |
| `/fire`         | FIRE calculator (inputs + projection UI)                                                                                    |
| `/transactions` | Sortable table, add/edit/delete, CSV export                                                                                 |
| `/accounts`     | Account CRUD                                                                                                                |
| `/profile`      | User info, **Household** card (create / join / invite / leave), sign out, theme toggle, delete all data                     |

Unauthenticated: `/login` and `/` (redirects based on auth state).

**Debug bypass:** Three parties must agree on the token — API (`.env`: `DEBUG_AUTH_ENABLED=true`), iOS (`AuthTokenProvider.isDebugSession`), and web (`src/lib/auth-debug.ts`). The web token is `"vaulttracker-debug-user"`, which maps to `firebase_id: "debug-user"` in the backend.

- `DEBUG_AUTH_AVAILABLE` and `DEBUG_AUTH_TOKEN` in `src/lib/auth-debug.ts` use `NODE_ENV === "development"` inlined at build time — the token string is not present in production bundles.
- `signInDebug` in `AuthContext` is `undefined` in production; the debug button in `login/page.tsx` is only rendered when `signInDebug` is defined.

### State Management

- **Server state:** React Query (`useQuery`/`useMutation`) — hooks in `src/lib/queries/`
- **Client state:** React Context — `AuthContext` (Firebase user + token, `src/contexts/auth-context.tsx`) and theme (dark/light, persisted to `localStorage`)

**Household (multi-account, API v1):** Shared households (`useHousehold`, profile card, dashboard/analytics toggles, household net worth history, `useHouseholdFireProfile` / `useUpdateHouseholdFire` on `/fire`). Backend contract: [`Documentation/Plans/2026-04-18-multi-account-support.md`](../Documentation/Plans/2026-04-18-multi-account-support.md); system design [`Documentation/VaultTracker System Design.md`](../Documentation/VaultTracker%20System%20Design.md).

### Key Files

| File                                                        | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/lib/logger.ts`                                         | Logging facade — `info` dev-only (console); `warn`/`error` use console in dev and **Sentry** in production (`captureMessage` with `level: warning` for `warn`; `captureException` with `error ?? new Error(message)` and `{ extra }` for `error`, matching the logging design plan). Optional 4th arg `LoggerErrorSentryScope` (`tags` / `contexts`) wraps `captureException` in `Sentry.withScope` (used by route error fallback). Do not log PII. Repeat `captureException` on the **same error object** is ignored by the SDK (`__sentry_captured__`). |
| `instrumentation-client.ts`                                 | Sentry client `Sentry.init` + `onRouterTransitionStart` (`@sentry/nextjs` v10; replaces legacy `sentry.client.config.ts`)                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `src/instrumentation.ts`                                    | Next.js hook: loads `sentry.server.config` / `sentry.edge.config`; exports `onRequestError`                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `sentry.server.config.ts`                                   | Node server Sentry init                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `sentry.edge.config.ts`                                     | Edge runtime Sentry init                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `next.config.ts`                                            | Wrapped with `withSentryConfig` (optional `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` for source maps in CI)                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `src/lib/api-client.ts`                                     | `ApiClient` — `fetch` + JWT, 401 retry; `getToken` failures (initial or after 401) invoke `onUnauthorized` then rethrow; logs network and token errors                                                                                                                                                                                                                                                                                                                                                                                                    |
| `src/lib/firebase.ts`                                       | Firebase app initialization (client-only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `src/lib/auth-debug.ts`                                     | Build-time debug auth constants (`DEBUG_AUTH_AVAILABLE`, `DEBUG_AUTH_TOKEN`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `src/types/api.ts`                                          | TypeScript mirrors of all backend Pydantic schemas (includes **FIRE** profile + `FireProjectionResponse` shapes)                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `src/lib/fire/fire-input-schema.ts`                         | Zod `fireInputSchema` for FIRE profile PUT / form (matches API validation); tests in `src/lib/__tests__/fire-input-schema.test.ts`                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `src/contexts/auth-context.tsx`                             | `AuthProvider` + `useAuth()` hook; logs sign-in success (`uid` for tracing), failure, sign-out, forced token refresh (`warn` only when a `currentUser` exists), and `getIdToken` failures                                                                                                                                                                                                                                                                                                                                                                 |
| `src/contexts/api-client-context.tsx`                       | `ApiClientProvider` + `useApiClient()` hook; base URL from env; clears React Query cache when `user` is `null` and on persistent 401 (`onUnauthorized`)                                                                                                                                                                                                                                                                                                                                                                                                   |
| `src/components/route-error-fallback.tsx`                   | Shared client UI for App Router error boundaries — `logger.error` + Sentry scope (`route_error_scope`); `ApiError` 401 or `Not signed in` shows **Return to login** + **Try again**; otherwise **Try again** only                                                                                                                                                                                                                                                                                                                                         |
| `src/app/error.tsx`                                         | Root error boundary (client); does not catch errors in the root layout (see `global-error.tsx`)                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `src/app/global-error.tsx`                                  | Root layout render errors — required `<html>` / `<body>`, same fallback UI as segment boundaries                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `src/app/(authenticated)/error.tsx`                         | Authenticated segment error boundary (client)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `src/lib/queries/`                                          | One file per resource: `use-dashboard.ts` (incl. `useDashboardHousehold`), `use-household.ts` (membership + create/join/leave/invite), `use-fire.ts` (incl. `useHouseholdFireProfile` / `useUpdateHouseholdFire`), `use-networth.ts` (incl. `useNetWorthHistoryHousehold`), `use-accounts.ts`, `use-transactions.ts`, `use-assets.ts`, `use-analytics.ts`, `use-prices.ts`, `use-user.ts`                                                                                                                                                                 |
| `src/components/dashboard/member-section.tsx`               | `HouseholdMemberSections` — collapsible card per member with allocation + `HoldingsGrid`. Tests in `src/components/dashboard/__tests__/member-section.test.tsx`.                                                                                                                                                                                                                                                                                                                                                                                          |
| `src/app/(authenticated)/dashboard/__tests__/page.test.tsx` | Household scope toggle + hero label when `useHousehold` returns data (mocked queries).                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `src/components/profile/household-settings-card.tsx`        | Profile **Household** section — `useHousehold` + create/join/invite/leave; invite preview with copy + expiry; confirm leave in `AlertDialog`. Tests in `src/components/profile/__tests__/household-settings-card.test.tsx`.                                                                                                                                                                                                                                                                                                                               |
| `src/components/dashboard/asset-detail-dialog.tsx`          | Read-only modal: per-holding metrics and recent transactions (client filter on cached `useTransactions`); opened from `holdings-grid.tsx` and analytics category cards. **Cash** hides Quantity, Avg Cost / Unit, Unrealized P&L, and **Cost Basis** (current value is the meaningful figure). **Real estate** hides Quantity, Avg Cost / Unit, and Unrealized P&L but **still shows Cost Basis**. Recent transactions table lists at most five rows, newest first.                                                                                       |

### API Client Pattern

`ApiClient` is at `src/lib/api-client.ts`. Base URL is read as:

```typescript
process.env.NEXT_PUBLIC_API_URL ?? process.env.NEXT_PUBLIC_API_HOST ?? "http://localhost:8000";
```

Both env var names work; `NEXT_PUBLIC_API_URL` takes precedence.

### Route Structure

All authenticated routes live under `src/app/(authenticated)/` with an auth-guard layout (`layout.tsx`). When `user` is null after auth resolution, the layout renders `LoginGateRedirect` (uses `useLayoutEffect` + `router.replace`) instead of children. Client render errors in that segment are caught by `(authenticated)/error.tsx`; the root `app/error.tsx` covers child routes under the root layout. Errors in **`root/layout.tsx` itself** use `app/global-error.tsx` (Next.js replaces the root layout when it activates).

Unauthenticated routes: `/login` and `/` (redirects based on auth state).

| Route           | Purpose                                                                                                                                                                                                                                                                                            |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/dashboard`    | Net worth chart, category allocation, holdings; **in a household:** **Household / Just me** toggle (defaults to household), merged hero + allocation + chart from household APIs, per-member collapsible sections (`HouseholdMemberSections`); **Just me** uses personal dashboard + holdings grid |
| `/analytics`    | Bento grid (personal holdings), hero + **net worth trend** use **Household / Just me** when in a household (defaults to household totals + `useNetWorthHistoryHousehold`); performance + category cards stay personal                                                                              |
| `/fire`         | FIRE calculator: **household** mode edits shared profile (`useHouseholdFireProfile`); charts hidden until API supports household projection; **personal** mode unchanged (`useFireProfile` + `useFireProjection`)                                                                                  |
| `/transactions` | Sortable table, add/edit/delete, CSV export                                                                                                                                                                                                                                                        |
| `/accounts`     | Account CRUD                                                                                                                                                                                                                                                                                       |
| `/profile`      | User info, **Household** card (create / join / invite / leave), sign out, theme toggle, delete all data                                                                                                                                                                                            |

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

Defined in `src/types/api.ts`. Mirror of backend schemas in `VaultTrackerAPI/app/schemas/`. Household types include `HouseholdResponse`, `HouseholdDashboardResponse`, `HouseholdInviteCodeResponse`, and `HouseholdFireProfile` (alias of `FireProfileResponse`).

**Household query keys:** `["household"]` for `GET /households/me` (404 → `null`); `["dashboard", "household"]` for merged dashboard; `["networth", "household", period]` for household history; `["fire", "household", "profile"]` for shared FIRE inputs. Create/join/leave invalidate `household`, `dashboard`, `networth`, `fire`, and `analytics`; invite-code generation only invalidates `household`.

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
NEXT_PUBLIC_SENTRY_DSN=   # optional
```

`NEXT_PUBLIC_API_HOST` also accepted as fallback for API base URL.

When deploying to Vercel: set env vars in Vercel dashboard and add the Vercel domain to `ALLOWED_ORIGINS` in `VaultTrackerAPI/app/config.py`.

## Testing

**Docs:** `Documentation/Testing Plan.md` describes the pyramid (Vitest for pure logic/schemas/components, Playwright for full flows), setup assumptions, and file map.

**Vitest** (`vitest.config.ts`, `vitest.setup.ts`): runs in `jsdom`; path alias `@/` matches the app. The `e2e/` folder is **excluded** so Playwright specs are not picked up as Vitest tests.

**Where tests live**

| Area                 | Location                                                                                                                        |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Unit                 | `src/lib/__tests__/*.test.ts`                                                                                                   |
| React Query hooks    | `src/lib/queries/__tests__/*.test.tsx`                                                                                          |
| Components / context | `src/components/__tests__/`, `src/components/layout/__tests__/`, `src/components/profile/__tests__/`, `src/contexts/__tests__/` |
| App routes           | `src/app/(authenticated)/**/__tests__/` (e.g. `fire/page.test.tsx`)                                                             |
| E2E                  | `e2e/*.spec.ts` (e.g. `auth`, `dashboard`, `analytics`, `transactions`, `accounts`, `profile`, `fire`)                          |

**Transaction form dialog:** `TransactionFormDialog` awaits `onSubmit` (sync or `Promise`). On success it calls `onOpenChange(false)`; if `onSubmit` rejects, the dialog stays open. Authenticated pages should use `mutateAsync` in `onSubmit`, show toasts in a `try`/`catch`, and `throw` after `toast.error` so the dialog does not close on failure.

**Playwright** (`playwright.config.ts`): `testDir` is `./e2e`, `baseURL` `http://localhost:3000`, `webServer` runs `npm run dev` unless `CI` is set (see `reuseExistingServer`). Install browsers once: `npx playwright install --with-deps chromium`.

**E2E and debug auth:** The debug session is **only in React memory** (not persisted). After debug sign-in on `/login`, navigating with `page.goto("/transactions")` performs a **full load** and clears that session, so guarded routes bounce to `/login`. E2E flows that need `/transactions` or `/accounts` should use **client navigation** (e.g. sidebar links **Transactions** / **Accounts**). To return to the dashboard from another route, use the **Home** link (not `page.goto("/dashboard")`).

**E2E and the API:** Create/delete transaction specs call the real backend (`/api/v1/transactions/...`). For them to pass you need the API running (e.g. local FastAPI), `DEBUG_AUTH_ENABLED=true` where applicable, and a reachable `NEXT_PUBLIC_API_URL` (or host) from the browser. **`analytics.spec.ts`** (price lookup) and **`profile.spec.ts`** (delete all data) stub selected API routes so they pass without mutating real data or depending on live price quotes. **`fire.spec.ts`** stubs `GET/PUT /api/v1/fire/profile` and `GET /api/v1/fire/projection` with JSON fixtures (reachable, unreachable, beyond_horizon) so FIRE flows pass without a running API.

**FIRE E2E navigation:** After debug login, open `/fire` via the header link **FIRE Calc** (client navigation), not `page.goto("/fire")`, so the debug session is preserved.

**Auth UI copy:** Login uses **Continue with Google** (when Firebase is configured). Success toasts for new transactions use **Transaction added** (not "created").
