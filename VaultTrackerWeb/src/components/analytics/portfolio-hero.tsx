"use client";

import { cn } from "@/lib/utils";
import { formatCurrency } from "@/lib/format";
import { Skeleton } from "@/components/ui/skeleton";

export interface PortfolioMonthChange {
  absolute: number;
  percent: number;
}

function TrendGlyph({ positive }: { positive: boolean }) {
  return (
    <svg
      width="12"
      height="12"
      viewBox="0 0 12 12"
      fill="none"
      aria-hidden
      className={cn("shrink-0", !positive && "rotate-180")}
    >
      <polyline
        points="1,9 5,4 8,7 11,2"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function PortfolioHero({
  totalNetWorth,
  monthChange,
  loading,
}: {
  totalNetWorth: number;
  monthChange: PortfolioMonthChange | null;
  loading: boolean;
}) {
  if (loading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-3 w-36" />
        <Skeleton className="h-14 w-full max-w-md md:h-[3.5rem]" />
        <Skeleton className="h-5 w-52" />
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-primary text-[10px] font-medium uppercase tracking-[0.14em]">
        Total portfolio
      </p>
      <p className="font-heading text-5xl font-bold tracking-tight tabular-nums md:text-[56px]">
        {formatCurrency(totalNetWorth)}
      </p>
      {monthChange ? (
        <div
          className={cn(
            "inline-flex flex-wrap items-center gap-1.5 font-mono text-[13px]",
            monthChange.absolute >= 0 ? "text-primary" : "text-destructive"
          )}
        >
          <TrendGlyph positive={monthChange.absolute >= 0} />
          <span className="tabular-nums">
            {monthChange.absolute >= 0 ? "+" : ""}
            {formatCurrency(monthChange.absolute)} (
            {monthChange.percent >= 0 ? "+" : ""}
            {monthChange.percent.toFixed(1)}%)
          </span>
          <span className="text-muted-foreground text-[11px] font-normal">
            last ~30 days
          </span>
        </div>
      ) : (
        <p className="text-muted-foreground text-[13px]">
          Add history to see trailing change.
        </p>
      )}
    </div>
  );
}
