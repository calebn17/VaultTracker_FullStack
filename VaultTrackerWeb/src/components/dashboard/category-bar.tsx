"use client";

import type { Category, CategoryTotals } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";

const ORDER: Category[] = [
  "crypto",
  "stocks",
  "cash",
  "realEstate",
  "retirement",
];

const COLORS: Record<Category, string> = {
  crypto: "bg-chart-1",
  stocks: "bg-chart-2",
  cash: "bg-chart-3",
  realEstate: "bg-chart-4",
  retirement: "bg-chart-5",
};

const LABELS: Record<Category, string> = {
  crypto: "Crypto",
  stocks: "Stocks",
  cash: "Cash",
  realEstate: "Real estate",
  retirement: "Retirement",
};

export function CategoryBar({
  totals,
  total,
  loading,
}: {
  totals: CategoryTotals | undefined;
  total: number;
  loading?: boolean;
}) {
  if (loading || !totals) {
    return (
      <div className="bg-muted h-4 w-full overflow-hidden rounded-full">
        <div className="bg-muted-foreground/20 h-full w-full animate-pulse" />
      </div>
    );
  }

  return (
    <div>
      <div className="flex h-4 w-full overflow-hidden rounded-full">
        {ORDER.map((key) => {
          const v = totals[key];
          const pct = total > 0 ? (v / total) * 100 : 0;
          if (pct <= 0) return null;
          return (
            <div
              key={key}
              className={cn(COLORS[key], "h-full min-w-0 transition-all")}
              style={{ width: `${pct}%` }}
              title={`${LABELS[key]}: ${formatCurrency(v)}`}
            />
          );
        })}
      </div>
      <div className="mt-2 flex flex-wrap gap-3 text-xs">
        {ORDER.map((key) => (
          <span key={key} className="text-muted-foreground flex items-center gap-1">
            <span className={cn("size-2 rounded-full", COLORS[key])} />
            {LABELS[key]}: {formatCurrency(totals[key])}
          </span>
        ))}
      </div>
    </div>
  );
}
