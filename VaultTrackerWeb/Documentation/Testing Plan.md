# VaultTrackerWeb — Testing Plan

For **commands** (`npm run test`, `test:e2e`, etc.), **where tests live**, and **E2E caveats** (debug auth navigation, API requirements), see [`VaultTrackerWeb/CLAUDE.md`](../CLAUDE.md) — section **Testing**.

## Overview

Three-layer testing pyramid:

| Layer     | Tool                               | Environment  | What it tests                           |
| --------- | ---------------------------------- | ------------ | --------------------------------------- |
| Unit      | **Vitest**                         | `node`       | Pure functions, classes, Zod schemas    |
| Component | **Vitest + React Testing Library** | `jsdom`      | React components and hooks in isolation |
| E2E       | **Playwright**                     | Real browser | Full user flows against a running app   |

**Why Vitest over Jest:** Next.js 15 + React 19 rely heavily on ESM. Vitest handles ESM natively and resolves path aliases (`@/`) without a babel transform step. Jest has ongoing ESM friction with the Firebase SDK.

---

## Setup

### Dependencies

```bash
# Unit + component
npm install -D vitest @vitest/coverage-v8 @vitejs/plugin-react
npm install -D @testing-library/react @testing-library/user-event @testing-library/jest-dom
npm install -D jsdom

# E2E
npm install -D @playwright/test
npx playwright install --with-deps chromium
```

### `vitest.config.ts`

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    globals: true,
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
});
```

### `vitest.setup.ts`

```ts
import "@testing-library/jest-dom";
```

### `playwright.config.ts`

```ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  use: {
    baseURL: "http://localhost:3000",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
});
```

### `package.json` scripts

```json
"test": "vitest run",
"test:watch": "vitest",
"test:coverage": "vitest run --coverage",
"test:e2e": "playwright test"
```

---

## Layer 1 — Unit Tests

Location: `src/lib/__tests__/`

No DOM or React. Tests run in the `node` environment (overridden per-file with `@vitest-environment node` if needed).

### `format.test.ts`

Target: `src/lib/format.ts`

| Test                                 | Assertion                       |
| ------------------------------------ | ------------------------------- |
| `formatCurrency(1234.5)`             | `"$1,234.50"`                   |
| `formatDate("2024-03-15T00:00:00Z")` | `"Mar 15, 2024"`                |
| `formatDate("not-a-date")`           | returns input (fallback branch) |
| `formatDateTime(...)`                | includes time component         |

### `account-types.test.ts`

Target: `src/lib/account-types.ts`

| Test                                                    | Assertion                                                              |
| ------------------------------------------------------- | ---------------------------------------------------------------------- |
| All 5 categories present in `ACCOUNT_TYPES_BY_CATEGORY` | object has keys `crypto`, `stocks`, `cash`, `realEstate`, `retirement` |
| `defaultAccountType("crypto")`                          | `"cryptoExchange"`                                                     |
| `defaultAccountType("cash")`                            | `"bank"`                                                               |
| Each value is a non-empty array                         | no empty arrays                                                        |

### `api-client.test.ts`

Target: `src/lib/api-client.ts`. `fetch` mocked with `vi.stubGlobal("fetch", vi.fn())`.

| Test                                                  | Assertion                                                              |
| ----------------------------------------------------- | ---------------------------------------------------------------------- |
| 200 JSON response                                     | resolves with parsed body                                              |
| 204 response                                          | resolves with `undefined`                                              |
| 4xx/5xx response                                      | throws `ApiError` with correct `.status`                               |
| 401 → retry succeeds                                  | calls `getToken` twice (second with `forceRefresh=true`), returns body |
| 401 → retry also 401                                  | calls `onUnauthorized`, throws `ApiError(401)`                         |
| `ApiError.fromResponse` with `{ detail: "msg" }` body | message is `"msg"`                                                     |
| `ApiError.fromResponse` with non-JSON body            | falls back to `statusText`                                             |

### `transaction-schema.test.ts`

Target: `src/lib/transaction-schema.ts` (extracted from `transaction-form.tsx` — see refactor below)

| Test                         | Assertion                                                       |
| ---------------------------- | --------------------------------------------------------------- |
| Crypto without symbol        | validation fails on `symbol`                                    |
| Stocks without symbol        | validation fails on `symbol`                                    |
| Cash without symbol          | passes                                                          |
| Real estate without symbol   | passes                                                          |
| Empty `asset_name`           | fails with "Required"                                           |
| Negative `quantity`          | fails                                                           |
| `needsSymbol("crypto")`      | `true`                                                          |
| `needsSymbol("cash")`        | `false`                                                         |
| `isCashLike("realEstate")`   | `true`                                                          |
| `isCashLike("stocks")`       | `false`                                                         |
| `toFormDefaults(null)`       | returns defaults with `category: "crypto"`, `price_per_unit: 1` |
| `toFormDefaults(existingTx)` | maps all fields correctly, slices date to `YYYY-MM-DD`          |

---

## Layer 2 — Component Tests

Location: `src/components/__tests__/`, `src/contexts/__tests__/`

Uses `jsdom` environment + React Testing Library. Firebase and `next/navigation` are mocked.

**Common mock setup:**

```ts
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: vi.fn((_, cb) => {
    cb(null);
    return () => {};
  }),
  signInWithPopup: vi.fn(),
  signOut: vi.fn(),
}));
```

### `transaction-form.test.tsx`

Target: `src/components/transactions/transaction-form.tsx`

| Test                           | Assertion                                                                |
| ------------------------------ | ------------------------------------------------------------------------ |
| Category = `crypto`            | Symbol field is rendered                                                 |
| Category = `cash`              | Symbol field is absent                                                   |
| Category = `cash`              | Quantity label is "Amount ($)"                                           |
| Category = `stocks`            | Quantity label is "Quantity"                                             |
| Category = `cash`              | Price per unit field is absent                                           |
| Submit with empty `asset_name` | Error message "Required" appears                                         |
| Submit valid crypto form       | `onSubmit` called with correct payload (symbol trimmed, date ISO string) |
| Open with existing transaction | All fields pre-filled from transaction data                              |

### `auth-context.test.tsx`

Target: `src/contexts/auth-context.tsx`

| Test                                              | Assertion                                     |
| ------------------------------------------------- | --------------------------------------------- |
| `signInDebug()`                                   | sets `mode = "debug"`, user to stub           |
| `getToken()` in debug mode                        | returns `DEBUG_AUTH_TOKEN`                    |
| `signOutUser()` in debug mode                     | resets user, calls `router.push("/login")`    |
| Production build (`DEBUG_AUTH_AVAILABLE = false`) | `signInDebug` is `undefined` in context value |

---

## Layer 3 — E2E Tests

Location: `e2e/`

Run against a live dev server (`npm run dev`). Debug auth must be available (development mode).

### `auth.spec.ts`

| Test                                  | Assertion                                           |
| ------------------------------------- | --------------------------------------------------- |
| `/login` renders sign-in button       | "Sign in with Google" button is visible             |
| Debug sign-in button visible in dev   | Button with debug label is present                  |
| Unauthenticated visit to `/dashboard` | Redirects to `/login`                               |
| Debug sign-in → redirect              | After clicking debug sign-in, lands on `/dashboard` |

### `transactions.spec.ts`

Requires debug auth session established in `beforeEach`.

| Test                         | Assertion                                                          |
| ---------------------------- | ------------------------------------------------------------------ |
| `/transactions` loads        | Table is visible                                                   |
| "Add transaction" dialog     | Opens on button click; form fields visible                         |
| Create valid buy transaction | Toast "Transaction created" appears; row present in table          |
| Delete transaction           | Confirmation dialog appears; after confirm, row removed from table |

---

## Refactor: Extract Transaction Schema

Before writing `transaction-schema.test.ts`, the Zod schema and its helpers must be extracted from `transaction-form.tsx` into their own file:

**New file:** `src/lib/transaction-schema.ts`

- Export: `transactionSchema` (the Zod schema object)
- Export: `TransactionFormValues` (the inferred type)
- Export: `needsSymbol(cat: Category): boolean`
- Export: `isCashLike(cat: Category): boolean`
- Export: `toFormDefaults(tx?: EnrichedTransaction | null): TransactionFormValues`

**Updated file:** `src/components/transactions/transaction-form.tsx`

- Import the above from `@/lib/transaction-schema`
- Remove the inline definitions

This is a pure refactor — no behavior change.

---

## File Map

```
VaultTrackerWeb/
├── vitest.config.ts                            (new)
├── vitest.setup.ts                             (new)
├── playwright.config.ts                        (new)
├── src/
│   ├── lib/
│   │   ├── transaction-schema.ts               (new — extracted from transaction-form.tsx)
│   │   └── __tests__/
│   │       ├── format.test.ts                  (new)
│   │       ├── account-types.test.ts           (new)
│   │       ├── api-client.test.ts              (new)
│   │       └── transaction-schema.test.ts      (new)
│   ├── components/
│   │   └── __tests__/
│   │       └── transaction-form.test.tsx       (new)
│   └── contexts/
│       └── __tests__/
│           └── auth-context.test.tsx           (new)
└── e2e/
    ├── auth.spec.ts                            (new)
    └── transactions.spec.ts                    (new)
```
