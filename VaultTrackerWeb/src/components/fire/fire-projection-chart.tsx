"use client";

import { useId } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { formatCurrency } from "@/lib/format";
import type { FireProjectionResponse } from "@/types/api";

export function FireProjectionChart({ projection }: { projection: FireProjectionResponse }) {
  const gid = useId().replace(/:/g, "");
  const curve = projection.projectionCurve;
  if (!curve.length) {
    return null;
  }

  const lean = projection.fireTargets.leanFire.targetAmount;
  const reg = projection.fireTargets.fire.targetAmount;
  const fat = projection.fireTargets.fatFire.targetAmount;
  const targetAge = projection.inputs.targetRetirementAge;

  const crossIdx = projection.fireTargets.fire.yearsToTarget;
  const crossPoint = crossIdx != null && curve[crossIdx] ? curve[crossIdx] : undefined;

  const maxY = Math.max(...curve.map((p) => p.projectedValue), lean, reg, fat, 1);

  return (
    <div className="h-[320px] w-full" data-slot="fire-projection-chart">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={curve} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id={`fireFill-${gid}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-primary)" stopOpacity={0.2} />
              <stop offset="100%" stopColor="var(--color-primary)" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="4 4" className="stroke-border/80" vertical={false} />
          <XAxis
            dataKey="age"
            tick={{ fill: "var(--color-muted-foreground)", fontSize: 10 }}
            stroke="transparent"
            tickLine={false}
            label={{ value: "Age", position: "insideBottom", offset: -4, fontSize: 10 }}
          />
          <YAxis
            domain={[0, maxY * 1.05]}
            tickFormatter={(v) =>
              new Intl.NumberFormat(undefined, {
                notation: "compact",
                maximumFractionDigits: 1,
              }).format(v)
            }
            tick={{ fill: "var(--color-muted-foreground)", fontSize: 10 }}
            stroke="transparent"
            tickLine={false}
            width={52}
          />
          <Tooltip
            content={({ active, payload }) => {
              if (!active || !payload?.[0]) return null;
              const row = payload[0].payload as (typeof curve)[0];
              return (
                <div className="bg-popover text-popover-foreground rounded-md border px-3 py-2 font-mono text-sm shadow-md">
                  <p className="text-muted-foreground text-[10px]">Age {row.age}</p>
                  <p className="text-[13px] font-medium">{formatCurrency(row.projectedValue)}</p>
                </div>
              );
            }}
          />
          <Area
            type="monotone"
            dataKey="projectedValue"
            stroke="var(--color-primary)"
            fill={`url(#fireFill-${gid})`}
            strokeWidth={2}
          />
          <ReferenceLine y={lean} stroke="#f59e0b" strokeDasharray="4 4" strokeOpacity={0.9} />
          <ReferenceLine
            y={reg}
            stroke="var(--color-primary)"
            strokeDasharray="4 4"
            strokeOpacity={0.95}
          />
          <ReferenceLine y={fat} stroke="#8b5cf6" strokeDasharray="4 4" strokeOpacity={0.9} />
          {targetAge != null ? (
            <ReferenceLine
              x={targetAge}
              stroke="var(--color-muted-foreground)"
              strokeDasharray="3 3"
              strokeOpacity={0.65}
            />
          ) : null}
          {crossPoint && crossPoint.age !== targetAge ? (
            <ReferenceLine
              x={crossPoint.age}
              stroke="var(--color-primary)"
              strokeWidth={1}
              strokeOpacity={0.45}
            />
          ) : null}
        </AreaChart>
      </ResponsiveContainer>
      <div className="text-muted-foreground mt-2 flex flex-wrap gap-4 text-[10px] tracking-wide uppercase">
        <span className="inline-flex items-center gap-1.5">
          <span className="bg-amber-500 inline-block size-2 rounded-full" aria-hidden />
          Lean FIRE
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="bg-primary inline-block size-2 rounded-full" aria-hidden />
          Regular FIRE
        </span>
        <span className="inline-flex items-center gap-1.5">
          <span className="bg-violet-500 inline-block size-2 rounded-full" aria-hidden />
          Fat FIRE
        </span>
        {targetAge != null ? (
          <span className="inline-flex items-center gap-1.5">
            <span className="bg-muted-foreground inline-block h-0.5 w-3" aria-hidden />
            Goal age
          </span>
        ) : null}
      </div>
    </div>
  );
}
