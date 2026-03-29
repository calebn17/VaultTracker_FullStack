"use client";

import { useMemo, useState } from "react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useDashboard } from "@/lib/queries/use-dashboard";
import { useAnalytics } from "@/lib/queries/use-analytics";
import { useNetWorthHistory } from "@/lib/queries/use-networth";
import { usePriceLookup } from "@/lib/queries/use-prices";
import { NetWorthChart } from "@/components/dashboard/net-worth-chart";
import { AssetDetailDialog } from "@/components/dashboard/asset-detail-dialog";
import { PortfolioHero } from "@/components/analytics/portfolio-hero";
import { CategoryBentoCard } from "@/components/analytics/category-bento-card";
import { PerformanceAttribution } from "@/components/analytics/performance-attribution";
import { formatCurrency } from "@/lib/format";
import { computeApproxMonthChange } from "@/lib/networth-change";
import type { Category, HoldingItem, NetWorthPeriod } from "@/types/api";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

function allocationPercent(
  allocation:
    | Record<string, { percentage: number } | undefined>
    | undefined,
  key: Category
): number {
  return allocation?.[key]?.percentage ?? 0;
}

export default function AnalyticsPage() {
  const [period, setPeriod] = useState<NetWorthPeriod>("daily");
  const [symbol, setSymbol] = useState("");
  const [lookup, setLookup] = useState("");
  const priceQ = usePriceLookup(lookup);

  const dashboard = useDashboard();
  const analytics = useAnalytics();
  const history = useNetWorthHistory(period);
  const historyDaily = useNetWorthHistory("daily");

  const [selectedHolding, setSelectedHolding] = useState<{
    holding: HoldingItem;
    category: Category;
  } | null>(null);

  const d = dashboard.data;
  const loadingDashboard = dashboard.isLoading;
  const loadingAnalytics = analytics.isLoading;

  const monthChange = useMemo(
    () => computeApproxMonthChange(historyDaily.data?.snapshots ?? []),
    [historyDaily.data?.snapshots]
  );

  const monthChangeProp =
    monthChange != null
      ? { absolute: monthChange.absolute, percent: monthChange.percent }
      : null;

  const totalNetWorth = d?.totalNetWorth ?? 0;
  const grouped = d?.groupedHoldings;
  const totals = d?.categoryTotals;
  const alloc = analytics.data?.allocation;

  const cardLoading = loadingDashboard || loadingAnalytics;

  return (
    <div className="space-y-10">
      <PortfolioHero
        totalNetWorth={totalNetWorth}
        monthChange={monthChangeProp}
        loading={loadingDashboard}
      />

      {analytics.isError ? (
        <p className="text-destructive text-sm">Failed to load analytics.</p>
      ) : null}

      <div className="grid grid-cols-12 gap-4 md:gap-5">
        <div className="col-span-12 lg:col-span-7">
          <CategoryBentoCard
            category="stocks"
            holdings={grouped?.stocks ?? []}
            totalValue={totals?.stocks ?? 0}
            allocationPercent={allocationPercent(alloc, "stocks")}
            totalNetWorth={totalNetWorth}
            onSelectHolding={(h, c) =>
              setSelectedHolding({ holding: h, category: c })
            }
            loading={cardLoading}
          />
        </div>
        <div className="col-span-12 lg:col-span-5">
          <CategoryBentoCard
            category="crypto"
            holdings={grouped?.crypto ?? []}
            totalValue={totals?.crypto ?? 0}
            allocationPercent={allocationPercent(alloc, "crypto")}
            totalNetWorth={totalNetWorth}
            onSelectHolding={(h, c) =>
              setSelectedHolding({ holding: h, category: c })
            }
            loading={cardLoading}
          />
        </div>

        <div className="col-span-12 lg:col-span-8">
          <CategoryBentoCard
            category="realEstate"
            holdings={grouped?.realEstate ?? []}
            totalValue={totals?.realEstate ?? 0}
            allocationPercent={allocationPercent(alloc, "realEstate")}
            totalNetWorth={totalNetWorth}
            onSelectHolding={(h, c) =>
              setSelectedHolding({ holding: h, category: c })
            }
            loading={cardLoading}
          />
        </div>
        <div className="col-span-12 lg:col-span-4">
          <CategoryBentoCard
            category="cash"
            holdings={grouped?.cash ?? []}
            totalValue={totals?.cash ?? 0}
            allocationPercent={allocationPercent(alloc, "cash")}
            totalNetWorth={totalNetWorth}
            onSelectHolding={(h, c) =>
              setSelectedHolding({ holding: h, category: c })
            }
            loading={cardLoading}
          />
        </div>

        <div className="col-span-12 lg:col-span-6">
          <CategoryBentoCard
            category="retirement"
            holdings={grouped?.retirement ?? []}
            totalValue={totals?.retirement ?? 0}
            allocationPercent={allocationPercent(alloc, "retirement")}
            totalNetWorth={totalNetWorth}
            onSelectHolding={(h, c) =>
              setSelectedHolding({ holding: h, category: c })
            }
            loading={cardLoading}
          />
        </div>

        <div className="border-border bg-card hover:border-foreground/15 col-span-12 flex flex-col gap-3 rounded-2xl border p-6 transition-colors lg:col-span-6">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <h3 className="text-muted-foreground text-[10px] font-medium uppercase tracking-[0.1em]">
              Net worth trend
            </h3>
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
          {history.isError ? (
            <p className="text-destructive text-sm">
              Could not load net worth history.
            </p>
          ) : null}
        </div>
      </div>

      <PerformanceAttribution
        performance={analytics.data?.performance}
        loading={loadingAnalytics}
      />

      <div className="border-border bg-card hover:border-foreground/15 rounded-2xl border p-6 transition-colors">
        <p className="text-muted-foreground mb-4 text-[10px] font-medium uppercase tracking-[0.1em]">
          Price lookup
        </p>
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end">
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
        </div>
        {lookup ? (
          <div className="border-border mt-6 border-t pt-4">
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
          </div>
        ) : null}
      </div>

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
