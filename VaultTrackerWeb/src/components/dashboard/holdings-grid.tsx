"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";
import type { Category, HoldingItem } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";
import { MERIDIAN_CATEGORY_HEX } from "@/components/dashboard/category-summary-list";
import { AssetDetailDialog } from "@/components/dashboard/asset-detail-dialog";

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

const tableGrid =
  "grid grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)] md:grid-cols-[2fr_1.2fr_1fr_1fr_0.8fr] gap-x-3 items-center";

export function AssetIcon({
  label,
  color,
}: {
  label: string;
  color: string;
}) {
  const text = label.slice(0, 3).toUpperCase();
  return (
    <div
      className="flex size-9 shrink-0 items-center justify-center rounded-lg text-[11px] font-bold tracking-wide"
      style={{
        background: `${color}18`,
        color,
        fontFamily: "var(--font-meridian-syne), system-ui, sans-serif",
      }}
    >
      {text}
    </div>
  );
}

export function HoldingsGrid({
  grouped,
  totalNetWorth,
  loading,
  categoryFilter = "all",
}: {
  grouped: Record<string, HoldingItem[]> | undefined;
  totalNetWorth: number;
  loading?: boolean;
  categoryFilter?: Category | "all";
}) {
  const [open, setOpen] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(ORDER.map((k) => [k, true]))
  );
  const [selectedHolding, setSelectedHolding] = useState<{
    holding: HoldingItem;
    category: Category;
  } | null>(null);

  const categoriesToShow =
    categoryFilter === "all" ? ORDER : [categoryFilter];

  const hasAny = categoriesToShow.some(
    (cat) => (grouped?.[cat] ?? []).length > 0
  );

  if (!loading && !hasAny) {
    return (
      <div className="bg-card text-muted-foreground rounded-2xl border px-5 py-12 text-center text-sm">
        No holdings yet. Add a transaction to get started.
      </div>
    );
  }

  if (loading) {
    return (
      <div className="bg-card overflow-hidden rounded-2xl border">
        {[1, 2, 3].map((i) => (
          <div key={i} className="bg-muted/40 h-14 animate-pulse border-b last:border-0" />
        ))}
      </div>
    );
  }

  return (
    <div className="bg-card overflow-hidden rounded-2xl border">
      <div
        className={cn(
          tableGrid,
          "text-muted-foreground border-border border-b px-5 py-3 text-[10px] tracking-[0.1em] uppercase"
        )}
      >
        <span>Asset</span>
        <span className="text-right">Value</span>
        <span className="hidden text-right md:block">24h change</span>
        <span className="text-right">Allocation</span>
        <span className="hidden text-right md:block">Ticker</span>
      </div>

      {categoriesToShow.map((cat) => {
        const items = grouped?.[cat] ?? [];
        const total = items.reduce((s, h) => s + h.current_value, 0);
        const isOpen = open[cat] ?? true;
        const color = MERIDIAN_CATEGORY_HEX[cat];
        const groupPct =
          totalNetWorth > 0 ? ((total / totalNetWorth) * 100).toFixed(1) : "0.0";
        const rowCount = items.length;

        if (items.length === 0 && categoryFilter !== "all") {
          return (
            <p
              key={cat}
              className="text-muted-foreground border-border border-b px-5 py-6 text-sm last:border-0"
            >
              No holdings in this category.
            </p>
          );
        }

        if (items.length === 0) return null;

        return (
          <div key={cat}>
            <button
              type="button"
              aria-expanded={isOpen}
              aria-label={`${isOpen ? "Collapse" : "Expand"} ${LABELS[cat]} holdings`}
              className={cn(
                tableGrid,
                "bg-secondary/80 border-border hover:bg-secondary w-full cursor-pointer border-b px-5 py-3 text-left transition-colors outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
              )}
              onClick={() =>
                setOpen((o) => ({ ...o, [cat]: !isOpen }))
              }
            >
              <div className="flex min-w-0 items-center gap-2.5">
                <span
                  className="h-4 w-0.5 shrink-0 rounded-full"
                  style={{ background: color }}
                  aria-hidden
                />
                <span
                  className="font-heading text-[11px] font-semibold tracking-[0.08em] text-foreground uppercase"
                >
                  {LABELS[cat]}
                </span>
                <span className="text-muted-foreground text-[10px]">
                  {rowCount} holding{rowCount === 1 ? "" : "s"}
                </span>
              </div>
              <span
                className="text-right text-xs font-medium tabular-nums"
                style={{ color }}
              >
                {formatCurrency(total)}
              </span>
              <span className="text-muted-foreground hidden text-right text-[11px] md:block">
                —
              </span>
              <span className="text-muted-foreground text-right text-[11px]">
                {groupPct}%
              </span>
              <span
                className="text-muted-foreground hidden justify-end md:flex"
                aria-hidden
              >
                <ChevronDown
                  className={cn(
                    "size-3 transition-transform",
                    !isOpen && "-rotate-90"
                  )}
                />
              </span>
            </button>

            {isOpen
              ? [...items]
                  .sort((a, b) => b.current_value - a.current_value)
                  .map((h) => {
                    const pct =
                      totalNetWorth > 0
                        ? ((h.current_value / totalNetWorth) * 100).toFixed(1)
                        : "0.0";
                    const iconLabel = h.symbol?.trim() || h.name;
                    return (
                      <button
                        key={h.id}
                        type="button"
                        aria-label={`View details for ${h.name}`}
                        onClick={() => setSelectedHolding({ holding: h, category: cat })}
                        className={cn(
                          tableGrid,
                          "border-border hover:bg-foreground/[0.05] w-full cursor-pointer border-b px-5 py-3.5 text-left text-sm transition-colors outline-none last:border-0 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
                        )}
                      >
                        <div className="flex min-w-0 items-center gap-3">
                          <AssetIcon label={iconLabel} color={color} />
                          <div className="min-w-0">
                            <div className="truncate text-[13px] text-foreground">
                              {h.name}
                            </div>
                            <div className="text-muted-foreground text-[10px] tracking-[0.06em] uppercase">
                              {h.symbol ?? LABELS[cat]}
                            </div>
                          </div>
                        </div>
                        <div className="text-foreground text-right text-[13px] tabular-nums">
                          {formatCurrency(h.current_value)}
                        </div>
                        <div className="text-muted-foreground hidden text-right text-xs md:block">
                          —
                        </div>
                        <div className="text-muted-foreground text-right text-[11px] tabular-nums">
                          {pct}%
                        </div>
                        <div className="text-muted-foreground hidden text-right text-[11px] md:block">
                          {h.symbol ?? "—"}
                        </div>
                      </button>
                    );
                  })
              : null}
          </div>
        );
      })}

      {selectedHolding ? (
        <AssetDetailDialog
          holding={selectedHolding.holding}
          category={selectedHolding.category}
          open
          onOpenChange={(isOpen) => {
            if (!isOpen) setSelectedHolding(null);
          }}
        />
      ) : null}
    </div>
  );
}
