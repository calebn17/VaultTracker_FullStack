"use client";

import type { AnalyticsResponse } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";
import { Skeleton } from "@/components/ui/skeleton";

export function PerformanceAttribution({
  performance,
  loading,
}: {
  performance: AnalyticsResponse["performance"] | undefined;
  loading: boolean;
}) {
  if (loading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-3 w-44" />
        <div className="grid gap-4 md:grid-cols-3">
          {[1, 2, 3].map((i) => (
            <Skeleton key={i} className="h-24 rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  if (!performance) return null;

  const positive = performance.totalGainLoss >= 0;

  return (
    <section className="space-y-4">
      <p className="text-[10px] font-medium uppercase tracking-[0.1em] text-muted-foreground">
        Performance summary
      </p>
      <div className="grid gap-4 md:grid-cols-3">
        <div className="rounded-xl bg-secondary p-5">
          <p className="text-[10px] uppercase tracking-[0.1em] text-muted-foreground">
            Total gain / loss
          </p>
          <p
            className={cn(
              "mt-2 font-heading text-xl font-semibold tabular-nums",
              positive ? "text-primary" : "text-destructive"
            )}
          >
            {formatCurrency(performance.totalGainLoss)} (
            {performance.totalGainLossPercent >= 0 ? "+" : ""}
            {performance.totalGainLossPercent}%)
          </p>
        </div>
        <div className="rounded-xl bg-secondary p-5">
          <p className="text-[10px] uppercase tracking-[0.1em] text-muted-foreground">
            Cost basis
          </p>
          <p className="mt-2 font-heading text-xl font-semibold tabular-nums text-foreground">
            {formatCurrency(performance.costBasis)}
          </p>
        </div>
        <div className="rounded-xl bg-secondary p-5">
          <p className="text-[10px] uppercase tracking-[0.1em] text-muted-foreground">
            Current value
          </p>
          <p className="mt-2 font-heading text-xl font-semibold tabular-nums text-foreground">
            {formatCurrency(performance.currentValue)}
          </p>
        </div>
      </div>
    </section>
  );
}
