---
tags:
  - vaultTracker
  - webApp
title: Vault Tracker - Web App Spec
---

# VaultTracker Web App — Design Spec

> **Purpose:** AI-agent consumable spec for building the Next.js web application. This is a thin client — all business logic lives in the backend (see [Backend 2.0 Spec](Vault%20Tracker%20-%20Backend%202.0%20Spec.md)). Read the [Backend Context](Vault%20Tracker%20-%20Backend%20Context.md) for the current API surface.

---

## Context

The web app is a responsive dashboard for tracking personal net worth. It consumes the Backend 2.0 smart API, meaning the client has **zero business logic** — no asset resolution, no account resolution, no data joins, no computation. It renders what the API returns.

**Dependency:** Backend 2.0 is complete. All smart endpoints, enriched responses, caching, analytics, price service, and net worth history are live and ready to consume.

---

## Overview

### Product Goals

1. **Broader product** — richer analytics, transaction history, account management beyond iOS
2. **Portfolio piece** — polished, deployed, publicly accessible
3. **Shared identity** — same Firebase Auth project as iOS, same backend, same user data

### Pages

| Route | Page | Auth | Data Source |
|-------|------|------|-------------|
| `/` | Redirect | No | — |
| `/login` | Google Sign-In | No | Firebase Auth |
| `/dashboard` | Net worth, chart, categories, holdings, price lookup | Yes | `GET /dashboard` + `GET /networth/history` + `GET /prices/{symbol}` |
| `/analytics` | Allocation donut, trends, gain/loss | Yes | `GET /analytics` |
| `/transactions` | Sortable table + add/edit/delete | Yes | `GET /transactions` (enriched) + `POST /transactions/smart` + `PUT /transactions/{id}/smart` |
| `/accounts` | Account CRUD + linked assets | Yes | `GET /accounts` + CRUD |
| `/profile` | User info, sign out, theme, delete data | Yes | Firebase Auth + `DELETE /users/me/data` |

---

## Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 14+ (App Router) |
| Language | TypeScript 5.x |
| Styling | Tailwind CSS 3.x |
| Components | shadcn/ui |
| Server state | TanStack React Query 5.x |
| Charts | Recharts 2.x |
| Tables | TanStack Table 8.x |
| Forms | React Hook Form + Zod |
| Auth | Firebase Auth (Web SDK) 10.x |
| HTTP | Native fetch (wrapped) |
| Deployment | Vercel (free tier) |

### Directory Structure

```
VaultTrackerWeb/
├── src/
│   ├── app/
│   │   ├── layout.tsx              # Root layout: providers, fonts, metadata
│   │   ├── page.tsx                # / → redirect to /dashboard or /login
│   │   ├── login/page.tsx          # Google Sign-In
│   │   ├── (authenticated)/        # Route group with auth guard layout
│   │   │   ├── layout.tsx          # App shell: sidebar + bottom tabs
│   │   │   ├── dashboard/page.tsx
│   │   │   ├── analytics/page.tsx
│   │   │   ├── transactions/page.tsx
│   │   │   ├── accounts/page.tsx
│   │   │   └── profile/page.tsx
│   ├── components/
│   │   ├── ui/                     # shadcn/ui generated components
│   │   ├── layout/
│   │   │   ├── sidebar.tsx         # Desktop sidebar navigation
│   │   │   ├── mobile-nav.tsx      # Mobile bottom tab bar
│   │   │   └── app-shell.tsx       # Wraps sidebar + main content
│   │   ├── dashboard/
│   │   │   ├── net-worth-chart.tsx  # Recharts line + area chart
│   │   │   ├── category-bar.tsx     # Proportional color bar
│   │   │   ├── holdings-grid.tsx    # Expandable category sections
│   │   │   └── stat-card.tsx        # Single stat display card
│   │   ├── analytics/
│   │   │   ├── allocation-donut.tsx # Recharts PieChart
│   │   │   ├── category-trends.tsx  # Line charts per category
│   │   │   └── performance-cards.tsx# Gain/loss summary
│   │   ├── transactions/
│   │   │   ├── transaction-table.tsx# TanStack Table
│   │   │   ├── transaction-form.tsx # Add/edit form (modal)
│   │   │   └── csv-export.tsx       # Export button
│   │   └── accounts/
│   │       ├── account-list.tsx     # Card grid
│   │       └── account-form.tsx     # Add/edit form (modal)
│   ├── lib/
│   │   ├── api-client.ts           # Fetch wrapper with JWT + 401 retry
│   │   ├── firebase.ts             # Firebase app init + auth exports
│   │   ├── queries/                # React Query hooks
│   │   │   ├── use-dashboard.ts
│   │   │   ├── use-transactions.ts
│   │   │   ├── use-accounts.ts
│   │   │   ├── use-assets.ts
│   │   │   ├── use-analytics.ts
│   │   │   ├── use-prices.ts
│   │   │   ├── use-networth.ts
│   │   │   └── use-user.ts
│   │   └── utils.ts                # Currency formatting, date helpers
│   ├── contexts/
│   │   ├── auth-context.tsx        # Firebase auth state + token management
│   │   └── theme-context.tsx       # Dark/light mode
│   └── types/
│       └── api.ts                  # TypeScript types matching backend schemas
├── public/
├── tailwind.config.ts
├── next.config.ts
├── package.json
└── tsconfig.json
```

### Auth Guard Pattern

Using a Next.js route group `(authenticated)` with a shared layout that checks auth:

```typescript
// src/app/(authenticated)/layout.tsx
"use client";
export default function AuthenticatedLayout({ children }) {
  const { user, loading } = useAuth();

  if (loading) return <LoadingSkeleton />;
  if (!user) {
    redirect("/login");
    return null;
  }

  return <AppShell>{children}</AppShell>;
}
```

---

## Technical Spec

### API Client (`lib/api-client.ts`)

Single class wrapping `fetch` with auth headers and 401 retry. Mirrors iOS `APIService` pattern.

```typescript
class ApiClient {
  constructor(
    private baseUrl: string,
    private getToken: () => Promise<string>,
    private onUnauthorized: () => void
  ) {}

  async request<T>(endpoint: string, options?: RequestInit): Promise<T> {
    const token = await this.getToken();
    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
        ...options?.headers,
      },
    });

    if (response.status === 401) {
      // Force refresh token (Firebase) and retry once
      const freshToken = await this.getToken(/* forceRefresh */ true);
      const retry = await fetch(`${this.baseUrl}${endpoint}`, {
        ...options,
        headers: {
          "Authorization": `Bearer ${freshToken}`,
          "Content-Type": "application/json",
          ...options?.headers,
        },
      });
      if (retry.status === 401) {
        this.onUnauthorized(); // sign out
        throw new ApiError("unauthorized", 401);
      }
      if (!retry.ok) throw await ApiError.fromResponse(retry);
      return retry.json();
    }

    if (!response.ok) throw await ApiError.fromResponse(response);
    return response.json();
  }

  get<T>(endpoint: string) { return this.request<T>(endpoint); }

  post<T>(endpoint: string, body: unknown) {
    return this.request<T>(endpoint, {
      method: "POST",
      body: JSON.stringify(body),
    });
  }

  put<T>(endpoint: string, body: unknown) {
    return this.request<T>(endpoint, {
      method: "PUT",
      body: JSON.stringify(body),
    });
  }

  delete(endpoint: string) {
    return this.request(endpoint, { method: "DELETE" });
  }
}
```

### TypeScript Types (`types/api.ts`)

Match backend Pydantic schemas exactly:

```typescript
// === Shared Literals ===

export type Category = "crypto" | "stocks" | "cash" | "realEstate" | "retirement";
export type AccountType = "cryptoExchange" | "brokerage" | "bank" | "retirement" | "other";
export type TransactionType = "buy" | "sell";
export type NetWorthPeriod = "daily" | "weekly" | "monthly" | "all";

// === Responses ===

export interface DashboardResponse {
  totalNetWorth: number;
  categoryTotals: Record<string, number>;
  groupedHoldings: Record<string, HoldingItem[]>;
}

export interface HoldingItem {
  id: string;
  name: string;
  symbol: string | null;
  quantity: number;
  current_value: number;
}

export interface EnrichedTransaction {
  id: string;
  user_id: string;
  asset_id: string;
  account_id: string;
  transaction_type: TransactionType;
  quantity: number;
  price_per_unit: number;
  total_value: number;
  date: string;
  asset: { id: string; name: string; symbol: string | null; category: Category };
  account: { id: string; name: string; account_type: AccountType };
}

export interface AccountResponse {
  id: string;
  name: string;
  account_type: AccountType;
  created_at: string;
}

export interface AssetResponse {
  id: string;
  user_id: string;
  name: string;
  symbol: string | null;
  category: Category;
  quantity: number;
  current_value: number;
  last_updated: string;
}

export interface AnalyticsResponse {
  allocation: Record<string, { value: number; percentage: number }>;
  performance: {
    totalGainLoss: number;
    totalGainLossPercent: number;
    costBasis: number;
    currentValue: number;
  };
}

export interface NetWorthHistoryResponse {
  snapshots: Array<{ date: string; value: number }>;
}

export interface PriceRefreshResponse {
  updated: Array<{ asset_id: string; symbol: string; old_value: number; new_value: number; price: number }>;
  skipped: string[];
  errors: Array<{ symbol: string; error: string }>;
}

export interface SinglePriceResponse {
  symbol: string;
  price: number;
  source: string;
}

export interface UserDataDeleteResponse {
  message: string;
}

// === Requests ===

export interface SmartTransactionCreate {
  transaction_type: TransactionType;
  category: Category;
  asset_name: string;
  symbol?: string;
  quantity: number;
  price_per_unit: number;
  account_name: string;
  account_type: AccountType;
  date?: string;
}

export interface AccountCreate {
  name: string;
  account_type: AccountType;
}

export interface AccountUpdate {
  name?: string;
  account_type?: AccountType;
}
```

### React Query Hooks (`lib/queries/`)

Each domain gets its own file. The pattern is consistent:

```typescript
// --- use-dashboard.ts ---
export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: () => api.get<DashboardResponse>("/api/v1/dashboard"),
  });
}

// --- use-transactions.ts ---
export function useTransactions() {
  return useQuery({
    queryKey: ["transactions"],
    queryFn: () => api.get<EnrichedTransaction[]>("/api/v1/transactions"),
  });
}

export function useCreateTransaction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: SmartTransactionCreate) =>
      api.post("/api/v1/transactions/smart", data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}

export function useUpdateTransaction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: SmartTransactionCreate }) =>
      api.put(`/api/v1/transactions/${id}/smart`, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}

export function useDeleteTransaction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/transactions/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["networth"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}

// --- use-accounts.ts ---
export function useAccounts() {
  return useQuery({
    queryKey: ["accounts"],
    queryFn: () => api.get<AccountResponse[]>("/api/v1/accounts"),
  });
}

export function useCreateAccount() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: AccountCreate) => api.post("/api/v1/accounts", data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

export function useUpdateAccount() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: AccountUpdate }) =>
      api.put(`/api/v1/accounts/${id}`, data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

export function useDeleteAccount() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/accounts/${id}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["accounts"] });
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["transactions"] });
      qc.invalidateQueries({ queryKey: ["assets"] });
    },
  });
}

// --- use-assets.ts ---
export function useAssets(category?: Category) {
  return useQuery({
    queryKey: ["assets", category],
    queryFn: () => {
      const params = category ? `?category=${category}` : "";
      return api.get<AssetResponse[]>(`/api/v1/assets${params}`);
    },
  });
}

// --- use-analytics.ts ---
export function useAnalytics() {
  return useQuery({
    queryKey: ["analytics"],
    queryFn: () => api.get<AnalyticsResponse>("/api/v1/analytics"),
  });
}

// --- use-networth.ts ---
export function useNetWorthHistory(period: NetWorthPeriod = "daily") {
  return useQuery({
    queryKey: ["networth", period],
    queryFn: () => api.get<NetWorthHistoryResponse>(`/api/v1/networth/history?period=${period}`),
  });
}

// --- use-prices.ts ---
export function useRefreshPrices() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => api.post<PriceRefreshResponse>("/api/v1/prices/refresh", {}),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["dashboard"] });
      qc.invalidateQueries({ queryKey: ["analytics"] });
    },
  });
}

export function usePriceLookup(symbol: string) {
  return useQuery({
    queryKey: ["price", symbol],
    queryFn: () => api.get<SinglePriceResponse>(`/api/v1/prices/${symbol}`),
    enabled: !!symbol,
  });
}

// --- use-user.ts ---
export function useDeleteUserData() {
  return useMutation({
    mutationFn: () => api.delete("/api/v1/users/me/data"),
    // On success: sign out + redirect to /login (handled in component)
  });
}
```

### Add / edit transaction form

Create calls `POST /api/v1/transactions/smart`. Edit sends the same payload shape to `PUT /api/v1/transactions/{id}/smart` (server reverses the old row on its asset, then re-resolves account + asset like create). **No resolution logic lives in the client.**

Fields:
- Transaction type: buy / sell (radio group)
- Category: crypto / stocks / cash / realEstate / retirement (select)
- Asset name: text input (e.g., "Bitcoin", "AAPL", "Savings")
- Symbol: text input — shown only for crypto, stocks, retirement. Hidden for cash, realEstate.
- Quantity: number input
  - For cash/realEstate: labeled "Amount ($)" and `price_per_unit` is hardcoded to `1.0`
  - For others: labeled "Quantity"
- Price per unit: number input — hidden for cash/realEstate
- Account name: text input (e.g., "Coinbase", "Fidelity")
- Account type: select — filtered to valid types for selected category
- Date: date picker (defaults to today)

Validation via Zod:
```typescript
const transactionSchema = z.object({
  transaction_type: z.enum(["buy", "sell"]),
  category: z.enum(["crypto", "stocks", "cash", "realEstate", "retirement"]),
  asset_name: z.string().min(1),
  symbol: z.string().optional(),
  quantity: z.number().positive(),
  price_per_unit: z.number().positive(),
  account_name: z.string().min(1),
  account_type: z.enum(["cryptoExchange", "brokerage", "bank", "retirement", "other"]),
  date: z.string().optional(),
});
```

### Transaction Table

TanStack Table with these columns:

| Column | Source | Sortable | Filterable |
|--------|--------|----------|------------|
| Date | `date` | Yes | No |
| Type | `transaction_type` | No | Yes (buy/sell) |
| Asset | `asset.name` | Yes | Yes (search) |
| Symbol | `asset.symbol` | No | No |
| Category | `asset.category` | No | Yes (select) |
| Account | `account.name` | No | Yes (select) |
| Quantity | `quantity` | Yes | No |
| Price | `price_per_unit` | Yes | No |
| Total | `total_value` | Yes | No |
| Actions | edit/delete buttons | No | No |

Pagination: client-side, 20 rows per page.

CSV export: downloads all transactions as CSV (date, type, asset, symbol, category, account, quantity, price, total).

### Responsive Layout

**Desktop (> 1024px):**
```
┌──────────┬─────────────────────────────────────┐
│          │                                     │
│ Sidebar  │           Main Content              │
│          │                                     │
│ - Home   │   (page content here)               │
│ - Charts │                                     │
│ - Txns   │                                     │
│ - Accts  │                                     │
│ - Profile│                                     │
│          │                                     │
└──────────┴─────────────────────────────────────┘
```

**Mobile (< 768px):**
```
┌─────────────────────────────────────┐
│                                     │
│           Main Content              │
│                                     │
│   (page content here, full width)   │
│                                     │
├─────┬─────┬─────┬─────┬────────────┤
│Home │Chart│Txns │Accts│Profile     │
└─────┴─────┴─────┴─────┴────────────┘
```

### Dark Mode

- `next-themes` library for theme management (or manual ThemeContext)
- Tailwind `class` strategy: `darkMode: "class"` in `tailwind.config.ts`
- Theme toggle in sidebar header + profile page
- Persisted to `localStorage`
- shadcn/ui components support dark mode via CSS variables out of the box

### Profile Page — Danger Zone

The `/profile` page includes a "Danger Zone" section at the bottom:

- Red-bordered card with destructive styling
- "Delete All Financial Data" button
- Confirmation dialog requiring user to type `DELETE` to confirm
- Calls `DELETE /users/me/data` via `useDeleteUserData()`
- On success: signs out via Firebase Auth, redirects to `/login`
- Note: preserves the Firebase auth account — only deletes financial data (accounts, assets, transactions, snapshots)

### Environment Variables

```
# .env.local
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
```

---

## Implementation Todo List

### Phase 1: Project Scaffolding

- [x] **1.1** `npx create-next-app@latest VaultTrackerWeb --typescript --tailwind --app --src-dir` (scaffold inside the monorepo)
- [x] **1.2** `npx shadcn@latest init` + add components: button, card, input, dialog, sheet, toast, table, dropdown-menu, avatar, badge, separator, tabs, skeleton, select, popover, calendar
- [x] **1.3** `npm install @tanstack/react-query @tanstack/react-table recharts react-hook-form @hookform/resolvers zod firebase date-fns next-themes`
- [x] **1.4** Set up `lib/firebase.ts` — Firebase app init, auth exports
- [x] **1.5** Set up `lib/api-client.ts` — fetch wrapper with JWT + 401 retry
- [x] **1.6** Set up `contexts/auth-context.tsx` — `onAuthStateChanged`, token management
- [x] **1.7** Set up React Query provider in `app/layout.tsx`
- [x] **1.8** Set up dark mode — `next-themes` or ThemeContext + Tailwind `class` strategy
- [x] **1.9** Set up `types/api.ts` — all TypeScript types matching backend schemas (use literal unions for Category, AccountType, TransactionType, NetWorthPeriod)
- [x] **1.10** Set up all React Query hooks in `lib/queries/` — dashboard, transactions (CRUD), accounts (CRUD), assets (with category filter), analytics, networth, prices (refresh + lookup), user (delete data)

### Phase 2: Auth & Layout Shell

- [x] **2.1** Build `/login` page — Google Sign-In button via Firebase Auth popup
- [x] **2.2** Build `(authenticated)/layout.tsx` — auth guard + app shell
- [x] **2.3** Build sidebar component — navigation links, theme toggle, user avatar
- [x] **2.4** Build mobile bottom tabs component
- [x] **2.5** Build `/profile` page — display name, email, sign out button, theme toggle, "Delete All Data" danger zone
- [x] **2.6** Root `/` page — redirect to `/dashboard` or `/login`

### Phase 3: Dashboard Page

- [x] **3.1** Wire up `useDashboard`, `useNetWorthHistory`, and `useAssets(category?)` query hooks
- [x] **3.2** Build stat cards — total net worth + 5 category totals
- [x] **3.3** Build net worth line chart (Recharts `LineChart` + `AreaChart`, CatmullRom)
- [x] **3.4** Build proportional category bar (colored segments)
- [x] **3.5** Build grouped holdings grid — expandable sections per category
- [x] **3.6** Add category filter chips (All + 5 categories)
- [x] **3.7** Add "Refresh Prices" button (calls `POST /prices/refresh`)
- [x] **3.8** Loading skeletons for all dashboard components
- [x] **3.9** Error state handling

### Phase 4: Transactions Page

- [x] **4.1** Wire up `useTransactions`, `useCreateTransaction`, `useUpdateTransaction`, `useDeleteTransaction` hooks
- [x] **4.2** Build transaction table — TanStack Table with all columns
- [x] **4.3** Add column sorting
- [x] **4.4** Add search (asset name) + filters (category, type, account)
- [x] **4.5** Add pagination (client-side, 20 per page)
- [x] **4.6** Build add transaction modal — React Hook Form + Zod
  - Category-dependent field visibility (symbol, quantity label, price)
  - Cash/realEstate: quantity = amount, price = 1.0
- [x] **4.7** Build edit transaction modal (pre-filled, calls `PUT /transactions/{id}/smart` with same body shape as smart create)
- [x] **4.8** Delete transaction with confirmation dialog
- [x] **4.9** CSV export button

### Phase 5: Accounts Page

- [x] **5.1** Wire up `useAccounts`, `useCreateAccount`, `useUpdateAccount`, `useDeleteAccount` hooks
- [x] **5.2** Build account card grid — name, type, created date
- [x] **5.3** Build add account modal (name + type)
- [x] **5.4** Build edit account modal
- [x] **5.5** Delete account with confirmation (warn: cascading deletes)
- [x] **5.6** Show linked assets/transaction count per account (requires `GET /assets` + `GET /transactions` filtered)

### Phase 6: Analytics Page

- [x] **6.1** Create `use-analytics` query hook
- [x] **6.2** Asset allocation donut chart (Recharts `PieChart`)
- [x] **6.3** Performance summary cards (gain/loss, cost basis, current value)
- [x] **6.4** Net worth chart with period selector (daily/weekly/monthly/all)
- [x] **6.5** Single price lookup — search by symbol, display current price via `GET /prices/{symbol}`

### Phase 7: Polish & Deploy

- [x] **7.1** Empty states for all pages (no data yet)
- [x] **7.2** Error boundary component
- [ ] **7.3** Responsive testing — mobile, tablet, desktop
- [ ] **7.4** Dark mode testing across all pages
- [ ] **7.5** Deploy to Vercel — connect GitHub repo, set env vars
- [ ] **7.6** Update backend CORS with Vercel production URL
- [ ] **7.7** End-to-end smoke test: sign in → add transaction → dashboard updates → analytics → CSV export
- [ ] **7.8** Test delete-all-data flow: profile → delete data → confirm → signed out → data gone
- [ ] **7.9** Test single price lookup flow

---

## Verification

### Local Development

1. Backend running at `localhost:8000` with `DEBUG_AUTH_ENABLED=true`
2. `cd VaultTrackerWeb && npm run dev` → opens `localhost:3000`
3. Sign in with Google (or configure debug auth for web)
4. Add transaction via smart form → verify dashboard updates
5. Verify transaction table shows enriched data
6. Verify analytics page shows allocation + performance
7. Delete transaction → verify dashboard updates
8. Look up a price by symbol → verify result displays
9. Profile → Delete All Data → confirm → verify signed out and data cleared
10. Toggle dark mode → verify all pages
11. Resize to mobile → verify bottom tabs + layout

### Production

1. Visit Vercel URL
2. Sign in with Google
3. Verify same data visible as in iOS app (shared Firebase user)
4. Full CRUD cycle + price refresh + CSV export
5. Test on actual mobile device
