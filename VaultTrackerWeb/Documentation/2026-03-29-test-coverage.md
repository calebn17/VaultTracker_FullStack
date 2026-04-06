# Web Test Coverage Map

**Date:** 2026-03-29
**Total tests:** ~95 (31 unit · 49 component+hook · 15 E2E)

---

## Test Suite Overview

| Layer     | Location                                               | Count | Requires server?                          |
| --------- | ------------------------------------------------------ | ----- | ----------------------------------------- |
| Unit      | `src/lib/__tests__/*.test.ts`                          | 31    | No                                        |
| Hook      | `src/lib/queries/__tests__/*.test.tsx`                 | 13    | No                                        |
| Component | `src/components/__tests__/`, `src/contexts/__tests__/` | 36    | No                                        |
| E2E       | `e2e/*.spec.ts`                                        | 15    | Yes (FastAPI + `DEBUG_AUTH_ENABLED=true`) |

---

## Sub-Module Coverage

### Utilities (`src/lib/`)

#### `format.ts`

**Features:** `formatCurrency()` (USD, 2 decimals, grouping), `formatDate()` (ISO → "MMM d, yyyy", error fallback), `formatDateTime()` (includes time).

| Test file        | Cases | Coverage    |
| ---------------- | ----- | ----------- |
| `format.test.ts` | 3     | ✅ Complete |

#### `transaction-schema.ts`

**Features:** Zod schema enforcing symbol requirement per category; `needsSymbol()`, `isCashLike()` helpers; `toFormDefaults()` for pre-filling edit form.

| Test file                    | Cases | Coverage    |
| ---------------------------- | ----- | ----------- |
| `transaction-schema.test.ts` | 12    | ✅ Complete |

#### `account-types.ts`

**Features:** `ACCOUNT_TYPES_BY_CATEGORY` map (5 categories); `defaultAccountType()`.

| Test file               | Cases | Coverage    |
| ----------------------- | ----- | ----------- |
| `account-types.test.ts` | 4     | ✅ Complete |

#### `api-client.ts`

**Features:** `ApiClient.get/post/put/delete`; Bearer token injection; 204 → undefined; 4xx/5xx → `ApiError`; 401 → force-refresh + retry; persistent 401 → `onUnauthorized`; `ApiError.fromResponse` body parsing.

| Test file            | Cases | Coverage    |
| -------------------- | ----- | ----------- |
| `api-client.test.ts` | 7     | ✅ Complete |

#### `networth-change.ts`

**Features:** `computeApproxMonthChange()` — trailing-30-day absolute + percent delta; handles empty/single snapshot, unsorted input, baseline within window, divide-by-zero, negative change.

| Test file                 | Cases | Coverage                       |
| ------------------------- | ----- | ------------------------------ |
| `networth-change.test.ts` | 7     | ✅ Complete (added 2026-03-29) |

---

### Auth & Context (`src/contexts/`)

#### `auth-context.tsx`

**Features:** Debug auth mode (`signInDebug`, debug token, stub user); `signOutUser` resets state + redirects; `signInDebug` undefined in production builds.

| Test file                    | Cases | Coverage                            |
| ---------------------------- | ----- | ----------------------------------- |
| `auth-context.test.tsx`      | 4     | ✅ Debug mode behavior              |
| `auth-context.prod.test.tsx` | 1     | ✅ Production: `signInDebug` absent |

#### `api-client-context.tsx`

**Features:** Provides `ApiClient` instance from env-based base URL; `useApiClient()` throws outside provider.

| Test file | Cases | Coverage                                      |
| --------- | ----- | --------------------------------------------- |
| —         | 0     | ⚠️ Covered indirectly via hook tests (mocked) |

---

### React Query Hooks (`src/lib/queries/`)

#### `use-transactions.ts`

**Features:** `useTransactions` — GET `/api/v1/transactions`; `useCreateTransaction` — POST `/api/v1/transactions/smart`, invalidates 5 keys; `useUpdateTransaction` — PUT `/api/v1/transactions/:id/smart`, invalidates 5 keys; `useDeleteTransaction` — DELETE `/api/v1/transactions/:id`, invalidates 5 keys.

| Test file                   | Cases | Coverage                                                               |
| --------------------------- | ----- | ---------------------------------------------------------------------- |
| `use-transactions.test.tsx` | 7     | ✅ URL construction, payload, all invalidation keys (added 2026-03-29) |

#### `use-accounts.ts`

**Features:** `useAccounts` — GET `/api/v1/accounts`; `useCreateAccount` — POST, invalidates accounts + dashboard; `useUpdateAccount` — PUT `/api/v1/accounts/:id`, invalidates accounts + dashboard; `useDeleteAccount` — DELETE, invalidates 6 keys.

| Test file               | Cases | Coverage                                                               |
| ----------------------- | ----- | ---------------------------------------------------------------------- |
| `use-accounts.test.tsx` | 6     | ✅ URL construction, payload, all invalidation keys (added 2026-03-29) |

#### `use-dashboard.ts`

**Features:** GET `/api/v1/dashboard` → `DashboardResponse`.

| Test file | Cases | Coverage                            |
| --------- | ----- | ----------------------------------- |
| —         | 0     | ⚠️ Not unit tested (covered by E2E) |

#### `use-analytics.ts`

**Features:** GET `/api/v1/analytics` → `AnalyticsResponse`.

| Test file | Cases | Coverage                                                     |
| --------- | ----- | ------------------------------------------------------------ |
| —         | 0     | ⚠️ Not unit tested (simple query, same pattern as dashboard) |

#### `use-networth.ts`

**Features:** GET `/api/v1/networth/history?period=...` → `NetWorthHistoryResponse`.

| Test file | Cases | Coverage           |
| --------- | ----- | ------------------ |
| —         | 0     | ⚠️ Not unit tested |

#### `use-prices.ts`

**Features:** GET single price by symbol; POST refresh all prices.

| Test file | Cases | Coverage           |
| --------- | ----- | ------------------ |
| —         | 0     | ⚠️ Not unit tested |

#### `use-assets.ts`, `use-user.ts`

**Features:** GET assets list; GET current user.

| Test file | Cases | Coverage           |
| --------- | ----- | ------------------ |
| —         | 0     | ⚠️ Not unit tested |

---

### Dashboard Components (`src/components/dashboard/`)

#### `stat-card.tsx`

**Features:** Three variants (`default`, `hero`, `compact`); renders title + value text; shows Skeleton while loading; hides value text when loading.

| Test file            | Cases | Coverage                                            |
| -------------------- | ----- | --------------------------------------------------- |
| `stat-card.test.tsx` | 5     | ✅ All 3 variants, loading state (added 2026-03-29) |

#### `asset-detail-dialog.tsx` + `holdings-grid.tsx`

**Features:** Cost basis computation (sum of qty × price); avg cost per unit; unrealized P&L (absolute + %); cash hides qty/avg/P&L/costBasis; real estate hides qty/avg/P&L but keeps cost basis; max 5 recent transactions, newest first; filtered by `asset_id`; opens on row click.

| Test file                      | Cases | Coverage                                                            |
| ------------------------------ | ----- | ------------------------------------------------------------------- |
| `asset-detail-dialog.test.tsx` | 9     | ✅ All computation paths, category rules, row limit, holdings click |

#### `net-worth-chart.tsx`

**Features:** Line/area chart of net worth over time; range buttons (1M/6M/1Y/ALL) → period param.

| Test file | Cases | Coverage                                           |
| --------- | ----- | -------------------------------------------------- |
| —         | 0     | ⚠️ Visual (Recharts); range buttons covered by E2E |

#### `category-bar.tsx`, `category-summary-list.tsx`

**Features:** Stacked bar showing allocation by category; category list with values and percentages.

| Test file | Cases | Coverage                 |
| --------- | ----- | ------------------------ |
| —         | 0     | ⚠️ Visual; no unit tests |

---

### Transaction Components (`src/components/transactions/`)

#### `transaction-form.tsx` (`TransactionFormDialog`)

**Features:** Category-dependent field visibility (symbol/price_per_unit hidden for cash/realEstate); "Amount ($)" label for cash; Zod validation with per-field errors; pre-fill from existing transaction; `onOpenChange(false)` after successful submit; dialog stays open on submit error; Cancel button closes; Save disabled when `pending`.

| Test file                   | Cases | Coverage                                                                 |
| --------------------------- | ----- | ------------------------------------------------------------------------ |
| `transaction-form.test.tsx` | 14    | ✅ Field visibility, validation, pre-fill, submit, cancel, pending state |

#### `transaction-table.tsx`

**Features:** Sortable, filterable, paginated table (TanStack Table v8); CSV export; delete with confirmation.

| Test file | Cases | Coverage                                   |
| --------- | ----- | ------------------------------------------ |
| —         | 0     | ⚠️ Covered by E2E (`transactions.spec.ts`) |

---

### Account Components (`src/components/accounts/`)

#### `account-form.tsx`

**Features:** Add/edit account form (name, account_type).

| Test file | Cases | Coverage                               |
| --------- | ----- | -------------------------------------- |
| —         | 0     | ⚠️ Covered by E2E (`accounts.spec.ts`) |

---

### Pages

#### `/login`

**Features:** Google sign-in button (or Firebase notice); debug sign-in button (dev only); redirects to `/dashboard` on success.

| Test file          | Cases | Coverage                                                   |
| ------------------ | ----- | ---------------------------------------------------------- |
| `e2e/auth.spec.ts` | 4     | ✅ Login page visibility, debug login, auth guard redirect |

#### `/dashboard`

**Features:** Net Worth heading + hero value; stats grid; net worth chart with period picker; allocation bar/list; holdings grid (click → asset detail dialog); Refresh Prices button.

| Test file               | Cases | Coverage                                                                                    |
| ----------------------- | ----- | ------------------------------------------------------------------------------------------- |
| `e2e/dashboard.spec.ts` | 4     | ✅ Heading, Refresh Prices toast, period picker, holdings → asset detail (added 2026-03-29) |

#### `/transactions`

**Features:** Table with all transactions; Add/Edit dialog; delete with confirmation alert; "Transaction added" toast on create; CSV export.

| Test file                  | Cases | Coverage                                                    |
| -------------------------- | ----- | ----------------------------------------------------------- |
| `e2e/transactions.spec.ts` | 4     | ✅ Table load, dialog open, create buy, delete with confirm |

#### `/accounts`

**Features:** Account list; Add account dialog; delete with confirmation.

| Test file              | Cases | Coverage                                        |
| ---------------------- | ----- | ----------------------------------------------- |
| `e2e/accounts.spec.ts` | 3     | ✅ Page load, create, delete (added 2026-03-29) |

#### `/analytics`

**Features:** Portfolio hero (total value, gain/loss); category bento cards with holdings; performance attribution; price lookup; chart.

| Test file | Cases | Coverage                              |
| --------- | ----- | ------------------------------------- |
| —         | 0     | ❌ No tests (unit, component, or E2E) |

#### `/profile`

**Features:** User info display; dark/light theme toggle (persisted to localStorage); sign out; delete all data.

| Test file | Cases | Coverage                              |
| --------- | ----- | ------------------------------------- |
| —         | 0     | ⚠️ Sign out covered by `auth.spec.ts` |

---

## Coverage Summary

| Sub-module                | Unit/Hook | Component | E2E  | Status        |
| ------------------------- | --------- | --------- | ---- | ------------- |
| `format.ts`               | ✅ 3      | —         | —    | Complete      |
| `transaction-schema.ts`   | ✅ 12     | —         | —    | Complete      |
| `account-types.ts`        | ✅ 4      | —         | —    | Complete      |
| `api-client.ts`           | ✅ 7      | —         | —    | Complete      |
| `networth-change.ts`      | ✅ 7      | —         | —    | Complete      |
| `auth-context.tsx`        | —         | ✅ 5      | —    | Complete      |
| `api-client-context.tsx`  | —         | —         | —    | Indirect only |
| `use-transactions.ts`     | ✅ 7      | —         | ✅   | Complete      |
| `use-accounts.ts`         | ✅ 6      | —         | ✅   | Complete      |
| `use-dashboard.ts`        | ❌ 0      | —         | ✅   | E2E only      |
| `use-analytics.ts`        | ❌ 0      | —         | ❌   | Not tested    |
| `use-networth.ts`         | ❌ 0      | —         | —    | Not tested    |
| `use-prices.ts`           | ❌ 0      | —         | ⚠️   | Not tested    |
| `stat-card.tsx`           | —         | ✅ 5      | —    | Complete      |
| `asset-detail-dialog.tsx` | —         | ✅ 9      | —    | Complete      |
| `net-worth-chart.tsx`     | —         | —         | ⚠️   | Visual only   |
| `transaction-form.tsx`    | —         | ✅ 14     | —    | Complete      |
| `transaction-table.tsx`   | —         | —         | ✅   | E2E only      |
| `account-form.tsx`        | —         | —         | ✅   | E2E only      |
| `/login` page             | —         | —         | ✅ 4 | Complete      |
| `/dashboard` page         | —         | —         | ✅ 4 | Good          |
| `/transactions` page      | —         | —         | ✅ 4 | Good          |
| `/accounts` page          | —         | —         | ✅ 3 | Good          |
| `/analytics` page         | —         | —         | ❌ 0 | Not tested    |
| `/profile` page           | —         | —         | ⚠️   | Partial       |

---

## CI Split

```
┌──────────────────────────────────────────────────────────────┐
│  Job: unit-tests (no server)                                 │
│  npm run test                                                │
│  Covers: lib/__tests__/, lib/queries/__tests__/,             │
│          components/__tests__/, contexts/__tests__/          │
│  Count: ~80 tests · sub-second · always green in CI         │
├──────────────────────────────────────────────────────────────┤
│  Job: e2e-tests (requires backend sidecar)                   │
│  npm run test:e2e                                            │
│  Requires: FastAPI running, DEBUG_AUTH_ENABLED=true,         │
│            NEXT_PUBLIC_API_URL set                           │
│  Count: 15 tests · gate on PR merge or nightly              │
└──────────────────────────────────────────────────────────────┘
```

---

## Known Gaps (Future Work)

| Gap                                                    | Priority | Notes                                              |
| ------------------------------------------------------ | -------- | -------------------------------------------------- |
| `/analytics` page E2E                                  | High     | No coverage at all; analytics hook also untested   |
| `use-dashboard`, `use-networth`, `use-analytics` hooks | Medium   | Simple queries; same pattern as `use-transactions` |
| `/profile` sign-out E2E                                | Low      | Partially covered by auth guard test               |
| `category-bar`, `category-summary-list`                | Low      | Visual components; low regression risk             |
