"use client";

import { useState } from "react";
import { RefreshCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { StatCard } from "@/components/dashboard/stat-card";
import { CategoryBar } from "@/components/dashboard/category-bar";
import { NetWorthChart } from "@/components/dashboard/net-worth-chart";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";
import { useDashboard } from "@/lib/queries/use-dashboard";
import { useNetWorthHistory } from "@/lib/queries/use-networth";
import { useAssets } from "@/lib/queries/use-assets";
import { useRefreshPrices } from "@/lib/queries/use-prices";
import { formatCurrency } from "@/lib/format";
import type { Category, NetWorthPeriod } from "@/types/api";
import { cn } from "@/lib/utils";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const CATEGORY_CHIPS: { key: Category | "all"; label: string }[] = [
  { key: "all", label: "All" },
  { key: "crypto", label: "Crypto" },
  { key: "stocks", label: "Stocks" },
  { key: "cash", label: "Cash" },
  { key: "realEstate", label: "Real estate" },
  { key: "retirement", label: "Retirement" },
];

export default function DashboardPage() {
  const [period, setPeriod] = useState<NetWorthPeriod>("daily");
  const [assetCategory, setAssetCategory] = useState<Category | "all">("all");

  const dashboard = useDashboard();
  const history = useNetWorthHistory(period);
  const assetsFiltered = useAssets(
    assetCategory === "all" ? undefined : assetCategory
  );
  const refreshPrices = useRefreshPrices();

  const d = dashboard.data;
  const loading = dashboard.isLoading;

  const groupedForFilter =
    assetCategory === "all"
      ? d?.groupedHoldings
      : assetsFiltered.data?.reduce(
          (acc, a) => {
            const list = acc[a.category] ?? [];
            list.push({
              id: a.id,
              name: a.name,
              symbol: a.symbol,
              quantity: a.quantity,
              current_value: a.current_value,
            });
            acc[a.category] = list;
            return acc;
          },
          {} as Record<string, import("@/types/api").HoldingItem[]>
        );

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
        <div className="flex flex-wrap items-center gap-2">
          <Select
            value={period}
            onValueChange={(v) => setPeriod(v as NetWorthPeriod)}
          >
            <SelectTrigger className="w-40">
              <SelectValue placeholder="Period" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="daily">Daily</SelectItem>
              <SelectItem value="weekly">Weekly</SelectItem>
              <SelectItem value="monthly">Monthly</SelectItem>
              <SelectItem value="all">All</SelectItem>
            </SelectContent>
          </Select>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={refreshPrices.isPending}
            onClick={() =>
              refreshPrices.mutate(undefined, {
                onSuccess: (res) => {
                  toast.message("Prices refreshed", {
                    description: `${res.updated.length} updated, ${res.skipped.length} skipped`,
                  });
                },
                onError: (e) => {
                  toast.error("Refresh failed", {
                    description: e instanceof Error ? e.message : "Unknown error",
                  });
                },
              })
            }
          >
            <RefreshCw
              className={cn(
                "mr-2 size-4",
                refreshPrices.isPending && "animate-spin"
              )}
            />
            Refresh prices
          </Button>
        </div>
      </div>

      {dashboard.isError ? (
        <p className="text-destructive text-sm">
          {dashboard.error instanceof Error
            ? dashboard.error.message
            : "Failed to load dashboard"}
        </p>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard
          title="Total net worth"
          value={formatCurrency(d?.totalNetWorth ?? 0)}
          loading={loading}
        />
        {d?.categoryTotals
          ? (["crypto", "stocks", "cash", "realEstate", "retirement"] as const).map(
              (k) => (
                <StatCard
                  key={k}
                  title={k}
                  value={formatCurrency(d.categoryTotals[k])}
                  loading={loading}
                />
              )
            )
          : [1, 2, 3, 4, 5].map((i) => (
              <StatCard key={i} title="…" value="…" loading />
            ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Net worth history</h2>
        <NetWorthChart
          data={history.data?.snapshots ?? []}
          loading={history.isLoading}
        />
        {history.isError ? (
          <p className="text-destructive text-sm">Could not load history.</p>
        ) : null}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Allocation bar</h2>
        <CategoryBar
          totals={d?.categoryTotals}
          total={d?.totalNetWorth ?? 0}
          loading={loading}
        />
      </section>

      <section className="space-y-3">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-lg font-medium">Holdings</h2>
          <div className="flex flex-wrap gap-2">
            {CATEGORY_CHIPS.map(({ key, label }) => (
              <Button
                key={key}
                type="button"
                size="sm"
                variant={assetCategory === key ? "default" : "outline"}
                onClick={() => setAssetCategory(key)}
              >
                {label}
              </Button>
            ))}
          </div>
        </div>
        <HoldingsGrid
          grouped={groupedForFilter}
          loading={loading || assetsFiltered.isLoading}
        />
      </section>
    </div>
  );
}
