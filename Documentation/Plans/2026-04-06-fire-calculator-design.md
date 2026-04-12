# FIRE Calculator — Design Spec

**Date:** 2026-04-06
**Status:** Draft
**Scope:** API (FastAPI) + Web (Next.js) MVP

## Context

VaultTracker users track their portfolio across five asset categories (crypto, stocks, cash, real estate, retirement) with transaction history, net worth snapshots, and analytics. A FIRE (Financial Independence, Retire Early) calculator is a natural extension — it answers "when can I stop working?" using the portfolio data users are already maintaining.

The MVP builds a calculation engine on the backend and a dedicated page on the web client. iOS will consume the same API endpoints in a future iteration.

## Summary of Decisions

| Decision | Choice |
|----------|--------|
| Platform | API + Web first; iOS later |
| Data source | Auto-pull portfolio data (net worth, allocation) |
| User inputs | Age, annual income (post-tax), annual expenses, optional target retirement age |
| FIRE types | Show Lean / Regular / Fat FIRE targets simultaneously |
| Persistence | Save user inputs to DB; compute projections on the fly |
| Return rates | Blended rate from actual allocation using per-class defaults |
| Inflation | 3% default, subtracted from nominal returns for real-dollar projections |
| Architecture | API-first — calculation engine on backend, web consumes via React Query |

---

## 1. Data Model

### New Table: `fire_profiles`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | String | PK | UUID string, same pattern as `users.id` / other tables |
| `user_id` | String | FK → `users.id`, unique | One profile per user |
| `current_age` | Integer | NOT NULL | |
| `annual_income` | Float | NOT NULL | Post-tax |
| `annual_expenses` | Float | NOT NULL | Drives FIRE number |
| `target_retirement_age` | Integer | nullable | Optional goal age |
| `created_at` | DateTime | auto | |
| `updated_at` | DateTime | auto on change | |

Add relationship to `User` model: `fire_profile = relationship("FIREProfile", uselist=False, back_populates="user", cascade="all, delete-orphan")`.

### `DELETE /users/me/data` behaviour

`fire_profiles` **is included** in the data wipe. Rationale: a user resetting their financial data should start with a clean FIRE slate — stale income/expense assumptions from a prior portfolio would produce misleading projections. The delete handler in `app/routers/users.py` must add an explicit `db.query(FIREProfile).filter(FIREProfile.user_id == current_user.id).delete()` before the commit (the SQLAlchemy cascade does not fire on bulk deletes, so it must be explicit).

---

## 2. API Endpoints

All under `/api/v1/fire`, authenticated via Firebase JWT (same as all other endpoints).

### `GET /fire/profile`
Returns the user's saved FIRE inputs. **404** if no profile exists.

**Response:** `FIREProfileResponse`
```json
{
  "id": "uuid",
  "currentAge": 32,
  "annualIncome": 145000,
  "annualExpenses": 62000,
  "targetRetirementAge": 45,
  "createdAt": "2026-04-06T...",
  "updatedAt": "2026-04-06T..."
}
```

### `PUT /fire/profile`
Create or update (upsert) the user's FIRE inputs.

**Request:** `FIREProfileInput`
```json
{
  "currentAge": 32,
  "annualIncome": 145000,
  "annualExpenses": 62000,
  "targetRetirementAge": 45
}
```

**Validation:**
- `currentAge`: 18–100
- `annualIncome`: ≥ 0
- `annualExpenses`: ≥ 0
- `targetRetirementAge`: nullable, if provided must be > `currentAge` and ≤ 100

### `GET /fire/projection`
Compute FIRE projection using saved profile + live portfolio data. **404** if no profile exists. Returns `FIREProjectionResponse`.

**Portfolio inputs:** Category **values** and **total net worth** must come from the **same aggregation as `GET /api/v1/dashboard`** (`categoryTotals` per category, `totalNetWorth`). Derive each category **percentage** as `categoryValue / totalNetWorth` when `totalNetWorth > 0`; if net worth is 0, follow the empty-portfolio rule in §3 (no fabricated percentages). Prefer a **shared helper** used by both the dashboard router and `fire_service` so FIRE and the dashboard never disagree.

**Response (reachable case):**
```json
{
  "status": "reachable",
  "unreachableReason": null,
  "inputs": {
    "currentAge": 32,
    "annualIncome": 145000,
    "annualExpenses": 62000,
    "currentNetWorth": 312450,
    "targetRetirementAge": 45
  },
  "allocation": {
    "crypto": { "value": 45000, "percentage": 14.4, "expectedReturn": 0.10 },
    "stocks": { "value": 180000, "percentage": 57.6, "expectedReturn": 0.08 },
    "cash": { "value": 25000, "percentage": 8.0, "expectedReturn": 0.02 },
    "realEstate": { "value": 40000, "percentage": 12.8, "expectedReturn": 0.05 },
    "retirement": { "value": 22450, "percentage": 7.2, "expectedReturn": 0.07 }
  },
  "blendedReturn": 0.072,
  "realBlendedReturn": 0.042,
  "inflationRate": 0.03,
  "annualSavings": 83000,
  "savingsRate": 0.572,
  "fireTargets": {
    "leanFire": { "targetAmount": 1085000, "yearsToTarget": 10, "targetAge": 42 },
    "fire": { "targetAmount": 1550000, "yearsToTarget": 14, "targetAge": 46 },
    "fatFire": { "targetAmount": 2325000, "yearsToTarget": null, "targetAge": null }
  },
  "projectionCurve": [
    { "age": 32, "year": 2026, "projectedValue": 312450 },
    { "age": 33, "year": 2027, "projectedValue": 418000 }
  ],
  "monthlyBreakdown": {
    "monthlySurplus": 6916,
    "monthsToFire": 168
  },
  "goalAssessment": {
    "targetAge": 45,
    "requiredSavingsRate": 0.65,
    "currentSavingsRate": 0.572,
    "status": "behind",
    "gapAmount": 120000
  }
}
```

**Response (unreachable case — annual savings ≤ 0):**
```json
{
  "status": "unreachable",
  "unreachableReason": "non_positive_savings",
  "inputs": { ... },
  "fireTargets": {
    "leanFire": { "targetAmount": 1085000, "yearsToTarget": null, "targetAge": null },
    "fire":     { "targetAmount": 1550000, "yearsToTarget": null, "targetAge": null },
    "fatFire":  { "targetAmount": 2325000, "yearsToTarget": null, "targetAge": null }
  },
  "projectionCurve": [],
  "monthlyBreakdown": { "monthlySurplus": 0, "monthsToFire": null },
  "goalAssessment": null
}
```

**`status` values:**
- `"reachable"` — annual savings > 0 **and** at least one FIRE tier crosses its target within `PROJECTION_YEARS`. Tiers not reached in that window still have `yearsToTarget: null` and `targetAge: null`.
- `"beyond_horizon"` — annual savings > 0 but **no** tier crosses within `PROJECTION_YEARS` (all three have `yearsToTarget` / `targetAge` null). Return a normal `projectionCurve` and target **amounts**; web should explain that no target is hit within the projection window (copy distinct from non-positive savings).
- `"unreachable"` — annual savings ≤ 0; no meaningful timeline. Web should replace the chart with the unreachable copy.

**`unreachableReason` values:** `null` when status is `"reachable"` or `"beyond_horizon"` | `"non_positive_savings"` only when status is `"unreachable"` (income ≤ expenses).

`monthlyBreakdown.monthsToFire` is months to **Regular FIRE** specifically (25 × annual expenses), not the minimum across tiers. It is `null` when status is `"unreachable"` or `"beyond_horizon"`, or when status is `"reachable"` but Regular FIRE is not reached within `PROJECTION_YEARS`.

`goalAssessment` is `null` when `targetRetirementAge` is not set, or when status is `"unreachable"`. When status is `"beyond_horizon"`, still compute `goalAssessment` if `targetRetirementAge` is set (projected value at goal age uses the same discrete return/savings model as the chart). When the goal age is past the fixed projection window, `goalAssessment.computedBeyondProjectionHorizon` is `true` so clients can label extrapolated figures.

---

## 3. Calculation Engine

Located in `VaultTrackerAPI/app/services/fire_service.py`.

### Constants

```python
DEFAULT_RETURNS = {
    "crypto": 0.10,
    "stocks": 0.08,
    "realEstate": 0.05,
    "cash": 0.02,
    "retirement": 0.07,
}
DEFAULT_INFLATION = 0.03
FIRE_MULTIPLIER = 25          # 4% safe withdrawal rate
LEAN_FIRE_EXPENSE_RATIO = 0.7  # 70% of expenses
FAT_FIRE_EXPENSE_RATIO = 1.5   # 150% of expenses
PROJECTION_YEARS = 30
```

### Core Functions

**`compute_blended_return(category_allocations: dict) -> tuple[float, float]`**
- Input: `{category: {value, percentage}}` built from dashboard totals (see `GET /fire/projection` — same numbers as `GET /dashboard`).
- Weighted average: `Σ(percentage/100 × DEFAULT_RETURNS[category])`
- Returns `(nominal_return, real_return)` where `real_return = nominal - DEFAULT_INFLATION`

**`compute_fire_targets(annual_expenses: float) -> dict`**
- Lean FIRE = `annual_expenses × LEAN_FIRE_EXPENSE_RATIO × FIRE_MULTIPLIER`
- Regular FIRE = `annual_expenses × FIRE_MULTIPLIER`
- Fat FIRE = `annual_expenses × FAT_FIRE_EXPENSE_RATIO × FIRE_MULTIPLIER`

**`generate_projection_curve(net_worth, annual_savings, real_return, years=30) -> list[dict]`**
- Year 0: current net worth
- Each subsequent year: `previous_value × (1 + real_return) + annual_savings`
- All values in today's dollars (inflation already subtracted from return)

**`find_crossover_year(curve, target_amount) -> int | None`**
- Linear scan of projection curve for first year where `projectedValue >= target_amount`
- Returns `None` if target not reached within projection window

**`compute_goal_assessment(profile, curve, fire_target) -> dict | None`**
- Only computed when `target_retirement_age` is set and status is `"reachable"` or `"beyond_horizon"`
- Checks projected value at goal age vs Regular FIRE target
- `status`: "ahead" if projected > target, "on_track" if within 5%, "behind" otherwise
- `gapAmount`: target − projected at goal age (negative means surplus)
- `requiredSavingsRate`: solved via binary search on annual savings (bounds: 0 to `annualIncome`). For each candidate savings, run the same discrete yearly recursion — `V_{n+1} = V_n × (1 + real_return) + savings` — over `(target_retirement_age − current_age)` years starting from current net worth. Find the smallest annual savings where `V` at goal age ≥ Regular FIRE target. Express result as `requiredAnnualSavings / annualIncome`. Terminate search when interval is < $1.

**`get_projection(user_id, db) -> FIREProjectionResponse`**
- Orchestrator: loads profile, obtains category totals + net worth via the **same logic as the dashboard** (shared helper), runs all calculations, sets `status` to `"reachable"` | `"beyond_horizon"` | `"unreachable"` from tier crossovers and savings sign, assembles response

### Edge Cases

- **Zero net worth:** Valid — projection starts from 0, driven by savings alone
- **100% cash allocation:** Blended return = 2% nominal, −1% real. FIRE takes much longer.
- **Expenses ≥ income:** Annual savings ≤ 0. Return `status: "unreachable"`, `unreachableReason: "non_positive_savings"`, all tier `yearsToTarget`/`targetAge` as `null`, empty `projectionCurve`, and `monthsToFire: null`
- **No assets in portfolio:** Use 0 for net worth, skip allocation breakdown, use a default 7% blended return
- **Positive savings but no tier within `PROJECTION_YEARS`:** `status: "beyond_horizon"`; non-empty `projectionCurve`; all tier `yearsToTarget` / `targetAge` null; `monthsToFire: null`
- **Target retirement age already passed current age:** Validation rejects this at the API layer

---

## 4. Web UI

### Route & Navigation

New route: `/fire` under `src/app/(authenticated)/fire/page.tsx`

Navigation link added to `site-header.tsx` between "Analytics" and "Transactions":
```
Home | Analytics | FIRE Calc | Transactions | Accounts
```

### Page Layout

Two-column layout (stacks on mobile):

**Left Panel — Inputs:**
- Hero headline: "You can achieve Financial Independence in **X YEARS** by age **Y**" when Regular FIRE is reached within the window; for `beyond_horizon`, use alternate copy (no fake years); for `unreachable`, hide or replace with the savings warning
- Form fields:
  - Current Age (number, "Yrs" suffix)
  - Annual Income, Post-Tax (currency input)
  - Annual Expenses (currency input)
  - Target Retirement Age (number, optional)
  - Current Net Worth (read-only, from portfolio)
  - Asset Allocation bar (read-only, visual bar showing category %)
  - Blended Expected Return (read-only, computed, shown as "X.X% real (Y.Y% nominal − 3% inflation)")
- "Run Simulation" button

**Right Panel — Results:**
- Wealth Projection Chart (Recharts area chart):
  - X-axis: Age
  - Y-axis: Portfolio value ($)
  - Green area: projected growth curve
  - Three horizontal dashed lines: Lean FIRE, FIRE, Fat FIRE (color-coded)
  - Crossover point annotation at Regular FIRE intersection
  - Vertical line at target retirement age (if set) with on-track/behind indicator
- Summary Cards (row of 3):
  - Monthly Surplus
  - Time to FIRE (months)
  - Projected Total at FIRE
- FIRE Targets Table:
  - Rows: Lean FIRE, Regular FIRE, Fat FIRE
  - Columns: Type, Target Amount, Years, Target Age

### UX Flow

1. **First visit (no profile):** Empty form, no results. User fills in inputs and clicks "Run Simulation."
2. **Return visit (profile exists):** Form pre-filled from saved inputs. Projection auto-runs on page load using saved inputs + current portfolio data. Results display immediately.
3. **Changing inputs:** User edits form fields and clicks "Run Simulation" to save new inputs and recompute.
4. **Unreachable FIRE (`status: "unreachable"`):** Show a message instead of the chart: "At your current savings rate, FIRE is not achievable. Consider reducing expenses or increasing income."
5. **Beyond horizon (`status: "beyond_horizon"`):** Show the chart plus copy that no Lean/Regular/Fat target is reached within the 30-year window (distinct from the non-positive-savings message).

### Components

```
src/app/(authenticated)/fire/page.tsx            — Page component
src/components/fire/fire-inputs-form.tsx          — React Hook Form + Zod validation
src/components/fire/fire-projection-chart.tsx     — Recharts area chart with target lines
src/components/fire/fire-summary-cards.tsx        — Three stat cards
src/components/fire/fire-targets-table.tsx        — Lean/Regular/Fat comparison table
src/components/fire/fire-hero-headline.tsx        — Dynamic headline
src/lib/queries/use-fire.ts                      — React Query hooks (useFireProfile, useFireProjection, useSaveFireProfile)
src/types/api.ts                                 — Add FIRE-related TypeScript types
```

### Form Validation (Zod)

```typescript
const fireInputSchema = z.object({
  currentAge: z.number().int().min(18).max(100),
  annualIncome: z.number().min(0),
  annualExpenses: z.number().min(0),
  // No fixed min here — e.g. currentAge 18 allows target 19 via refine below (matches API).
  targetRetirementAge: z.number().int().max(100).nullable(),
}).refine(
  (data) => !data.targetRetirementAge || data.targetRetirementAge > data.currentAge,
  { message: "Target age must be greater than current age", path: ["targetRetirementAge"] }
);
```

---

## 5. File Changes Summary

### Backend (`VaultTrackerAPI/`)

| File | Action | Description |
|------|--------|-------------|
| `app/models/fire_profile.py` | Create | SQLAlchemy model for `fire_profiles` table |
| `app/models/__init__.py` | Edit | Import FIREProfile |
| `app/models/user.py` | Edit | Add `fire_profile` relationship |
| `app/schemas/fire.py` | Create | Pydantic schemas for input/response |
| `app/services/dashboard_aggregate.py` | Create | Shared aggregation for `GET /dashboard` (category totals, `totalNetWorth`, grouped holdings); `fire_service` uses the totals + net worth slice only |
| `app/services/fire_service.py` | Create | Calculation engine |
| `app/routers/dashboard.py` | Edit | Call `dashboard_aggregate` instead of inlining the asset loop |
| `app/routers/fire.py` | Create | FastAPI router with 3 endpoints (same layout as other resources) |
| `app/routers/__init__.py` | Edit | Export `fire_router` |
| `app/main.py` | Edit | Register fire router |
| `app/routers/users.py` | Edit | Add `FIREProfile` deletion to `DELETE /users/me/data` |
| `tests/test_fire.py` | Create | Unit + integration tests |

### Web (`VaultTrackerWeb/`)

| File | Action | Description |
|------|--------|-------------|
| `src/app/(authenticated)/fire/page.tsx` | Create | FIRE calculator page |
| `src/components/fire/fire-inputs-form.tsx` | Create | Input form |
| `src/components/fire/fire-projection-chart.tsx` | Create | Projection chart |
| `src/components/fire/fire-summary-cards.tsx` | Create | Summary stats |
| `src/components/fire/fire-targets-table.tsx` | Create | FIRE targets comparison |
| `src/components/fire/fire-hero-headline.tsx` | Create | Dynamic headline |
| `src/lib/queries/use-fire.ts` | Create | React Query hooks |
| `src/types/api.ts` | Edit | Add FIRE types |
| `src/components/layout/site-header.tsx` | Edit | Add FIRE Calc nav link |
| `src/components/layout/mobile-nav.tsx` | Edit | Add FIRE Calc mobile nav |
| `src/components/fire/__tests__/*.tsx` | Create | RTL tests for FIRE components (forms, conditional results UI) |
| `e2e/fire.spec.ts` | Create | Playwright UI flows for `/fire` (see §6) |

---

## 6. Testing Strategy

### Backend Tests (`tests/test_fire.py`)

**Unit tests (calculation functions):**
- Blended return calculation with various allocations
- FIRE target computation (Lean/Regular/Fat)
- Projection curve generation over 30 years
- Crossover year detection (found and not found)
- Goal assessment (ahead/on_track/behind)
- Edge cases: zero net worth, negative savings, 100% single asset class, empty portfolio, `beyond_horizon` status when no tier crosses within `PROJECTION_YEARS`

**Integration tests (API endpoints):**
- PUT profile → GET profile round-trip
- PUT profile validation (age out of range, target age < current age)
- GET projection with valid profile
- GET projection with no profile → 404
- GET projection with zero/negative savings → unreachable FIRE response
- GET projection with positive savings but no tier within `PROJECTION_YEARS` → `status: "beyond_horizon"`, non-empty curve, all tier timelines null

### Web — unit and hooks (Vitest)

- Form validation: `fireInputSchema` (Zod) in `src/lib/__tests__/` or next to schema
- React Query: `useFireProfile` / `useFireProjection` / `useSaveFireProfile` with mocked `ApiClient` (`src/lib/queries/__tests__/`)

### Web — UI component tests (Vitest + React Testing Library)

Use **Testing Library** (`@testing-library/react`, `user-event`) in `src/components/fire/__tests__/` to exercise visible behavior without a browser. Wrap with the same providers the page uses (e.g. `QueryClientProvider`, auth/api mocks).

Suggested cases:

- **Inputs form:** invalid target age shows validation message; submit calls save mutation with expected payload (mock `useMutation`).
- **Results region:** when projection query returns `status: "reachable"`, chart (or its container), summary cards, and targets table show expected labels/values from fixture data.
- **`unreachable`:** unreachable copy is shown; chart region hidden or replaced (match implementation).
- **`beyond_horizon`:** chart still present; distinct message or banner vs `unreachable` (assert copy / `role` / test id as appropriate).
- **Hero headline:** switches between success-style headline, beyond-horizon copy, and hidden/disabled state for `unreachable` (fixture-driven).

### Web — E2E UI tests (Playwright)

Add **`e2e/fire.spec.ts`** following [`VaultTrackerWeb/Documentation/Testing Plan.md`](../../VaultTrackerWeb/Documentation/Testing%20Plan.md): **Chromium**, `baseURL` localhost:3000, debug session via **client navigation** (not a cold `page.goto("/fire")` after login — same caveat as other e2e specs).

**Auth:** `debugLoginToDashboard` then navigate to FIRE via **header or mobile nav** link (`FIRE Calc` / `href="/fire"`), consistent with [`e2e/dashboard.spec.ts`](../../VaultTrackerWeb/e2e/dashboard.spec.ts).

**API strategy:**

- **Stubbed (recommended for CI):** `page.route` for `GET/PUT /api/v1/fire/profile` and `GET /api/v1/fire/projection` with JSON fixtures (`reachable`, `unreachable`, `beyond_horizon`) so tests do not require a running API or seeded portfolio. Optionally stub `GET /api/v1/dashboard` if the page fetches it separately for read-only net worth / allocation.
- **Integrated (optional local):** same flows against real `NEXT_PUBLIC_API_URL` + API with `DEBUG_AUTH_ENABLED` and seeded data — document as manual or nightly, not required for default CI.

**E2E scenarios (minimal set):**

1. After debug login, **FIRE Calc** nav opens `/fire` and shows the inputs form (heading or main landmark).
2. **Run Simulation** with stubs: profile PUT returns 200; projection GET returns `reachable` — assert a visible result (e.g. table row, stat text, or chart svg) tied to fixture values.
3. Stub **`unreachable`** — assert savings warning is visible and chart is not (per UI spec).
4. Stub **`beyond_horizon`** — assert chart (or projection area) visible and horizon-specific copy is present.

**Commands:** `npm run test:e2e` (or `npx playwright test e2e/fire.spec.ts` from `VaultTrackerWeb/`). Align with existing `playwright.config.ts` `webServer` / `reuseExistingServer` behavior.

### Manual Verification

1. Start API locally: `uvicorn app.main:app --reload`
2. Start web locally: `npm run dev`
3. Log in, navigate to `/fire`
4. Enter inputs, run simulation
5. Verify chart renders with correct crossover points
6. Verify values match manual calculation
7. Refresh page — verify auto-load works with saved profile
8. Test edge cases: zero income, expenses > income
9. Scenario with positive savings but no FIRE line crossed within 30 years → `beyond_horizon` messaging + chart still visible
10. From `VaultTrackerWeb/`: `npx playwright test e2e/fire.spec.ts` (or full `npm run test:e2e`) with app running or via Playwright `webServer`

---

## 7. Future Iterations (Not in MVP)

- Per-asset-class return rate overrides (user slider per category)
- Adjustable inflation rate input
- Monte Carlo simulation (probability distributions instead of fixed returns)
- Barista FIRE / Coast FIRE calculations
- Tax-advantaged vs taxable account distinction in projections
- Savings rate optimization suggestions
- iOS tab integration (consumes same API)
- Export projection as PDF
- Historical FIRE progress tracking (snapshot results over time)
