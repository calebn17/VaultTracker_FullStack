"use client";

import type { Category, CategoryTotals } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { CATEGORY_LABELS, CATEGORY_ORDER } from "@/components/dashboard/category-bar";

/** Meridian reference palette (networth-tracker.html) */
export const MERIDIAN_CATEGORY_HEX: Record<Category, string> = {
  crypto: "#f5a864",
  stocks: "#64c8f5",
  cash: "#e8e0c8",
  realEstate: "#c8f564",
  retirement: "#a89cf5",
};

export function CategorySummaryList({
  totals,
  total: totalProp,
  loading,
}: {
  totals: CategoryTotals | undefined;
  /** Defaults to sum of category totals */
  total?: number;
  loading?: boolean;
}) {
  const total = totalProp ?? (totals ? CATEGORY_ORDER.reduce((s, k) => s + totals[k], 0) : 0);
  if (loading || !totals) {
    return (
      <div className="flex flex-col gap-3.5">
        {CATEGORY_ORDER.map((key) => (
          <div key={key} className="flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="bg-muted flex items-center gap-2">
                <span className="bg-muted size-2 animate-pulse rounded-full" />
                <span className="bg-muted h-3 w-16 animate-pulse rounded" />
              </span>
              <span className="bg-muted h-3 w-10 animate-pulse rounded" />
            </div>
            <div className="bg-muted h-1 animate-pulse rounded-full" />
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3.5">
      {CATEGORY_ORDER.map((key) => {
        const val = totals[key];
        const pct = total > 0 ? (val / total) * 100 : 0;
        const color = MERIDIAN_CATEGORY_HEX[key];
        return (
          <div key={key} className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-xs text-foreground">
                <span
                  className="size-2 shrink-0 rounded-full"
                  style={{ background: color }}
                  aria-hidden
                />
                {CATEGORY_LABELS[key]}
              </div>
              <span className="text-muted-foreground text-xs tabular-nums">{pct.toFixed(1)}%</span>
            </div>
            <div className="bg-secondary h-1 overflow-hidden rounded-full">
              <div
                className="h-full rounded-full transition-[width] duration-1000 ease-out"
                style={{
                  width: `${Math.min(100, pct)}%`,
                  background: color,
                }}
              />
            </div>
            <div className="text-muted-foreground text-right text-[11px] tabular-nums">
              {formatCurrency(val)}
            </div>
          </div>
        );
      })}
    </div>
  );
}
