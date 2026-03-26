# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

VaultTrackerWeb is **in early scaffolding phase** — only documentation and configuration exist. The primary reference is `Documentation/Web App Spec.md`, which contains the complete implementation plan (7 phases), exact component names, TypeScript types, API endpoint mappings, and React Query hook patterns.

## Commands

```bash
npm run dev    # Dev server at localhost:3000
npm run build  # Production build
npm run lint   # ESLint
```

Tests are not yet configured (Phase 7 of spec).

## Tech Stack

- **Next.js 15** — App Router (not Pages Router)
- **TypeScript 5**
- **Tailwind CSS** — `darkMode: "class"` strategy
- **shadcn/ui** — pre-built components
- **TanStack React Query v5** — all server state
- **TanStack Table v8** — transactions table (sortable, filterable, paginated)
- **React Hook Form + Zod** — form validation
- **Recharts v2** — charts (LineChart, AreaChart, PieChart)
- **Firebase Auth Web SDK v10** — Google Sign-In popup
- **date-fns** — date formatting

## Architecture

### Authentication Flow

1. Firebase Auth (Google Sign-In popup) on client
2. Client retrieves Firebase JWT (`idToken`)
3. All API calls include `Authorization: Bearer <token>` header
4. On 401: force-refresh Firebase token and retry once; on second 401 sign out

**Debug bypass:** Set `DEBUG_AUTH_ENABLED=true` in API `.env`. Pass token `"vaulttracker-debug-user"` — maps to stable `firebase_id: "debug-user"` in the backend.

### State Management

- **Server state:** React Query (`useQuery`/`useMutation`) — see `src/hooks/`
- **Client state:** React Context — `AuthContext` (Firebase user + token) and `ThemeContext` (dark/light, persisted to localStorage)

### API Client Pattern

Single `ApiClient` class (wraps `fetch`) at `src/lib/api.ts`:
- Injects JWT from `AuthContext` into every request
- 401 retry with token refresh before sign-out
- Reads base URL from `NEXT_PUBLIC_API_HOST`

### Route Structure

All authenticated routes live under `src/app/(authenticated)/` with an auth-guard layout that redirects to `/login` if no user. Unauthenticated routes: `/login` and `/` (redirects to `/dashboard` or `/login`).

| Route | Purpose |
|---|---|
| `/dashboard` | Net worth chart, category bar, holdings grid, price refresh |
| `/analytics` | Allocation donut, gain/loss performance |
| `/transactions` | Sortable table, add/edit/delete, CSV export |
| `/accounts` | Account CRUD |
| `/profile` | User info, sign out, theme toggle, delete all data |

### React Query Hook Pattern

```typescript
// src/hooks/useDashboard.ts
export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
  });
}

// Mutations must invalidate: ["dashboard"], ["transactions"], ["networth"], ["analytics"], ["assets"]
```

## API Contract (Breaking Changes)

These values are shared with the API and iOS — renaming anything here is a **breaking change**:

```typescript
type Category = "crypto" | "stocks" | "cash" | "realEstate" | "retirement"
type AccountType = "cryptoExchange" | "brokerage" | "bank" | "retirement" | "other"
type TransactionType = "buy" | "sell"
```

### Category-Dependent Form Logic

- **Cash & Real Estate:** Hide `symbol` and `price_per_unit`; label quantity as "Amount ($)"; hardcode `price_per_unit = 1.0`
- **Crypto, Stocks, Retirement:** Show `symbol` (required), `quantity`, `price_per_unit`

## Environment

Copy `.env.local.example` → `.env.local`:

```
NEXT_PUBLIC_API_HOST=http://localhost:8000
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
```

Production uses `NEXT_PUBLIC_API_HOST=https://vaulttracker-api.onrender.com`. Deployed to Vercel — set env vars in Vercel dashboard and add Vercel URL to API CORS allowlist.
