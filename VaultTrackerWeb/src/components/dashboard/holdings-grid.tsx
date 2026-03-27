"use client";

import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import type { Category, HoldingItem } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { Button } from "@/components/ui/button";

const ORDER: Category[] = [
  "crypto",
  "stocks",
  "cash",
  "realEstate",
  "retirement",
];

const LABELS: Record<Category, string> = {
  crypto: "Crypto",
  stocks: "Stocks",
  cash: "Cash",
  realEstate: "Real Estate",
  retirement: "Retirement",
};

export function HoldingsGrid({
  grouped,
  loading,
  categoryFilter = "all",
}: {
  grouped: Record<string, HoldingItem[]> | undefined;
  loading?: boolean;
  /** When not `"all"`, only that category section is shown. */
  categoryFilter?: Category | "all";
}) {
  const [open, setOpen] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(ORDER.map((k) => [k, true]))
  );

  const categoriesToShow =
    categoryFilter === "all" ? ORDER : [categoryFilter];

  if (loading) {
    return (
      <div className="space-y-2">
        {[1, 2, 3].map((i) => (
          <div key={i} className="bg-muted h-12 animate-pulse rounded-lg" />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {categoriesToShow.map((cat) => {
        const items = grouped?.[cat] ?? [];
        const total = items.reduce((s, h) => s + h.current_value, 0);
        const isOpen = open[cat] ?? true;
        return (
          <div
            key={cat}
            className="bg-card rounded-lg border"
          >
            <Button
              variant="ghost"
              className="h-auto w-full justify-between px-4 py-3 font-medium"
              onClick={() =>
                setOpen((o) => ({ ...o, [cat]: !isOpen }))
              }
            >
              <span className="flex items-center gap-2">
                {isOpen ? (
                  <ChevronDown className="size-4" />
                ) : (
                  <ChevronRight className="size-4" />
                )}
                {LABELS[cat]}
                <span className="text-muted-foreground text-sm font-normal">
                  ({items.length} holding{items.length === 1 ? "" : "s"})
                </span>
              </span>
              <span className="tabular-nums">{formatCurrency(total)}</span>
            </Button>
            {isOpen && items.length > 0 ? (
              <ul className="border-t px-4 py-2">
                {items.map((h) => (
                  <li
                    key={h.id}
                    className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 py-2 text-sm"
                  >
                    <span className="min-w-0 truncate">
                      {h.name}
                      {h.symbol ? (
                        <span className="text-muted-foreground ml-1">
                          ({h.symbol})
                        </span>
                      ) : null}
                    </span>
                    <span className="shrink-0 whitespace-nowrap text-right font-medium tabular-nums">
                      {formatCurrency(h.current_value)}
                    </span>
                  </li>
                ))}
              </ul>
            ) : null}
            {isOpen && items.length === 0 ? (
              <p className="text-muted-foreground border-t px-4 py-3 text-sm">
                No holdings in this category.
              </p>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}
