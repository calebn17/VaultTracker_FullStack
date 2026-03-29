# Analytics Page Redesign — "Onyx Wealth" Bento Grid

## Context

The current Analytics/Charts page (`/analytics`) has a basic vertical layout with 4 sections: allocation donut, performance card, net worth trend chart, and price lookup. The goal is to redesign it into a premium bento-grid layout inspired by the "Onyx Wealth" Assets tab reference (`VaultTrackerWeb/Documentation/References/VaultTracker_Web_AssetsTab/`), showing assets grouped by category in visually distinct cards.

**Key constraint:** Only implement features backed by existing API data. The reference shows UI elements (Export Report, 24h change per asset, APY, Transfer button, property types, per-asset sparklines) that don't exist in the backend — these are all **ignored**.

## Data Sources (all existing, no new API calls)

| Hook | Data Used |
|------|-----------|
| `useDashboard()` | `totalNetWorth`, `categoryTotals`, `groupedHoldings` (Record\<string, HoldingItem[]\>) |
| `useAnalytics()` | `allocation` (per-category percentages), `performance` (gain/loss, cost basis, current value) |
| `useNetWorthHistory("daily")` | For `computeApproxMonthChange` (hero trailing change) |
| `useNetWorthHistory(period)` | For net worth trend chart |
| `usePriceLookup(symbol)` | Price lookup utility (kept as-is) |

**New for this page:** `useDashboard()` is not currently called on the analytics page but is needed for `groupedHoldings` and `categoryTotals`. React Query deduplicates if the user visited dashboard first.

## Page Layout

```
┌─────────────────────────────────────────────────┐
│  TOTAL PORTFOLIO                                │
│  $XXX,XXX.XX         [trailing ±X.X% badge]    │
│  last ~30 days: ±$X,XXX                        │
├─────────────────────┬───────────────────────────┤
│  Stocks & ETFs      │  Digital Assets (Crypto)  │
│  (col-span-7)       │  (col-span-5)             │
│  Table: name,qty,   │  Vertical list with       │
│  value              │  icon badges + values     │
├─────────────────────┴──┬────────────────────────┤
│  Real Estate           │  Cash & Liquidity       │
│  (col-span-8)          │  (col-span-4, inverted  │
│  Property-style list   │   lime bg)              │
├────────────────────────┴────────────────────────┤
│  Retirement (col-span-6)  │  Net Worth Chart     │
│  Vertical list            │  (col-span-6)        │
│                           │  with period selector │
├───────────────────────────┴─────────────────────┤
│  PERFORMANCE SUMMARY                            │
│  Gain/Loss  │  Cost Basis  │  Current Value     │
├─────────────────────────────────────────────────┤
│  Price Lookup (kept, restyled to match)         │
└─────────────────────────────────────────────────┘
```

Mobile: All cards stack to full-width (`col-span-12`).

## New Files

All under `src/components/analytics/`:

### 1. `portfolio-hero.tsx`
- Props: `totalNetWorth`, `monthChange: {absolute, percent} | null`, `loading`
- "TOTAL PORTFOLIO" label: `text-primary text-[10px] uppercase tracking-[0.14em]`
- Value: `font-heading text-5xl md:text-[56px] font-bold tabular-nums tracking-tight`
- Growth badge: pill with trend icon, green/red based on sign
- Pattern: mirrors dashboard hero (lines 91-132) with different label text

### 2. `category-bento-card.tsx` — Single component handling all 5 categories
Rather than 5 separate card files, one component with variant rendering based on `category` prop. This avoids file proliferation since the structure is similar.

```typescript
interface CategoryBentoCardProps {
  category: Category;
  holdings: HoldingItem[];
  totalValue: number;           // from categoryTotals
  allocationPercent: number;    // from analytics.allocation
  totalNetWorth: number;
  onSelectHolding: (holding: HoldingItem, category: Category) => void;
  loading: boolean;
}
```

**Category-specific rendering:**
- **stocks**: Table layout (3 cols: Asset, Qty/Units, Value). Blue accent `#64c8f5`. Icon uses show_chart-style badge.
- **crypto**: Compact vertical list with colored icon dots + name + value. Orange accent `#f5a864`.
- **realEstate**: Property-style rows (name prominent, value right-aligned). Lime accent `#c8f564`.
- **cash**: **Inverted** — `bg-primary text-primary-foreground`. Large total value centered. Beige accent `#e8e0c8`.
- **retirement**: Vertical list similar to crypto. Purple accent `#a89cf5`.

All rows are clickable → calls `onSelectHolding` to open `AssetDetailDialog`.

Empty state per card: subtle message "No holdings yet" with reduced opacity.

### 3. `performance-attribution.tsx`
- Props: `performance: AnalyticsResponse["performance"] | undefined`, `loading`
- Header: "PERFORMANCE SUMMARY" uppercase micro-label
- 3-column grid of metric tiles:
  - Total Gain/Loss (value + percent, colored)
  - Cost Basis (neutral)
  - Current Value (neutral)
- Styled as `bg-secondary rounded-xl p-5` tiles

## Files to Modify

### `src/app/(authenticated)/analytics/page.tsx` — Full rewrite
- Calls `useDashboard()` (new), `useAnalytics()`, `useNetWorthHistory` (×2), `usePriceLookup`
- Computes `monthChange` via `computeApproxMonthChange` (import from `@/lib/networth-change`)
- Manages `selectedHolding` state for `AssetDetailDialog`
- Renders: PortfolioHero → 12-col bento grid with CategoryBentoCards + NetWorthChart → PerformanceAttribution → PriceLookup → AssetDetailDialog
- Keeps the existing period selector for net worth chart (inlined in the chart's grid cell)

### `src/components/dashboard/holdings-grid.tsx` — Minor edit
- Export the `AssetIcon` component (add `export` keyword) so bento cards can reuse it

## Styling Approach

- All colors from existing `MERIDIAN_CATEGORY_HEX` and CSS variables (no new tokens)
- Fonts: `font-heading` for titles/values, default mono for data
- Cards: `bg-card rounded-2xl border border-border p-6` (standard), `hover:border-foreground/15 transition-colors`
- Cash card inverted: `bg-primary text-primary-foreground rounded-2xl p-6`
- Micro-labels: `text-[10px] tracking-[0.1em] uppercase text-muted-foreground`
- Values: `tabular-nums` always on financial figures
- No new CSS variables or globals.css changes needed

## Grid Column Assignments

```
Row 1: stocks(7) + crypto(5) = 12
Row 2: realEstate(8) + cash(4) = 12
Row 3: retirement(6) + netWorthChart(6) = 12
```

## Implementation Steps

1. Export `AssetIcon` from `holdings-grid.tsx`
2. Create `src/components/analytics/portfolio-hero.tsx`
3. Create `src/components/analytics/category-bento-card.tsx`
4. Create `src/components/analytics/performance-attribution.tsx`
5. Rewrite `src/app/(authenticated)/analytics/page.tsx`
6. Visual verification — run `npm run dev`, navigate to `/analytics`, verify:
   - Hero shows total net worth and trailing change
   - All 5 category cards render with correct holdings
   - Clicking a holding opens AssetDetailDialog
   - Cash card has inverted lime styling
   - Net worth chart renders with period selector
   - Performance summary shows gain/loss, cost basis, current value
   - Price lookup still works
   - Mobile responsive (cards stack)
   - Empty categories show graceful empty state
7. Run `npm run build` to verify no type errors
8. Run `npm run test` to verify existing tests pass

## Design Reference Files

- `VaultTrackerWeb/Documentation/References/VaultTracker_Web_AssetsTab/screen.png` — Target screenshot
- `VaultTrackerWeb/Documentation/References/VaultTracker_Web_AssetsTab/DESIGN.md` — Design system spec
- `VaultTrackerWeb/Documentation/References/VaultTracker_Web_AssetsTab/code.html` — HTML/Tailwind reference implementation
