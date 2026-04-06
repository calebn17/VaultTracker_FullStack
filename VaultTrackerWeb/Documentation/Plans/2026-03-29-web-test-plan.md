# Web Test Plan — VaultTracker

**Date:** 2026-03-29
**Current state:** 59 tests (24 unit · 27 component · 8 E2E)
**Target after this plan:** ~97 tests

---

## 1. Architecture Overview

```
Pages (Next.js App Router)
    ↓
React Query Hooks (src/lib/queries/)   ←→   ApiClient (fetch + JWT + 401 retry)
    ↓                                              ↓
Components (src/components/)              AuthContext (Firebase + debug)
    ↓
Utilities (src/lib/)   Types (src/types/api.ts)
```

Each seam is a testable boundary:

- **Utilities** — pure functions, no deps → unit tests
- **Hooks** — mock `ApiClient` via `vi.mock("@/contexts/api-client-context")` → hook tests
- **Components** — mock hooks → component tests
- **E2E** — real browser + real Next.js + real API (debug auth) → Playwright

---

## 2. Full Functionality Inventory

| Area             | Components                                                                                                                   |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **Utilities**    | `format.ts`, `account-types.ts`, `transaction-schema.ts`, `networth-change.ts`, `utils.ts`                                   |
| **API Client**   | `api-client.ts` — fetch wrapper, JWT injection, 401 retry                                                                    |
| **Contexts**     | `auth-context.tsx` (Firebase + debug), `api-client-context.tsx`                                                              |
| **Hooks**        | `use-dashboard`, `use-transactions`, `use-accounts`, `use-analytics`, `use-networth`, `use-prices`, `use-assets`, `use-user` |
| **Dashboard**    | `stat-card`, `category-bar`, `category-summary-list`, `net-worth-chart`, `holdings-grid`, `asset-detail-dialog`              |
| **Transactions** | `transaction-form`, `transaction-table`                                                                                      |
| **Accounts**     | `account-form`                                                                                                               |
| **Analytics**    | `portfolio-hero`, `performance-attribution`, `category-bento-card`                                                           |
| **Layout**       | `app-shell`, `site-header`, `mobile-nav`                                                                                     |
| **Pages**        | `/login`, `/dashboard`, `/transactions`, `/accounts`, `/analytics`, `/profile`                                               |

---

## 3. Layer-by-Layer Coverage Audit

### Unit Tests (24 tests in `src/lib/__tests__/`)

| File                    | Tests | Status        |
| ----------------------- | ----- | ------------- |
| `format.ts`             | 3     | ✅ Complete   |
| `account-types.ts`      | 4     | ✅ Complete   |
| `transaction-schema.ts` | 12    | ✅ Complete   |
| `api-client.ts`         | 7     | ✅ Complete   |
| `networth-change.ts`    | 0     | ❌ Not tested |

### Component/Context Tests (27 tests)

| File                                                                    | Tests | Status                                              |
| ----------------------------------------------------------------------- | ----- | --------------------------------------------------- |
| `auth-context.tsx` (debug)                                              | 4     | ✅ Good                                             |
| `auth-context.tsx` (prod guard)                                         | 1     | ✅ Good                                             |
| `transaction-form.tsx`                                                  | 10    | ✅ Good                                             |
| `asset-detail-dialog.tsx` + `holdings-grid.tsx`                         | 9     | ✅ Good                                             |
| All hooks (`use-transactions`, `use-accounts`, etc.)                    | 0     | ❌ Not tested                                       |
| `stat-card.tsx`                                                         | 0     | ❌ Not tested                                       |
| Page components (dashboard, transactions, accounts, analytics, profile) | 0     | ⚠️ Out of scope (too integration-heavy without E2E) |

### E2E Tests (8 tests in `e2e/`)

| File                   | Tests | Status                                           |
| ---------------------- | ----- | ------------------------------------------------ |
| `auth.spec.ts`         | 4     | ✅ Good (login, auth guard, debug login)         |
| `transactions.spec.ts` | 4     | ✅ Good (table load, add dialog, create, delete) |
| `dashboard.spec.ts`    | 0     | ❌ Missing                                       |
| `accounts.spec.ts`     | 0     | ❌ Missing                                       |

---

## 4. Gap Analysis (Priority Order)

### P1 — Missing coverage causing low confidence

1. **React Query hooks** — All 8 query hooks are untested. Mutations could call the wrong URL, invalidate the wrong keys, or send a malformed body. These bugs are invisible without hook tests.
2. **`networth-change.ts`** — Pure function with edge cases (empty array, baseline selection, divide-by-zero). Zero tests.

### P2 — E2E gaps in core flows

3. **Dashboard** — No E2E verification that the dashboard loads meaningful data or that interactions (period picker, refresh, holdings click) work end-to-end.
4. **Accounts** — Account CRUD has no E2E coverage at all.

### P3 — Component gaps (nice-to-have)

5. **`StatCard`** — Simple component, easy to test, currently zero tests.
6. **`TransactionForm` edge cases** — Error on submit and reset after success not tested.

### P4 — Formerly deferred; implemented (follow-up)

- **Remaining React Query hooks** — Vitest coverage added in `src/lib/queries/__tests__/`: `use-dashboard.test.tsx`, `use-networth.test.tsx`, `use-analytics.test.tsx`, `use-assets.test.tsx`, `use-prices.test.tsx` (`useRefreshPrices` + `usePriceLookup`), `use-user.test.tsx` (`useDeleteUserData` only; [`use-user.ts`](../../src/lib/queries/use-user.ts) has no `useQuery` wrapper).
- **`/analytics` page E2E** — [`e2e/analytics.spec.ts`](../../e2e/analytics.spec.ts): debug login → sidebar **Analytics**; asserts **Total portfolio**, category cards (**Stocks & ETFs**, **Digital Assets**); price lookup uses a Playwright route stub for `GET **/api/v1/prices/BTC` so the flow is deterministic without a live price backend.
- **`/profile` page E2E** — [`e2e/profile.spec.ts`](../../e2e/profile.spec.ts): **Toggle theme** scoped to `main` (header also has a theme control); **Delete all financial data** uses a stubbed `DELETE **/api/v1/users/me/data`, then asserts toast **All financial data removed** and redirect to `/login`.

### Permanently out of scope

- shadcn UI primitives (`src/components/ui/`) — library components, not app logic
- Static layout (`site-header`, `mobile-nav`, `app-shell`) — no meaningful testable logic
- Recharts chart rendering — visual only, requires snapshot tooling

---

## 5. Test Pyramid Target

```
          ┌─────────────────────────────────┐
          │      E2E / Playwright (15)  15%  │
          ├─────────────────────────────────┤
          │   Component + Hook (49)     50%  │
          ├─────────────────────────────────┤
          │     Unit (33)               35%  │
          └─────────────────────────────────┘
```

**Key principle:** Unit and component tests run with `npm run test` (no server, sub-second).
E2E tests require local API (`DEBUG_AUTH_ENABLED=true`) and are gated as a separate CI job.

---

## 6. New Tests

### 6.1 `src/lib/__tests__/networth-change.test.ts` (NEW — 7 tests)

Pure function tests; no mocking needed.

| Test                                                          | Input → Expected                                                                         |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| returns null for empty array                                  | `[]` → `null`                                                                            |
| returns null for single snapshot                              | `[{date, value:100}]` → `null`                                                           |
| computes correct absolute and percent                         | `[{Feb25,80k},{Mar26,100k}]` → `{absolute:20000, percent:25}`                            |
| returns 0 percent when baseline value is 0                    | `[{Feb25,0},{Mar26,5000}]` → `{absolute:5000, percent:0}` (not NaN/Infinity)             |
| handles unsorted input by sorting internally                  | Reversed order → same result as sorted order                                             |
| uses snapshot within 30-day window as baseline, ignores older | 3 points at day -60, -20, 0 → absolute is value(day0) - value(day-20), NOT value(day-60) |
| computes negative change correctly                            | `100k → 80k` → `{absolute:-20000, percent≈-20}`                                          |

### 6.2 `src/lib/queries/__tests__/use-transactions.test.tsx` (NEW — 7 tests)

Mocks `useApiClient` to return a stub `ApiClient` with spied methods.

```typescript
vi.mock("@/contexts/api-client-context", () => ({
  useApiClient: () => mockApi,
}));
```

| Test                                                       | What it proves                                                                                                                          |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `useTransactions` fetches and returns list                 | `api.get` called with `"/api/v1/transactions"` → `data[0].asset_name == "Bitcoin"`                                                      |
| `useCreateTransaction` calls correct path                  | `api.post` spy called with `("/api/v1/transactions/smart", body)`                                                                       |
| `useCreateTransaction` invalidates 5 query keys on success | `queryClient.invalidateQueries` called with each of: `["dashboard"]`, `["transactions"]`, `["networth"]`, `["analytics"]`, `["assets"]` |
| `useUpdateTransaction` builds correct URL with id          | `api.put` called with `"/api/v1/transactions/txn-42/smart"` when id is `"txn-42"`                                                       |
| `useUpdateTransaction` invalidates 5 query keys on success | Same 5 keys as create                                                                                                                   |
| `useDeleteTransaction` calls correct DELETE path           | `api.delete` called with `"/api/v1/transactions/txn-99"`                                                                                |
| `useDeleteTransaction` invalidates 5 query keys on success | Same 5 keys                                                                                                                             |

### 6.3 `src/lib/queries/__tests__/use-accounts.test.tsx` (NEW — 6 tests)

Same mock pattern as above.

Note: `useCreateAccount` and `useUpdateAccount` invalidate `["accounts"]` + `["dashboard"]`.
`useDeleteAccount` invalidates 6 keys: `accounts`, `dashboard`, `networth`, `analytics`, `transactions`, `assets`.

| Test                                                              | What it proves                                               |
| ----------------------------------------------------------------- | ------------------------------------------------------------ |
| `useAccounts` fetches list                                        | `api.get("/api/v1/accounts")` → `data[0].name == "Coinbase"` |
| `useCreateAccount` posts to `/api/v1/accounts`                    | Spy verifies path + body                                     |
| `useCreateAccount` invalidates `["accounts"]` and `["dashboard"]` | 2 invalidation calls                                         |
| `useUpdateAccount` puts to `/api/v1/accounts/:id`                 | Correct URL interpolation                                    |
| `useDeleteAccount` deletes `/api/v1/accounts/:id`                 | Correct URL                                                  |
| `useDeleteAccount` invalidates all 6 query keys                   | Verify each key                                              |

### 6.4 `src/components/__tests__/stat-card.test.tsx` (NEW — 5 tests)

No mocking needed; `StatCard` is a pure presentational component.

| Test                                         | What it proves                                                    |
| -------------------------------------------- | ----------------------------------------------------------------- |
| default variant renders title and value text | `getByText("Total Value")`, `getByText("$10,000")` both visible   |
| default variant shows Skeleton when loading  | `loading=true` → Skeleton present, value text absent              |
| hero variant renders title and value         | Different className path — value in `<p>` with `font-serif` class |
| hero variant shows Skeleton when loading     | Skeleton present for hero variant too                             |
| compact variant renders title and value      | `variant="compact"` renders value in `text-lg` paragraph          |

### 6.5 `src/components/__tests__/transaction-form.test.tsx` — 2 additional tests

| Test                                       | What it proves                                   |
| ------------------------------------------ | ------------------------------------------------ |
| calls onClose after successful submission  | `onSubmit` resolves → `onClose` callback invoked |
| does not call onClose when onSubmit throws | `onSubmit` rejects → `onClose` NOT called        |

### 6.6 `e2e/dashboard.spec.ts` (NEW — 4 tests)

Uses same pattern as `transactions.spec.ts`: debug login, then client navigation.

```typescript
async function debugLoginToDashboard(page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
}
```

| Test                                                                   | What it proves                                                                          |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| dashboard shows Net Worth heading                                      | `getByRole("heading", { name: /net worth/i })` visible                                  |
| refresh prices button is present and clickable                         | Button visible; click shows toast                                                       |
| period picker changes active button                                    | Click "6M" → that button has active/selected state                                      |
| clicking holdings row opens asset detail dialog (requires seeded data) | After creating a transaction, row in holdings grid opens dialog with "Cost Basis" label |

> Note: The holdings dialog test depends on data existing. It should run after the transaction E2E tests create data, or use a `beforeAll` setup step to seed one transaction.

### 6.7 `e2e/accounts.spec.ts` (NEW — 3 tests)

```typescript
async function debugLoginAndGoToAccounts(page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
  await page.getByRole("link", { name: "Accounts" }).click();
  await expect(page).toHaveURL(/\/accounts/);
}
```

| Test                                      | What it proves                                                     |
| ----------------------------------------- | ------------------------------------------------------------------ |
| accounts page loads with Accounts heading | `getByRole("heading", { name: "Accounts" })` visible               |
| create account shows new row              | Fill form → save → row with account name visible                   |
| delete account removes row                | Create → delete → confirm → row NOT visible (`.not.toBeVisible()`) |

---

## 7. CI Considerations

| Test suite         | Command                 | Server needed?                                     |
| ------------------ | ----------------------- | -------------------------------------------------- |
| Unit + component   | `npm run test`          | No — runs in jsdom, milliseconds                   |
| Unit with coverage | `npm run test:coverage` | No                                                 |
| E2E                | `npm run test:e2e`      | Yes — local FastAPI with `DEBUG_AUTH_ENABLED=true` |

CI strategy:

- **PR checks:** `npm run test` (fast, no deps) always runs
- **E2E job:** Separate CI job with backend sidecar; can be gated or run nightly

---

## 8. Test Quality Principle

Every test must be capable of failing when the implementation is wrong:

- Hook tests: spy on `api.get`/`api.post`/`api.put`/`api.delete` — assert both the method call AND the returned data shape
- Invalidation tests: spy on `queryClient.invalidateQueries` — assert the exact query keys, not just that the spy was called
- Component tests: assert specific text content or computed values, not just element existence
- E2E tests: after create, assert the specific row by unique name; after delete, assert `.not.toBeVisible()`
