"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/format";
import type { FireProjectionResponse } from "@/types/api";

function projectedValueAtRegularFire(p: FireProjectionResponse): number {
  const idx = p.fireTargets.fire.yearsToTarget;
  if (idx != null && p.projectionCurve[idx]) {
    return p.projectionCurve[idx].projectedValue;
  }
  return p.fireTargets.fire.targetAmount;
}

export function FireSummaryCards({
  projection,
  loading,
}: {
  projection: FireProjectionResponse | undefined;
  loading?: boolean;
}) {
  if (loading) {
    return (
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {[1, 2, 3].map((i) => (
          <Card key={i} size="sm" className="animate-pulse bg-muted/40">
            <CardHeader>
              <CardTitle className="h-4 w-24 rounded bg-muted" />
            </CardHeader>
            <CardContent>
              <div className="bg-muted h-8 w-20 rounded" />
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  if (!projection || projection.status === "unreachable") {
    return null;
  }

  const months = projection.monthlyBreakdown.monthsToFire;
  const monthsLabel =
    months == null ? "—" : months >= 12 ? `${Math.round(months / 12)} yr` : `${months} mo`;

  const atFire = projectedValueAtRegularFire(projection);

  return (
    <div
      className="grid grid-cols-1 gap-3 sm:grid-cols-3"
      data-slot="fire-summary-cards"
      role="list"
    >
      <Card size="sm" role="listitem">
        <CardHeader>
          <CardTitle className="text-muted-foreground text-xs font-normal tracking-wide uppercase">
            Monthly surplus
          </CardTitle>
        </CardHeader>
        <CardContent className="font-mono text-lg font-medium tabular-nums">
          {formatCurrency(projection.monthlyBreakdown.monthlySurplus)}
        </CardContent>
      </Card>
      <Card size="sm" role="listitem">
        <CardHeader>
          <CardTitle className="text-muted-foreground text-xs font-normal tracking-wide uppercase">
            Time to Regular FIRE
          </CardTitle>
        </CardHeader>
        <CardContent className="font-mono text-lg font-medium tabular-nums">
          {monthsLabel}
        </CardContent>
      </Card>
      <Card size="sm" role="listitem">
        <CardHeader>
          <CardTitle className="text-muted-foreground text-xs font-normal tracking-wide uppercase">
            Projected at Regular FIRE
          </CardTitle>
        </CardHeader>
        <CardContent className="font-mono text-lg font-medium tabular-nums">
          {formatCurrency(atFire)}
        </CardContent>
      </Card>
    </div>
  );
}
