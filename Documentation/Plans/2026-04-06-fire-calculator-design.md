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
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users, unique | One profile per user |
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
- `"reachable"` — annual savings > 0; at least one FIRE tier is reachable within `PROJECTION_YEARS`. Individual tiers that are not reached within the window have `yearsToTarget: null` and `targetAge: null`.
- `"unreachable"` — annual savings ≤ 0; no tier is computable. Web should replace the chart with the unreachable copy.

**`unreachableReason` values:** `null` (reachable) | `"non_positive_savings"` (income ≤ expenses).

`monthlyBreakdown.monthsToFire` is months to **Regular FIRE** specifically (25 × annual expenses), not the minimum across tiers. It is `null` when status is `"unreachable"` or Regular FIRE is not reached within `PROJECTION_YEARS`.

`goalAssessment` is `null` when `targetRetirementAge` is not set, or when status is `"unreachable"`.

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
- Input: `{category: {value, percentage}}` from dashboard data
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
- Only computed when `target_retirement_age` is set and status is `"reachable"`
- Checks projected value at goal age vs Regular FIRE target
- `status`: "ahead" if projected > target, "on_track" if within 5%, "behind" otherwise
- `gapAmount`: target − projected at goal age (negative means surplus)
- `requiredSavingsRate`: solved via binary search on annual savings (bounds: 0 to `annualIncome`). For each candidate savings, run the same discrete yearly recursion — `V_{n+1} = V_n × (1 + real_return) + savings` — over `(target_retirement_age − current_age)` years starting from current net worth. Find the smallest annual savings where `V` at goal age ≥ Regular FIRE target. Express result as `requiredAnnualSavings / annualIncome`. Terminate search when interval is < $1.

**`get_projection(user_id, db) -> FIREProjectionResponse`**
- Orchestrator: fetches profile + dashboard data, runs all calculations, assembles response

### Edge Cases

- **Zero net worth:** Valid — projection starts from 0, driven by savings alone
- **100% cash allocation:** Blended return = 2% nominal, −1% real. FIRE takes much longer.
- **Expenses ≥ income:** Annual savings ≤ 0. Return `status: "unreachable"`, `unreachableReason: "non_positive_savings"`, all tier `yearsToTarget`/`targetAge` as `null`, empty `projectionCurve`, and `monthsToFire: null`
- **No assets in portfolio:** Use 0 for net worth, skip allocation breakdown, use a default 7% blended return
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
- Hero headline: "You can achieve Financial Independence in **X YEARS** by age **Y**" (updates dynamically from projection results)
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
4. **Unreachable FIRE:** If savings rate is zero or negative, show a message instead of the chart: "At your current savings rate, FIRE is not achievable. Consider reducing expenses or increasing income."

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
  targetRetirementAge: z.number().int().min(19).max(100).nullable(),
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
| `app/services/fire_service.py` | Create | Calculation engine |
| `app/api/fire.py` | Create | FastAPI router with 3 endpoints |
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

---

## 6. Testing Strategy

### Backend Tests (`tests/test_fire.py`)

**Unit tests (calculation functions):**
- Blended return calculation with various allocations
- FIRE target computation (Lean/Regular/Fat)
- Projection curve generation over 30 years
- Crossover year detection (found and not found)
- Goal assessment (ahead/on_track/behind)
- Edge cases: zero net worth, negative savings, 100% single asset class, empty portfolio

**Integration tests (API endpoints):**
- PUT profile → GET profile round-trip
- PUT profile validation (age out of range, target age < current age)
- GET projection with valid profile
- GET projection with no profile → 404
- GET projection with zero/negative savings → unreachable FIRE response

### Web Tests

- Form validation (Zod schema) via Vitest
- React Query hook behavior (mock API responses)
- Component rendering with projection data

### Manual Verification

1. Start API locally: `uvicorn app.main:app --reload`
2. Start web locally: `npm run dev`
3. Log in, navigate to `/fire`
4. Enter inputs, run simulation
5. Verify chart renders with correct crossover points
6. Verify values match manual calculation
7. Refresh page — verify auto-load works with saved profile
8. Test edge cases: zero income, expenses > income

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
