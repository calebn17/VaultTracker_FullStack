"use client";

import type { CategoryTotals } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";
import { CATEGORY_LABELS, CATEGORY_ORDER } from "@/components/dashboard/category-bar";

export function CategorySummaryList({
  totals,
  loading,
}: {
  totals: CategoryTotals | undefined;
  loading?: boolean;
}) {
  if (loading || !totals) {
    return (
      <ul className="space-y-2">
        {CATEGORY_ORDER.map((key) => (
          <li
            key={key}
            className="flex items-center justify-between gap-3 text-sm"
          >
            <span className="bg-muted h-4 w-20 animate-pulse rounded" />
            <span className="bg-muted h-4 w-24 animate-pulse rounded" />
          </li>
        ))}
      </ul>
    );
  }

  return (
    <ul className="space-y-2">
      {CATEGORY_ORDER.map((key) => (
        <li
          key={key}
          className={cn(
            "flex items-baseline justify-between gap-3 border-b border-border/60 pb-2 text-sm last:border-0 last:pb-0"
          )}
        >
          <span className="text-muted-foreground">{CATEGORY_LABELS[key]}</span>
          <span className="tabular-nums font-medium">
            {formatCurrency(totals[key])}
          </span>
        </li>
      ))}
    </ul>
  );
}
