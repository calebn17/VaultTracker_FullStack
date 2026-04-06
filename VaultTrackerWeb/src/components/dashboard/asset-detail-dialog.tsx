"use client";

import { useMemo } from "react";
import { format } from "date-fns";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import type { Category, HoldingItem, TransactionType } from "@/types/api";
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

const TRANSACTION_TYPE_LABELS: Record<TransactionType, string> = {
  buy: "Buy",
  sell: "Sell",
};

const SIMPLE_CATEGORIES: Category[] = ["cash", "realEstate"];

type Metric = { label: string; value: string; valueColor?: string };

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

  const metrics: Metric[] = [
    { label: "Current Value", value: formatCurrency(holding.current_value) },
    ...(!isSimple
      ? [
          {
            label: "Quantity",
            value: holding.quantity.toLocaleString(undefined, {
              maximumFractionDigits: 8,
            }),
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
          <div className="mb-1 flex items-center gap-3">
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

        <div className="mt-4 grid grid-cols-2 gap-3">
          {metrics.map(({ label, value, valueColor }) => (
            <div key={label} className="bg-secondary rounded-lg px-4 py-3">
              <p className="text-muted-foreground mb-1 text-[10px] tracking-[0.1em] uppercase">
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

        {recentTransactions.length > 0 && (
          <div className="mt-5">
            <p className="text-muted-foreground mb-2 text-[10px] tracking-[0.1em] uppercase">
              Recent Transactions
            </p>
            <div className="overflow-hidden rounded-xl border">
              <table className="w-full text-[12px]">
                <thead>
                  <tr className="bg-secondary/80 border-b">
                    <th className="text-muted-foreground px-3 py-2 text-left font-medium">Date</th>
                    <th className="text-muted-foreground px-3 py-2 text-left font-medium">Type</th>
                    <th className="text-muted-foreground px-3 py-2 text-right font-medium">Qty</th>
                    <th className="text-muted-foreground px-3 py-2 text-right font-medium">
                      Price
                    </th>
                    <th className="text-muted-foreground px-3 py-2 text-right font-medium">
                      Account
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {recentTransactions.map((t) => (
                    <tr key={t.id} className="border-b last:border-0">
                      <td className="text-muted-foreground px-3 py-2">
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
                      <td className="text-foreground px-3 py-2 text-right tabular-nums">
                        {t.quantity.toLocaleString(undefined, {
                          maximumFractionDigits: 8,
                        })}
                      </td>
                      <td className="text-foreground px-3 py-2 text-right tabular-nums">
                        {formatCurrency(t.price_per_unit)}
                      </td>
                      <td className="text-muted-foreground px-3 py-2 text-right">
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
