"use client";

import { useMemo, useState } from "react";
import { Plus, RefreshCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { StatCard } from "@/components/dashboard/stat-card";
import { CategorySummaryList } from "@/components/dashboard/category-summary-list";
import { NetWorthChart } from "@/components/dashboard/net-worth-chart";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";
import { HouseholdMemberSections } from "@/components/dashboard/member-section";
import { TransactionFormDialog } from "@/components/transactions/transaction-form";
import { useDashboard, useDashboardHousehold } from "@/lib/queries/use-dashboard";
import { useHousehold } from "@/lib/queries/use-household";
import { useNetWorthHistory, useNetWorthHistoryHousehold } from "@/lib/queries/use-networth";
import { useRefreshPrices } from "@/lib/queries/use-prices";
import { useCreateTransaction } from "@/lib/queries/use-transactions";
import { formatCurrency } from "@/lib/format";
import { computeApproxMonthChange } from "@/lib/networth-change";
import type {
  Category,
  DashboardResponse,
  HouseholdDashboardResponse,
  NetWorthPeriod,
} from "@/types/api";
import { cn } from "@/lib/utils";

const CATEGORY_CHIPS: { key: Category | "all"; label: string }[] = [
  { key: "all", label: "All" },
  { key: "crypto", label: "Crypto" },
  { key: "stocks", label: "Stocks" },
  { key: "cash", label: "Cash" },
  { key: "realEstate", label: "Real Estate" },
  { key: "retirement", label: "Retirement" },
];

type ChartRange = "1M" | "6M" | "1Y" | "ALL";

const RANGE_TO_PERIOD: Record<ChartRange, NetWorthPeriod> = {
  "1M": "daily",
  "6M": "weekly",
  "1Y": "monthly",
  ALL: "all",
};

function toDashboardShape(
  household: HouseholdDashboardResponse,
  personalGrouped: DashboardResponse["groupedHoldings"] | undefined
): DashboardResponse {
  return {
    totalNetWorth: household.totalNetWorth,
    categoryTotals: household.categoryTotals,
    groupedHoldings: personalGrouped ?? {
      crypto: [],
      stocks: [],
      cash: [],
      realEstate: [],
      retirement: [],
    },
  };
}

export default function DashboardPage() {
  const { data: household } = useHousehold();
  const inHousehold = household != null;
  const [preferPersonal, setPreferPersonal] = useState(false);
  const isHouseholdView = inHousehold && !preferPersonal;

  const [chartRange, setChartRange] = useState<ChartRange>("6M");
  const [assetCategory, setAssetCategory] = useState<Category | "all">("all");
  const [addTransactionOpen, setAddTransactionOpen] = useState(false);
  const [chartNowMs] = useState(() => Date.now());

  const personalDashboard = useDashboard();
  const householdDashboard = useDashboardHousehold({
    enabled: inHousehold && isHouseholdView,
  });

  const personalHistoryRange = useNetWorthHistory(RANGE_TO_PERIOD[chartRange]);
  const householdHistoryRange = useNetWorthHistoryHousehold(RANGE_TO_PERIOD[chartRange], {
    enabled: inHousehold && isHouseholdView,
  });

  const personalDaily = useNetWorthHistory("daily");
  const householdDaily = useNetWorthHistoryHousehold("daily", {
    enabled: inHousehold && isHouseholdView,
  });

  const historyRangeActive = isHouseholdView ? householdHistoryRange : personalHistoryRange;
  const historyDailyActive = isHouseholdView ? householdDaily : personalDaily;

  const createTx = useCreateTransaction();
  const refreshPrices = useRefreshPrices();

  const d: DashboardResponse | undefined = useMemo(() => {
    if (isHouseholdView) {
      const h = householdDashboard.data;
      if (!h) return undefined;
      return toDashboardShape(h, personalDashboard.data?.groupedHoldings);
    }
    return personalDashboard.data;
  }, [isHouseholdView, householdDashboard.data, personalDashboard.data]);

  const loading = isHouseholdView ? householdDashboard.isLoading : personalDashboard.isLoading;
  const dashboardQueryError = isHouseholdView
    ? householdDashboard.isError
    : personalDashboard.isError;
  const dashboardError = isHouseholdView ? householdDashboard.error : personalDashboard.error;

  const chartSnapshots = useMemo(() => {
    const raw = historyRangeActive.data?.snapshots ?? [];
    if (chartRange !== "1M") return raw;
    const cutoff = chartNowMs - 30 * 24 * 60 * 60 * 1000;
    return raw.filter((s) => new Date(s.date).getTime() >= cutoff);
  }, [historyRangeActive.data?.snapshots, chartRange, chartNowMs]);

  const monthChange = useMemo(
    () => computeApproxMonthChange(historyDailyActive.data?.snapshots ?? []),
    [historyDailyActive.data?.snapshots]
  );

  const groupedForFilter =
    assetCategory === "all"
      ? d?.groupedHoldings
      : d?.groupedHoldings
        ? { [assetCategory]: d.groupedHoldings[assetCategory] ?? [] }
        : undefined;

  const totals = d?.categoryTotals;
  const liquid = totals ? totals.cash : 0;
  const investments = totals ? totals.crypto + totals.stocks + totals.retirement : 0;
  const realEstate = totals?.realEstate ?? 0;

  const heroChange =
    monthChange != null
      ? {
          abs: monthChange.absolute,
          pct: monthChange.percent,
        }
      : null;

  return (
    <div className="space-y-8">
      {inHousehold ? (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-muted-foreground font-mono text-[10px] tracking-[0.12em] uppercase">
            View
          </span>
          <div
            className="bg-secondary flex gap-1 rounded-md p-0.5"
            role="group"
            aria-label="Dashboard scope"
          >
            <button
              type="button"
              className={cn(
                "rounded px-3 py-1.5 font-mono text-xs transition-colors",
                isHouseholdView
                  ? "border-primary/20 bg-card text-primary border"
                  : "text-muted-foreground hover:text-foreground"
              )}
              onClick={() => setPreferPersonal(false)}
            >
              Household
            </button>
            <button
              type="button"
              className={cn(
                "rounded px-3 py-1.5 font-mono text-xs transition-colors",
                !isHouseholdView
                  ? "border-primary/20 bg-card text-primary border"
                  : "text-muted-foreground hover:text-foreground"
              )}
              onClick={() => setPreferPersonal(true)}
            >
              Just me
            </button>
          </div>
        </div>
      ) : null}

      <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
        <div className="space-y-6">
          <StatCard
            variant="hero"
            title={isHouseholdView ? "Household net worth" : "Total net worth"}
            value={formatCurrency(d?.totalNetWorth ?? 0)}
            loading={loading}
          />
          {heroChange ? (
            <div
              className={cn(
                "inline-flex items-center gap-1.5 font-mono text-[13px]",
                heroChange.abs >= 0 ? "text-primary" : "text-destructive"
              )}
            >
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden>
                <polyline
                  points="1,9 5,4 8,7 11,2"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
              <span>
                {heroChange.abs >= 0 ? "+" : ""}
                {formatCurrency(heroChange.abs)} ({heroChange.pct >= 0 ? "+" : ""}
                {heroChange.pct.toFixed(1)}%)
              </span>
              <span className="text-muted-foreground text-[11px] font-normal">last ~30 days</span>
            </div>
          ) : (
            <p className="text-muted-foreground text-[13px]">Add history to see trailing change.</p>
          )}
        </div>
        <div className="flex flex-wrap items-center gap-2 lg:pt-2">
          <Button
            type="button"
            className="rounded-md px-[18px] py-2.5 font-mono text-xs font-medium tracking-wide hover:shadow-[0_4px_20px_rgba(200,245,100,0.3)]"
            onClick={() => setAddTransactionOpen(true)}
          >
            <Plus className="mr-2 size-3.5" strokeWidth={2} />
            Add transaction
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="font-mono text-xs"
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
            <RefreshCw className={cn("mr-2 size-4", refreshPrices.isPending && "animate-spin")} />
            Refresh prices
          </Button>
        </div>
      </div>

      {dashboardQueryError ? (
        <p className="text-destructive text-sm">
          {dashboardError instanceof Error ? dashboardError.message : "Failed to load dashboard"}
        </p>
      ) : null}

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <div className="bg-card hover:border-foreground/15 rounded-xl border p-5 transition-colors">
          <p className="text-muted-foreground mb-2.5 text-[10px] tracking-[0.1em] uppercase">
            Liquid assets
          </p>
          {loading ? (
            <div className="bg-muted h-7 w-28 animate-pulse rounded" />
          ) : (
            <p className="font-heading text-[22px] font-semibold tabular-nums">
              {formatCurrency(liquid)}
            </p>
          )}
          <p className="text-muted-foreground mt-1.5 text-[11px]">Cash</p>
        </div>
        <div className="bg-card hover:border-foreground/15 rounded-xl border p-5 transition-colors">
          <p className="text-muted-foreground mb-2.5 text-[10px] tracking-[0.1em] uppercase">
            Investments
          </p>
          {loading ? (
            <div className="bg-muted h-7 w-28 animate-pulse rounded" />
          ) : (
            <p className="font-heading text-[22px] font-semibold tabular-nums">
              {formatCurrency(investments)}
            </p>
          )}
          <p className="text-primary mt-1.5 text-[11px]">Stocks + crypto + retirement</p>
        </div>
        <div className="bg-card hover:border-foreground/15 rounded-xl border p-5 transition-colors">
          <p className="text-muted-foreground mb-2.5 text-[10px] tracking-[0.1em] uppercase">
            Real estate
          </p>
          {loading ? (
            <div className="bg-muted h-7 w-28 animate-pulse rounded" />
          ) : (
            <p className="font-heading text-[22px] font-semibold tabular-nums">
              {formatCurrency(realEstate)}
            </p>
          )}
          <p className="text-muted-foreground mt-1.5 text-[11px]">Property value</p>
        </div>
        <div className="bg-card hover:border-foreground/15 rounded-xl border p-5 transition-colors">
          <p className="text-muted-foreground mb-2.5 text-[10px] tracking-[0.1em] uppercase">
            ~30 day change
          </p>
          {loading ? (
            <div className="bg-muted h-7 w-28 animate-pulse rounded" />
          ) : monthChange ? (
            <p
              className={cn(
                "font-heading text-[22px] font-semibold tabular-nums",
                monthChange.absolute >= 0 ? "text-primary" : "text-destructive"
              )}
            >
              {monthChange.absolute >= 0 ? "+" : ""}
              {formatCurrency(monthChange.absolute)}
            </p>
          ) : (
            <p className="text-muted-foreground font-heading text-[22px] font-semibold">—</p>
          )}
          <p
            className={cn(
              "mt-1.5 text-[11px]",
              monthChange && monthChange.percent >= 0
                ? "text-primary"
                : monthChange
                  ? "text-destructive"
                  : "text-muted-foreground"
            )}
          >
            {monthChange
              ? `${monthChange.percent >= 0 ? "+" : ""}${monthChange.percent.toFixed(1)}% vs ~30d ago`
              : "Need more history"}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1fr_340px]">
        <div className="bg-card rounded-2xl border p-7">
          <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
            <h2 className="font-heading text-sm font-semibold">Net worth over time</h2>
            <div className="bg-secondary flex gap-1 rounded-md p-0.5">
              {(["1M", "6M", "1Y", "ALL"] as const).map((r) => (
                <button
                  key={r}
                  type="button"
                  className={cn(
                    "rounded px-2.5 py-1 font-mono text-[11px] transition-colors",
                    chartRange === r
                      ? "border-primary/20 bg-card text-primary border"
                      : "text-muted-foreground hover:text-foreground"
                  )}
                  onClick={() => setChartRange(r)}
                >
                  {r}
                </button>
              ))}
            </div>
          </div>
          <div className="h-[260px]">
            <NetWorthChart data={chartSnapshots} loading={historyRangeActive.isLoading} />
          </div>
          {historyRangeActive.isError ? (
            <p className="text-destructive mt-2 text-sm">Could not load history.</p>
          ) : null}
        </div>

        <div className="bg-card rounded-2xl border p-7">
          <div className="mb-6">
            <h2 className="font-heading text-sm font-semibold">Allocation</h2>
          </div>
          <CategorySummaryList
            totals={d?.categoryTotals}
            total={d?.totalNetWorth ?? 0}
            loading={loading}
          />
        </div>
      </div>

      {isHouseholdView ? (
        <section className="space-y-4">
          <h2 className="font-heading text-sm font-semibold">Household members</h2>
          <HouseholdMemberSections
            members={householdDashboard.data?.members ?? []}
            loading={householdDashboard.isLoading}
          />
        </section>
      ) : (
        <section className="space-y-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <h2 className="font-heading text-sm font-semibold">Holdings</h2>
            <div className="flex flex-wrap gap-1">
              {CATEGORY_CHIPS.map(({ key, label }) => (
                <button
                  key={key}
                  type="button"
                  className={cn(
                    "rounded-md border border-transparent px-3 py-1.5 font-mono text-[11px] transition-colors",
                    assetCategory === key
                      ? "border-border bg-card text-foreground"
                      : "text-muted-foreground hover:text-foreground"
                  )}
                  onClick={() => setAssetCategory(key)}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <HoldingsGrid
            grouped={groupedForFilter}
            totalNetWorth={d?.totalNetWorth ?? 0}
            loading={loading}
            categoryFilter={assetCategory}
          />
        </section>
      )}

      <TransactionFormDialog
        open={addTransactionOpen}
        onOpenChange={setAddTransactionOpen}
        initial={null}
        title="Add transaction"
        pending={createTx.isPending}
        defaultCategory={assetCategory === "all" ? undefined : assetCategory}
        onSubmit={async (payload) => {
          try {
            await createTx.mutateAsync(payload);
            toast.success("Transaction added");
          } catch (e) {
            toast.error(e instanceof Error ? e.message : "Create failed");
            throw e;
          }
        }}
      />
    </div>
  );
}
