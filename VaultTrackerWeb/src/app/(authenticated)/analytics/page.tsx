"use client";

import { useState } from "react";
import {
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  Legend,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useAnalytics } from "@/lib/queries/use-analytics";
import { useNetWorthHistory } from "@/lib/queries/use-networth";
import { usePriceLookup } from "@/lib/queries/use-prices";
import { NetWorthChart } from "@/components/dashboard/net-worth-chart";
import { formatCurrency } from "@/lib/format";
import type { NetWorthPeriod } from "@/types/api";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const COLORS = [
  "var(--color-chart-1)",
  "var(--color-chart-2)",
  "var(--color-chart-3)",
  "var(--color-chart-4)",
  "var(--color-chart-5)",
];

export default function AnalyticsPage() {
  const [period, setPeriod] = useState<NetWorthPeriod>("daily");
  const [symbol, setSymbol] = useState("");
  const [lookup, setLookup] = useState("");
  const priceQ = usePriceLookup(lookup);

  const analytics = useAnalytics();
  const history = useNetWorthHistory(period);

  const pieData =
    analytics.data?.allocation &&
    Object.entries(analytics.data.allocation)
      .filter(([, v]) => v.value > 0)
      .map(([name, v]) => ({
        name,
        value: v.value,
        pct: v.percentage,
      }));

  return (
    <div className="space-y-8">
      <h1 className="text-2xl font-semibold tracking-tight">Analytics</h1>

      {analytics.isError ? (
        <p className="text-destructive text-sm">Failed to load analytics.</p>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Allocation</CardTitle>
          </CardHeader>
          <CardContent>
            {analytics.isLoading ? (
              <div className="bg-muted h-64 animate-pulse rounded-lg" />
            ) : pieData?.length ? (
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={pieData}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      outerRadius={90}
                      label={({ name, percent }) =>
                        `${String(name)} (${((percent ?? 0) * 100).toFixed(0)}%)`
                      }
                    >
                      {pieData.map((_, i) => (
                        <Cell
                          key={i}
                          fill={COLORS[i % COLORS.length]}
                          stroke="transparent"
                        />
                      ))}
                    </Pie>
                    <Tooltip
                      formatter={(value) =>
                        formatCurrency(typeof value === "number" ? value : 0)
                      }
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="text-muted-foreground text-sm">No data yet.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Performance</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            {analytics.isLoading ? (
              <div className="space-y-2">
                <div className="bg-muted h-6 animate-pulse rounded" />
                <div className="bg-muted h-6 animate-pulse rounded" />
              </div>
            ) : analytics.data ? (
              <>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Gain / loss</span>
                  <span
                    className={
                      analytics.data.performance.totalGainLoss >= 0
                        ? "text-emerald-600 dark:text-emerald-400"
                        : "text-destructive"
                    }
                  >
                    {formatCurrency(analytics.data.performance.totalGainLoss)} (
                    {analytics.data.performance.totalGainLossPercent}%)
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Cost basis</span>
                  <span>
                    {formatCurrency(analytics.data.performance.costBasis)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Current value</span>
                  <span>
                    {formatCurrency(analytics.data.performance.currentValue)}
                  </span>
                </div>
              </>
            ) : null}
          </CardContent>
        </Card>
      </div>

      <section className="space-y-2">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-lg font-medium">Net worth trend</h2>
          <Select
            value={period}
            onValueChange={(v) => setPeriod(v as NetWorthPeriod)}
          >
            <SelectTrigger className="w-40 sm:w-44">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="daily">Daily</SelectItem>
              <SelectItem value="weekly">Weekly</SelectItem>
              <SelectItem value="monthly">Monthly</SelectItem>
              <SelectItem value="all">All</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <NetWorthChart
          data={history.data?.snapshots ?? []}
          loading={history.isLoading}
        />
      </section>

      <Card>
        <CardHeader>
          <CardTitle>Price lookup</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-4 sm:flex-row sm:items-end">
          <div className="flex-1 space-y-2">
            <label className="text-sm font-medium" htmlFor="sym">
              Symbol
            </label>
            <Input
              id="sym"
              placeholder="e.g. BTC, AAPL"
              value={symbol}
              onChange={(e) => setSymbol(e.target.value)}
            />
          </div>
          <Button type="button" onClick={() => setLookup(symbol.trim())}>
            Look up
          </Button>
        </CardContent>
        {lookup ? (
          <CardContent className="border-t pt-0">
            {priceQ.isLoading ? (
              <p className="text-muted-foreground text-sm">Loading…</p>
            ) : priceQ.isError ? (
              <p className="text-destructive text-sm">No price found.</p>
            ) : priceQ.data ? (
              <p className="text-sm">
                <span className="font-medium">{priceQ.data.symbol}</span>:{" "}
                {formatCurrency(priceQ.data.price)}{" "}
                <span className="text-muted-foreground">
                  ({priceQ.data.source})
                </span>
              </p>
            ) : null}
          </CardContent>
        ) : null}
      </Card>
    </div>
  );
}
