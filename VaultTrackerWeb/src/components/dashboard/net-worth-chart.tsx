"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { format } from "date-fns";
import { formatCurrency } from "@/lib/format";
import { Skeleton } from "@/components/ui/skeleton";

export function NetWorthChart({
  data,
  loading,
}: {
  data: Array<{ date: string; value: number }>;
  loading?: boolean;
}) {
  if (loading) {
    return <Skeleton className="h-[260px] w-full rounded-lg" />;
  }

  if (!data.length) {
    return (
      <p className="text-muted-foreground py-12 text-center text-sm">
        No history yet. Add a transaction to record your first snapshot.
      </p>
    );
  }

  const chartData = data.map((d) => ({
    ...d,
    t: new Date(d.date).getTime(),
  }));

  return (
    <div className="h-[260px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={chartData} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="nwFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--color-primary)" stopOpacity={0.18} />
              <stop offset="100%" stopColor="var(--color-primary)" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid
            strokeDasharray="4 4"
            className="stroke-border/80"
            vertical={false}
          />
          <XAxis
            dataKey="t"
            type="number"
            domain={["dataMin", "dataMax"]}
            tickFormatter={(t) => format(new Date(t), "MMM d")}
            tick={{ fill: "var(--color-muted-foreground)", fontSize: 10 }}
            stroke="transparent"
            tickLine={false}
          />
          <YAxis
            tickFormatter={(v) =>
              new Intl.NumberFormat(undefined, {
                notation: "compact",
                maximumFractionDigits: 1,
              }).format(v)
            }
            tick={{ fill: "var(--color-muted-foreground)", fontSize: 10 }}
            stroke="transparent"
            tickLine={false}
            width={48}
          />
          <Tooltip
            content={({ active, payload }) => {
              if (!active || !payload?.[0]) return null;
              const row = payload[0].payload as { date: string; value: number };
              return (
                <div className="bg-popover text-popover-foreground rounded-md border px-3 py-2 font-mono text-sm shadow-md">
                  <p className="text-muted-foreground text-[10px]">
                    {format(new Date(row.date), "PP")}
                  </p>
                  <p className="text-[13px] font-medium">{formatCurrency(row.value)}</p>
                </div>
              );
            }}
          />
          <Area
            type="monotone"
            dataKey="value"
            stroke="var(--color-primary)"
            fill="url(#nwFill)"
            strokeWidth={2}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
