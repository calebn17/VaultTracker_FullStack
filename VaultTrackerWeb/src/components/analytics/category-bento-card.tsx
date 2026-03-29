"use client";

import type { Category, HoldingItem } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";
import { MERIDIAN_CATEGORY_HEX } from "@/components/dashboard/category-summary-list";
import { AssetIcon } from "@/components/dashboard/holdings-grid";

const CARD_TITLES: Record<Category, string> = {
  stocks: "Stocks & ETFs",
  crypto: "Digital Assets",
  realEstate: "Real Estate",
  cash: "Cash & Liquidity",
  retirement: "Retirement",
};

function sortedHoldings(holdings: HoldingItem[]) {
  return [...holdings].sort((a, b) => b.current_value - a.current_value);
}

export interface CategoryBentoCardProps {
  category: Category;
  holdings: HoldingItem[];
  totalValue: number;
  allocationPercent: number;
  totalNetWorth: number;
  onSelectHolding: (holding: HoldingItem, category: Category) => void;
  loading: boolean;
}

export function CategoryBentoCard({
  category,
  holdings,
  totalValue,
  allocationPercent,
  onSelectHolding,
  loading,
}: CategoryBentoCardProps) {
  const accent = MERIDIAN_CATEGORY_HEX[category];
  const title = CARD_TITLES[category];
  const items = sortedHoldings(holdings);

  if (loading) {
    return (
      <div
        className={cn(
          "rounded-2xl border border-border p-6",
          category === "cash"
            ? "bg-primary text-primary-foreground"
            : "bg-card"
        )}
      >
        <div className="bg-muted/50 mb-4 h-3 w-28 animate-pulse rounded" />
        <div className="bg-muted/50 h-10 w-40 animate-pulse rounded" />
      </div>
    );
  }

  const shellClass = cn(
    "flex h-full flex-col rounded-2xl border p-6 transition-colors",
    category === "cash"
      ? "border-primary-foreground/15 bg-primary text-primary-foreground hover:border-primary-foreground/25"
      : "bg-card border-border hover:border-foreground/15"
  );

  const header = (
    <div className="mb-4 flex items-start justify-between gap-2">
      <div className="flex min-w-0 items-center gap-2">
        <span
          className="h-4 w-0.5 shrink-0 rounded-full"
          style={{ background: accent }}
          aria-hidden
        />
        <h2
          className={cn(
            "text-[10px] font-medium uppercase tracking-[0.1em]",
            category === "cash"
              ? "text-primary-foreground/90"
              : "text-muted-foreground"
          )}
        >
          {title}
        </h2>
      </div>
      <span
        className={cn(
          "shrink-0 font-mono text-[11px] tabular-nums",
          category === "cash"
            ? "text-primary-foreground/80"
            : "text-muted-foreground"
        )}
      >
        {allocationPercent.toFixed(1)}% alloc
      </span>
    </div>
  );

  if (items.length === 0) {
    return (
      <div className={shellClass}>
        {header}
        <p
          className={cn(
            "py-8 text-center text-sm opacity-60",
            category === "cash"
              ? "text-primary-foreground"
              : "text-muted-foreground"
          )}
        >
          No holdings yet
        </p>
      </div>
    );
  }

  if (category === "stocks") {
    return (
      <div className={shellClass}>
        {header}
        <div className="min-h-0 flex-1 overflow-x-auto">
          <div className="text-muted-foreground grid min-w-[280px] grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)] gap-x-3 gap-y-1 border-b border-border pb-2 text-[10px] font-medium uppercase tracking-[0.1em]">
            <span>Asset</span>
            <span className="text-right">Qty</span>
            <span className="text-right">Value</span>
          </div>
          <ul className="divide-border/60 divide-y">
            {items.map((h) => (
              <li key={h.id}>
                <button
                  type="button"
                  onClick={() => onSelectHolding(h, category)}
                  className="hover:bg-foreground/[0.04] grid w-full grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)] gap-x-3 py-3 text-left text-sm transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <div className="flex min-w-0 items-center gap-2">
                    <AssetIcon
                      label={h.symbol?.trim() || h.name}
                      color={accent}
                    />
                    <span className="truncate font-medium">{h.name}</span>
                  </div>
                  <span className="text-muted-foreground text-right font-mono text-[13px] tabular-nums">
                    {h.quantity.toLocaleString(undefined, {
                      maximumFractionDigits: 4,
                    })}
                  </span>
                  <span className="text-right font-mono text-[13px] tabular-nums">
                    {formatCurrency(h.current_value)}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>
    );
  }

  if (category === "realEstate") {
    return (
      <div className={shellClass}>
        {header}
        <ul className="min-h-0 flex-1 space-y-1">
          {items.map((h) => (
            <li key={h.id}>
              <button
                type="button"
                onClick={() => onSelectHolding(h, category)}
                className="hover:bg-foreground/[0.04] flex w-full items-center justify-between gap-4 rounded-lg py-3 text-left transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                <span className="font-heading min-w-0 truncate text-[15px] font-semibold tracking-tight">
                  {h.name}
                </span>
                <span className="shrink-0 font-mono text-sm tabular-nums">
                  {formatCurrency(h.current_value)}
                </span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    );
  }

  if (category === "cash") {
    return (
      <div className={shellClass}>
        {header}
        <div className="mb-6 text-center">
          <p className="font-heading text-3xl font-bold tabular-nums md:text-4xl">
            {formatCurrency(totalValue)}
          </p>
        </div>
        <ul className="border-primary-foreground/15 min-h-0 flex-1 space-y-1 border-t pt-4">
          {items.map((h) => (
            <li key={h.id}>
              <button
                type="button"
                onClick={() => onSelectHolding(h, category)}
                className="hover:bg-primary-foreground/10 flex w-full items-center justify-between gap-3 rounded-lg py-2 text-left text-sm transition-colors outline-none focus-visible:ring-2 focus-visible:ring-primary-foreground/40"
              >
                <div className="flex min-w-0 items-center gap-2">
                  <span
                    className="size-2 shrink-0 rounded-full"
                    style={{ background: accent }}
                    aria-hidden
                  />
                  <span className="text-primary-foreground/95 truncate">
                    {h.name}
                  </span>
                </div>
                <span className="text-primary-foreground shrink-0 font-mono tabular-nums">
                  {formatCurrency(h.current_value)}
                </span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    );
  }

  return (
    <div className={shellClass}>
      {header}
      <ul className="min-h-0 flex-1 space-y-1">
        {items.map((h) => {
          const iconLabel = h.symbol?.trim() || h.name;
          return (
            <li key={h.id}>
              <button
                type="button"
                onClick={() => onSelectHolding(h, category)}
                className="hover:bg-foreground/[0.04] flex w-full items-center justify-between gap-3 rounded-lg py-2.5 text-left transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring"
              >
                <div className="flex min-w-0 items-center gap-2.5">
                  <AssetIcon label={iconLabel} color={accent} />
                  <span className="min-w-0 truncate text-[13px]">{h.name}</span>
                </div>
                <span className="shrink-0 font-mono text-[13px] tabular-nums">
                  {formatCurrency(h.current_value)}
                </span>
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
