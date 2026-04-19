# VaultTrackerWeb — System Design

## Authentication Flow

1. Firebase Auth (Google Sign-In popup) on client — initialized in `src/lib/firebase.ts`
2. Client retrieves Firebase JWT via `AuthContext.getToken()` (`src/contexts/auth-context.tsx`)
3. All API calls include `Authorization: Bearer <token>` header
4. On 401: force-refresh Firebase token and retry once; on second 401 sign out and redirect to `/login`
5. If `getToken` throws, `ApiClient` calls the same `onUnauthorized` path so user is redirected to `/login`
6. `ApiClientProvider` calls `queryClient.clear()` when `AuthContext.user` is `null` and on persistent 401 — prevents cached data from previous account flashing after sign-in

**Debug bypass:** `DEBUG_AUTH_AVAILABLE` and `DEBUG_AUTH_TOKEN` in `src/lib/auth-debug.ts` use `NODE_ENV === "development"` inlined at build time — token string is not present in production bundles. `signInDebug` in `AuthContext` is `undefined` in production.

## State Management

- **Server state:** React Query (`useQuery`/`useMutation`) — hooks in `src/lib/queries/`
- **Client state:** React Context — `AuthContext` (Firebase user + token) and theme (dark/light, persisted to `localStorage`)

## Route Structure

All authenticated routes live under `src/app/(authenticated)/` with an auth-guard layout. When `user` is null after auth resolution, layout renders `LoginGateRedirect`. Root layout errors use `app/global-error.tsx`.

| Route | Purpose |
|-------|---------|
| `/dashboard` | Net worth chart, category bar, holdings grid, price refresh |
| `/analytics` | Portfolio hero, category cards, net worth chart, performance summary, price lookup |
| `/fire` | FIRE calculator (inputs + projection) |
| `/transactions` | Sortable table, add/edit/delete, CSV export |
| `/accounts` | Account CRUD |
| `/profile` | User info, sign out, theme toggle, delete all data |

## Key Files

| File | Purpose |
|------|---------|
| `src/lib/logger.ts` | Logging facade — `info` dev-only; `warn`/`error` → Sentry in production |
| `src/lib/api-client.ts` | `ApiClient` — `fetch` + JWT, 401 retry; `getToken` failures invoke `onUnauthorized` |
| `src/lib/firebase.ts` | Firebase app initialization (client-only) |
| `src/lib/auth-debug.ts` | Build-time debug auth constants |
| `src/types/api.ts` | TypeScript mirrors of all backend Pydantic schemas (including FIRE) |
| `src/lib/fire/fire-input-schema.ts` | Zod `fireInputSchema` for FIRE profile PUT/form |
| `src/contexts/auth-context.tsx` | `AuthProvider` + `useAuth()` hook |
| `src/contexts/api-client-context.tsx` | `ApiClientProvider` + `useApiClient()` hook; clears React Query cache on sign-out/401 |
| `src/components/route-error-fallback.tsx` | Shared error boundary UI — 401 shows "Return to login" + "Try again"; others show "Try again" |
| `src/lib/queries/` | One file per resource: `use-dashboard`, `use-fire`, `use-accounts`, `use-transactions`, etc. |
| `src/components/dashboard/asset-detail-dialog.tsx` | Read-only modal: per-holding metrics + recent transactions. Cash hides Qty/Avg Cost/P&L. Real estate hides Qty/Avg Cost/P&L but shows Cost Basis. Shows at most 5 recent transactions. |

## API Client Pattern

```typescript
// Base URL resolution (api-client-context.tsx)
process.env.NEXT_PUBLIC_API_URL ?? process.env.NEXT_PUBLIC_API_HOST ?? "http://localhost:8000"
```

## React Query Hook Pattern

```typescript
export function useDashboard() {
  const api = useApiClient();
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
  });
}
```

**Mutations must invalidate:** `["dashboard"]`, `["transactions"]`, `["networth"]`, `["analytics"]`, `["assets"]`. Delete mutations also invalidate their own resource key.

## API Contract

```typescript
type Category = "crypto" | "stocks" | "cash" | "realEstate" | "retirement";
type AccountType = "cryptoExchange" | "brokerage" | "bank" | "retirement" | "other";
type TransactionType = "buy" | "sell";
```

Defined in `src/types/api.ts`. Renaming is a breaking change across API, iOS, and Web.

### Category-Dependent Form Logic

- **Cash & Real Estate:** Hide `symbol` and `price_per_unit`; label quantity as "Amount ($)"; hardcode `price_per_unit = 1.0`
- **Crypto, Stocks, Retirement:** Show `symbol` (required), `quantity`, `price_per_unit`

## Transaction Form Dialog

`TransactionFormDialog` awaits `onSubmit`. On success calls `onOpenChange(false)`; if `onSubmit` rejects, dialog stays open. Authenticated pages should use `mutateAsync` in `onSubmit`, show toasts in `try`/`catch`, and `throw` after `toast.error` so dialog does not close on failure.

## Testing Notes

**E2E and debug auth:** Debug session is **only in React memory** — not persisted. After debug sign-in, `page.goto("/transactions")` clears the session. Use **client navigation** (sidebar links) instead of `page.goto` for guarded routes.

**FIRE E2E:** Open `/fire` via the header link **FIRE Calc** (client nav), not `page.goto("/fire")`.

**Auth UI copy:** Login uses **Continue with Google**. Success toasts for new transactions: **Transaction added**.

## Security Headers

`next.config.ts` defines `headers()` on the inner config — CSP plus standard browser hardening headers. **CSP note:** production `script-src` currently includes `'unsafe-inline'` because Next.js App Router relies on inline scripts; tightening to nonce-based CSP is documented as a known gap.

## Sentry

`instrumentation-client.ts` holds Sentry client init + `onRouterTransitionStart`. `src/instrumentation.ts` loads server/edge configs and exports `onRequestError`. `tracesSampleRate: 0.1`. Optional: set `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` in CI for source maps (never commit the token).
