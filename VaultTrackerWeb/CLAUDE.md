# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

VaultTrackerWeb is **fully implemented**. All seven phases from `Documentation/Web App Spec.md` are complete.

## Commands

```bash
npm run dev    # Dev server at localhost:3000
npm run build  # Production build
npm run lint   # ESLint
```

Tests are not yet configured.

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

| File | Purpose |
|---|---|
| `src/lib/api-client.ts` | `ApiClient` class — wraps `fetch`, injects JWT, 401 retry |
| `src/lib/firebase.ts` | Firebase app initialization (client-only) |
| `src/lib/auth-debug.ts` | Build-time debug auth constants (`DEBUG_AUTH_AVAILABLE`, `DEBUG_AUTH_TOKEN`) |
| `src/types/api.ts` | TypeScript mirrors of all backend Pydantic schemas |
| `src/contexts/auth-context.tsx` | `AuthProvider` + `useAuth()` hook |
| `src/contexts/api-client-context.tsx` | `ApiClientProvider` + `useApiClient()` hook; reads base URL from env |
| `src/lib/queries/` | One file per resource: `use-dashboard.ts`, `use-accounts.ts`, `use-transactions.ts`, `use-assets.ts`, `use-networth.ts`, `use-analytics.ts`, `use-prices.ts`, `use-user.ts` |

### API Client Pattern

`ApiClient` is at `src/lib/api-client.ts`. Base URL is read as:

```typescript
process.env.NEXT_PUBLIC_API_URL ?? process.env.NEXT_PUBLIC_API_HOST ?? "http://localhost:8000"
```

Both env var names work; `NEXT_PUBLIC_API_URL` takes precedence.

### Route Structure

All authenticated routes live under `src/app/(authenticated)/` with an auth-guard layout (`layout.tsx`). When `user` is null after auth resolution, the layout renders `LoginGateRedirect` (uses `useLayoutEffect` + `router.replace`) instead of children.

Unauthenticated routes: `/login` and `/` (redirects based on auth state).

| Route | Purpose |
|---|---|
| `/dashboard` | Net worth chart, category bar, holdings grid, price refresh |
| `/analytics` | Allocation donut, gain/loss performance |
| `/transactions` | Sortable table, add/edit/delete, CSV export |
| `/accounts` | Account CRUD |
| `/profile` | User info, sign out, theme toggle, delete all data |

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
type Category = "crypto" | "stocks" | "cash" | "realEstate" | "retirement"
type AccountType = "cryptoExchange" | "brokerage" | "bank" | "retirement" | "other"
type TransactionType = "buy" | "sell"
```

Defined in `src/types/api.ts`. Mirror of backend schemas in `VaultTrackerAPI/app/schemas/`.

### Category-Dependent Form Logic

- **Cash & Real Estate:** Hide `symbol` and `price_per_unit`; label quantity as "Amount ($)"; hardcode `price_per_unit = 1.0`
- **Crypto, Stocks, Retirement:** Show `symbol` (required), `quantity`, `price_per_unit`

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
```

`NEXT_PUBLIC_API_HOST` is also accepted as a fallback for the API base URL.

Production API URL: `https://vaulttracker-api.onrender.com`. Deployed to Vercel — set env vars in the Vercel dashboard and add the Vercel domain to the API's CORS allowlist.
