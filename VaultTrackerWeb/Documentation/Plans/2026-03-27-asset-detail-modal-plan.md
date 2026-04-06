# Asset Detail Modal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only modal that opens when clicking an asset row in the Holdings grid, showing aggregate metrics (cost basis, P&L, avg cost, last transaction date) and the 5 most recent transactions.

**Architecture:** A new `AssetDetailDialog` component receives a `HoldingItem` + `category` as props and internally calls the already-cached `useTransactions()` hook, filtering client-side by `asset_id`. `HoldingsGrid` gains a `selectedHolding` state and renders the dialog. No API changes required.

**Tech Stack:** Next.js 15 App Router, TypeScript, Tailwind CSS, TanStack React Query v5, Vitest + React Testing Library, date-fns

**Category-aware metrics:** Cash and Real Estate hide `Quantity`, `Avg Cost / Unit`, and `Unrealized P&L` since those categories use `price_per_unit = 1.0` and quantity = dollar amount, making those metrics meaningless. **Cash** also hides **Cost Basis** (current value is the meaningful summary). **Real estate** shows **Cost Basis** plus Current Value and Last Transaction.

---

## Execution discipline (`.cursor/rules/vaulttracker-plan-todos.mdc`)

- **One todo = one commit** — Each item below is a single logical commit; wording maps to the suggested commit subject.
- **Stop for review** — After each commit, pause: summarize what changed and wait for the user before the next item. **Exception:** batch only if the user explicitly asks to skip review, batch, or “do the rest.”

### Committable todos (in order)

1. **`feat(dashboard): add AssetDetailDialog with cost basis and recent transactions`** — Create `src/components/dashboard/asset-detail-dialog.tsx` and `src/components/__tests__/asset-detail-dialog.test.tsx` (TDD). Add `@testing-library/user-event` as a devDependency here if `npm ls` shows it missing (required for todo 2).

2. **`feat(dashboard): open AssetDetailDialog on asset row click`** — Update `src/components/dashboard/holdings-grid.tsx` and extend the test file with the HoldingsGrid describe block.

3. **`docs(web): note asset detail modal in CLAUDE.md`** — After the user confirms the feature or asks for documentation/commits: one short bullet in `VaultTrackerWeb/CLAUDE.md` (repo root) per `.cursor/rules/vaulttracker-claude-sync.mdc`.

---

## File Map

| Action | Path                                                    | Responsibility                |
| ------ | ------------------------------------------------------- | ----------------------------- |
| Create | `src/components/dashboard/asset-detail-dialog.tsx`      | Modal UI + metric computation |
| Modify | `src/components/dashboard/holdings-grid.tsx`            | Click state + dialog render   |
| Create | `src/components/__tests__/asset-detail-dialog.test.tsx` | Component tests               |

---

## Task 1: Build `AssetDetailDialog` (TDD)

**Files:**

- Create: `src/components/dashboard/asset-detail-dialog.tsx`
- Create: `src/components/__tests__/asset-detail-dialog.test.tsx`

- [ ] **Step 1: Write the failing tests**

Create `src/components/__tests__/asset-detail-dialog.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, it, expect, vi, beforeEach } from "vitest";
import type { EnrichedTransaction } from "@/types/api";

vi.mock("@/lib/queries/use-transactions", () => ({
  useTransactions: vi.fn(),
}));

import { useTransactions } from "@/lib/queries/use-transactions";
import { AssetDetailDialog } from "@/components/dashboard/asset-detail-dialog";

const mockHolding = {
  id: "asset-1",
  name: "Bitcoin",
  symbol: "BTC",
  quantity: 0.5,
  current_value: 30000,
};

const mockCashHolding = {
  id: "asset-cash",
  name: "Chase Checking",
  symbol: null,
  quantity: 18000,
  current_value: 18000,
};

const mockTransactions: EnrichedTransaction[] = [
  {
    id: "tx-1",
    user_id: "u1",
    asset_id: "asset-1",
    account_id: "acc-1",
    transaction_type: "buy",
    quantity: 0.6,
    price_per_unit: 40000,
    total_value: 24000,
    date: "2024-01-01T00:00:00Z",
    asset: { id: "asset-1", name: "Bitcoin", symbol: "BTC", category: "crypto" },
    account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  {
    id: "tx-2",
    user_id: "u1",
    asset_id: "asset-1",
    account_id: "acc-1",
    transaction_type: "sell",
    quantity: 0.1,
    price_per_unit: 45000,
    total_value: 4500,
    date: "2024-06-01T00:00:00Z",
    asset: { id: "asset-1", name: "Bitcoin", symbol: "BTC", category: "crypto" },
    account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  // Unrelated asset — must be excluded
  {
    id: "tx-3",
    user_id: "u1",
    asset_id: "asset-99",
    account_id: "acc-1",
    transaction_type: "buy",
    quantity: 10,
    price_per_unit: 100,
    total_value: 1000,
    date: "2024-03-01T00:00:00Z",
    asset: { id: "asset-99", name: "Ethereum", symbol: "ETH", category: "crypto" },
    account: { id: "acc-1", name: "Coinbase", account_type: "cryptoExchange" },
  },
  {
    id: "tx-4",
    user_id: "u1",
    asset_id: "asset-cash",
    account_id: "acc-2",
    transaction_type: "buy",
    quantity: 18000,
    price_per_unit: 1,
    total_value: 18000,
    date: "2024-02-01T00:00:00Z",
    asset: { id: "asset-cash", name: "Chase Checking", symbol: null, category: "cash" },
    account: { id: "acc-2", name: "Chase", account_type: "bank" },
  },
];

describe("AssetDetailDialog", () => {
  beforeEach(() => {
    vi.mocked(useTransactions).mockReturnValue({
      data: mockTransactions,
      isLoading: false,
    } as ReturnType<typeof useTransactions>);
  });

  it("renders the asset name in the title", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getByText("Bitcoin")).toBeInTheDocument();
  });

  it("computes and displays cost basis correctly", () => {
    // costBasis = 24000 (buy) - 4500 (sell) = 19500
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getByText("$19,500.00")).toBeInTheDocument();
  });

  it("computes and displays unrealized P&L correctly", () => {
    // unrealizedPnL = 30000 - 19500 = 10500
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getByText("$10,500.00")).toBeInTheDocument();
  });

  it("shows only transactions for this asset", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getAllByRole("row").length).toBe(3); // header + 2 rows (asset-1 only)
  });

  it("shows account name in transaction rows", () => {
    render(
      <AssetDetailDialog
        holding={mockHolding}
        category="crypto"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.getAllByText("Coinbase").length).toBeGreaterThan(0);
  });

  it("hides quantity, avg cost, P&L, and cost basis for cash category", () => {
    render(
      <AssetDetailDialog
        holding={mockCashHolding}
        category="cash"
        open={true}
        onOpenChange={() => {}}
      />
    );
    expect(screen.queryByText("Quantity")).not.toBeInTheDocument();
    expect(screen.queryByText("Avg Cost / Unit")).not.toBeInTheDocument();
    expect(screen.queryByText("Unrealized P&L")).not.toBeInTheDocument();
    expect(screen.queryByText("Cost Basis")).not.toBeInTheDocument();
    expect(screen.getByText("Current Value")).toBeInTheDocument();
    expect(screen.getByText("Last Transaction")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
cd VaultTrackerWeb && npm run test -- asset-detail-dialog
```

Expected: multiple failures — `AssetDetailDialog` does not exist yet.

- [ ] **Step 3: Verify `@testing-library/user-event` is installed**

```bash
cd VaultTrackerWeb && npm ls @testing-library/user-event
```

If not installed, run `npm install -D @testing-library/user-event`.

- [ ] **Step 4: Implement `AssetDetailDialog`**

Create `src/components/dashboard/asset-detail-dialog.tsx`:

```tsx
"use client";

import { useMemo } from "react";
import { format } from "date-fns";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import type { Category, HoldingItem } from "@/types/api";
import { useTransactions } from "@/lib/queries/use-transactions";
import { formatCurrency } from "@/lib/format";
import { MERIDIAN_CATEGORY_HEX } from "@/components/dashboard/category-summary-list";

const CATEGORY_LABELS: Record<Category, string> = {
  crypto: "Crypto",
  stocks: "Stocks",
  cash: "Cash",
  realEstate: "Real Estate",
  retirement: "Retirement",
};

const TRANSACTION_TYPE_LABELS: Record<string, string> = {
  buy: "Buy",
  sell: "Sell",
};

const SIMPLE_CATEGORIES: Category[] = ["cash", "realEstate"];

export function AssetDetailDialog({
  holding,
  category,
  open,
  onOpenChange,
}: {
  holding: HoldingItem;
  category: Category;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const { data: transactions } = useTransactions();
  const color = MERIDIAN_CATEGORY_HEX[category];
  const isSimple = SIMPLE_CATEGORIES.includes(category);

  const {
    costBasis,
    unrealizedPnL,
    unrealizedPnLPct,
    avgCostPerUnit,
    lastDate,
    recentTransactions,
  } = useMemo(() => {
    const filtered = (transactions ?? []).filter((t) => t.asset_id === holding.id);
    const sorted = [...filtered].sort(
      (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
    );

    const costBasis = filtered.reduce(
      (sum, t) => (t.transaction_type === "buy" ? sum + t.total_value : sum - t.total_value),
      0
    );
    const unrealizedPnL = holding.current_value - costBasis;
    const unrealizedPnLPct = costBasis > 0 ? (unrealizedPnL / costBasis) * 100 : 0;
    const avgCostPerUnit = holding.quantity > 0 ? costBasis / holding.quantity : 0;
    const lastDate = sorted[0]?.date ?? null;

    return {
      costBasis,
      unrealizedPnL,
      unrealizedPnLPct,
      avgCostPerUnit,
      lastDate,
      recentTransactions: sorted.slice(0, 5),
    };
  }, [transactions, holding]);

  const pnlPositive = unrealizedPnL >= 0;

  const metrics = [
    { label: "Current Value", value: formatCurrency(holding.current_value) },
    ...(!isSimple
      ? [
          {
            label: "Quantity",
            value: holding.quantity.toLocaleString(undefined, { maximumFractionDigits: 8 }),
          },
        ]
      : []),
    ...(category !== "cash" ? [{ label: "Cost Basis", value: formatCurrency(costBasis) }] : []),
    ...(!isSimple
      ? [
          { label: "Avg Cost / Unit", value: formatCurrency(avgCostPerUnit) },
          {
            label: "Unrealized P&L",
            value: `${pnlPositive ? "+" : ""}${formatCurrency(unrealizedPnL)} (${pnlPositive ? "+" : ""}${unrealizedPnLPct.toFixed(2)}%)`,
            valueColor: pnlPositive ? "text-emerald-400" : "text-red-400",
          },
        ]
      : []),
    {
      label: "Last Transaction",
      value: lastDate ? format(new Date(lastDate), "MMM d, yyyy") : "—",
    },
  ];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        overlayClassName="bg-black/70 supports-backdrop-filter:backdrop-blur-md"
        className="sm:max-w-[480px] rounded-[20px] p-8 shadow-[0_40px_80px_rgba(0,0,0,0.6)]"
      >
        <DialogHeader>
          <div className="flex items-center gap-3 mb-1">
            <span
              className="flex size-10 shrink-0 items-center justify-center rounded-lg text-[11px] font-bold tracking-wide"
              style={{
                background: `${color}18`,
                color,
                fontFamily: "var(--font-meridian-syne), system-ui, sans-serif",
              }}
            >
              {(holding.symbol?.trim() || holding.name).slice(0, 3).toUpperCase()}
            </span>
            <div>
              <DialogTitle className="font-serif text-[22px] font-normal leading-tight">
                {holding.name}
              </DialogTitle>
              <p className="text-muted-foreground text-[11px] uppercase tracking-[0.08em]">
                {holding.symbol ?? CATEGORY_LABELS[category]}
              </p>
            </div>
          </div>
        </DialogHeader>

        {/* Aggregate metrics */}
        <div className="grid grid-cols-2 gap-3 mt-4">
          {metrics.map(({ label, value, valueColor }) => (
            <div key={label} className="bg-secondary rounded-lg px-4 py-3">
              <p className="text-muted-foreground text-[10px] uppercase tracking-[0.1em] mb-1">
                {label}
              </p>
              <p
                className={`text-[13px] font-medium tabular-nums ${valueColor ?? "text-foreground"}`}
              >
                {value}
              </p>
            </div>
          ))}
        </div>

        {/* Recent transactions */}
        {recentTransactions.length > 0 && (
          <div className="mt-5">
            <p className="text-muted-foreground text-[10px] uppercase tracking-[0.1em] mb-2">
              Recent Transactions
            </p>
            <div className="border rounded-xl overflow-hidden">
              <table className="w-full text-[12px]">
                <thead>
                  <tr className="border-b bg-secondary/80">
                    <th className="text-left text-muted-foreground font-medium px-3 py-2">Date</th>
                    <th className="text-left text-muted-foreground font-medium px-3 py-2">Type</th>
                    <th className="text-right text-muted-foreground font-medium px-3 py-2">Qty</th>
                    <th className="text-right text-muted-foreground font-medium px-3 py-2">
                      Price
                    </th>
                    <th className="text-right text-muted-foreground font-medium px-3 py-2">
                      Account
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {recentTransactions.map((t) => (
                    <tr key={t.id} className="border-b last:border-0">
                      <td className="px-3 py-2 text-muted-foreground">
                        {format(new Date(t.date), "MMM d, yy")}
                      </td>
                      <td className="px-3 py-2">
                        <span
                          className={
                            t.transaction_type === "buy" ? "text-emerald-400" : "text-red-400"
                          }
                        >
                          {TRANSACTION_TYPE_LABELS[t.transaction_type]}
                        </span>
                      </td>
                      <td className="px-3 py-2 text-right tabular-nums text-foreground">
                        {t.quantity.toLocaleString(undefined, { maximumFractionDigits: 8 })}
                      </td>
                      <td className="px-3 py-2 text-right tabular-nums text-foreground">
                        {formatCurrency(t.price_per_unit)}
                      </td>
                      <td className="px-3 py-2 text-right text-muted-foreground">
                        {t.account.name}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
```

- [ ] **Step 5: Run tests — confirm they pass**

```bash
cd VaultTrackerWeb && npm run test -- asset-detail-dialog
```

Expected: all 6 tests pass.

- [ ] **Step 6: Commit**

```bash
cd VaultTrackerWeb && git add src/components/dashboard/asset-detail-dialog.tsx src/components/__tests__/asset-detail-dialog.test.tsx
git commit -m "feat(dashboard): add AssetDetailDialog with cost basis and recent transactions"
```

---

## Task 2: Wire click handler into `HoldingsGrid`

**Files:**

- Modify: `src/components/dashboard/holdings-grid.tsx`
- Modify: `src/components/__tests__/asset-detail-dialog.test.tsx`

- [ ] **Step 1: Write a failing test for click behavior**

Add these imports at the top of `src/components/__tests__/asset-detail-dialog.test.tsx`:

```tsx
import userEvent from "@testing-library/user-event";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";
```

Append a new describe block at the bottom of the file:

```tsx
describe("HoldingsGrid click behavior", () => {
  beforeEach(() => {
    vi.mocked(useTransactions).mockReturnValue({
      data: mockTransactions,
      isLoading: false,
    } as ReturnType<typeof useTransactions>);
  });

  it("opens AssetDetailDialog when an asset row is clicked", async () => {
    const user = userEvent.setup();
    const grouped = {
      crypto: [
        { id: "asset-1", name: "Bitcoin", symbol: "BTC", quantity: 0.5, current_value: 30000 },
      ],
    } as Record<string, import("@/types/api").HoldingItem[]>;

    render(<HoldingsGrid grouped={grouped} totalNetWorth={30000} />);

    await user.click(screen.getByText("Bitcoin"));
    expect(screen.getAllByText("Bitcoin").length).toBeGreaterThan(1);
  });
});
```

- [ ] **Step 2: Run test — confirm it fails**

```bash
cd VaultTrackerWeb && npm run test -- asset-detail-dialog
```

Expected: FAIL — clicking Bitcoin does nothing yet.

- [ ] **Step 3: Modify `HoldingsGrid` to add click state and render dialog**

In `src/components/dashboard/holdings-grid.tsx`, make the following changes:

1. Add import at the top:

```tsx
import { AssetDetailDialog } from "@/components/dashboard/asset-detail-dialog";
```

2. Inside the `HoldingsGrid` function, add state after the existing `open` state:

```tsx
const [selectedHolding, setSelectedHolding] = useState<{
  holding: HoldingItem;
  category: Category;
} | null>(null);
```

3. Replace the asset row `div` (currently at line ~190) with a `button`:

```tsx
<button
  key={h.id}
  type="button"
  onClick={() => setSelectedHolding({ holding: h, category: cat })}
  className={cn(
    tableGrid,
    "w-full text-left border-border hover:bg-foreground/[0.05] border-b px-5 py-3.5 text-sm last:border-0 cursor-pointer transition-colors"
  )}
>
  {/* inner content unchanged */}
</button>
```

4. Add the dialog just before the closing `</div>` of the outer wrapper:

```tsx
{
  selectedHolding && (
    <AssetDetailDialog
      holding={selectedHolding.holding}
      category={selectedHolding.category}
      open
      onOpenChange={(isOpen) => {
        if (!isOpen) setSelectedHolding(null);
      }}
    />
  );
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
cd VaultTrackerWeb && npm run test -- asset-detail-dialog
```

Expected: all tests pass.

- [ ] **Step 5: Manual smoke test**

```bash
cd VaultTrackerWeb && npm run dev
```

Open `http://localhost:3000/dashboard`. Click any asset row — the detail modal should open with correct metrics and recent transactions. Close it with the X or by clicking the overlay. Verify that cash and real estate do not show Quantity, Avg Cost / Unit, or Unrealized P&L; **cash** should also omit Cost Basis; **real estate** should still show Cost Basis.

- [ ] **Step 6: Commit**

```bash
cd VaultTrackerWeb && git add src/components/dashboard/holdings-grid.tsx src/components/__tests__/asset-detail-dialog.test.tsx
git commit -m "feat(dashboard): open AssetDetailDialog on asset row click"
```
