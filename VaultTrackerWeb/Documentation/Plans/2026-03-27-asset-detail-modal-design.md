# Asset Detail Modal — Design Spec

Date: 2026-03-27

## Context

Clicking an asset row in the Holdings grid currently does nothing. This spec adds a read-only detail modal that opens on click, surfacing per-asset aggregate metrics and recent transaction history that are not visible in the grid itself.

---

## Data Model

No API changes required. All data is derived from existing cached queries.

**Inputs (passed as props):**

- `HoldingItem` — `{ id, name, symbol, quantity, current_value }` — already available in the `HoldingsGrid` loop
- `category: Category` — available in the same loop

**Fetched internally:**

- `useTransactions()` — already cached; filtered client-side by `transaction.asset_id === holding.id`

**Computed client-side from filtered transactions:**

| Metric                | Derivation                                |
| --------------------- | ----------------------------------------- |
| Cost basis            | `Σ buy.total_value − Σ sell.total_value`  |
| Unrealized P&L ($)    | `current_value − costBasis`               |
| Unrealized P&L (%)    | `(unrealizedPnL / costBasis) × 100`       |
| Avg cost per unit     | `costBasis / quantity`                    |
| Last transaction date | `max(date)` across all asset transactions |
| Recent transactions   | Last 5 by date descending                 |

**Each recent transaction row shows:** date, type (buy/sell), quantity, price per unit, account name.

**Category-aware display:** Cash and Real Estate hide `Quantity`, `Avg Cost / Unit`, and `Unrealized P&L` (these use `price_per_unit = 1.0` where quantity = dollar amount, making those metrics meaningless). **Cash** also hides **Cost Basis** — for cash holdings, current value is treated as the primary figure. **Real estate** still shows **Cost Basis** alongside Current Value and Last Transaction.

---

## Components

### New file: `src/components/dashboard/asset-detail-dialog.tsx`

A read-only modal dialog. Props:

```ts
{
  holding: HoldingItem;
  category: Category;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}
```

Uses existing primitives: `Dialog`, `DialogContent`, `DialogHeader`, `DialogTitle` from `src/components/ui/dialog.tsx`.

Calls `useTransactions()` internally and filters by `holding.id`. Renders aggregate metrics and the last 5 transactions.

### Modified file: `src/components/dashboard/holdings-grid.tsx`

Two changes:

1. Each asset row `div` gets an `onClick` handler (or becomes a `button`) that sets `selectedHolding` state to the clicked `HoldingItem` + its `category`.
2. `<AssetDetailDialog>` rendered once at the bottom of the grid, controlled by `selectedHolding` state.

---

## Scope

- **Read-only** — no actions (no add transaction, no edit, no navigation)
- **No new API endpoints** — all data from existing queries
- **No new query hooks** — reuses `useTransactions` from `src/lib/queries/use-transactions.ts`
