"use client";

import { useMemo, useState } from "react";
import { Plus, RefreshCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { StatCard } from "@/components/dashboard/stat-card";
import { CategorySummaryList } from "@/components/dashboard/category-summary-list";
import { NetWorthChart } from "@/components/dashboard/net-worth-chart";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";
import { TransactionFormDialog } from "@/components/transactions/transaction-form";
import { useDashboard } from "@/lib/queries/use-dashboard";
import { useNetWorthHistory } from "@/lib/queries/use-networth";
import { useRefreshPrices } from "@/lib/queries/use-prices";
import { useCreateTransaction } from "@/lib/queries/use-transactions";
import { formatCurrency } from "@/lib/format";
import { computeApproxMonthChange } from "@/lib/networth-change";
import type { Category, NetWorthPeriod } from "@/types/api";
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

export default function DashboardPage() {
  const [chartRange, setChartRange] = useState<ChartRange>("6M");
  const [assetCategory, setAssetCategory] = useState<Category | "all">("all");
  const [addTransactionOpen, setAddTransactionOpen] = useState(false);

  const dashboard = useDashboard();
  const createTx = useCreateTransaction();
  const historyForChart = useNetWorthHistory(RANGE_TO_PERIOD[chartRange]);
  const historyDaily = useNetWorthHistory("daily");
  const refreshPrices = useRefreshPrices();

  const d = dashboard.data;
  const loading = dashboard.isLoading;

  const chartSnapshots = useMemo(() => {
    const raw = historyForChart.data?.snapshots ?? [];
    if (chartRange !== "1M") return raw;
    const cutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;
    return raw.filter((s) => new Date(s.date).getTime() >= cutoff);
  }, [historyForChart.data?.snapshots, chartRange]);

  const monthChange = useMemo(
    () => computeApproxMonthChange(historyDaily.data?.snapshots ?? []),
    [historyDaily.data?.snapshots]
  );

  const groupedForFilter =
    assetCategory === "all"
      ? d?.groupedHoldings
      : d?.groupedHoldings
        ? { [assetCategory]: d.groupedHoldings[assetCategory] ?? [] }
        : undefined;

  const totals = d?.categoryTotals;
  const liquid = totals ? totals.cash : 0;
  const investments = totals
    ? totals.crypto + totals.stocks + totals.retirement
    : 0;
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
      <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
        <div className="space-y-6">
          <StatCard
            variant="hero"
            title="Total net worth"
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
              <svg
                width="12"
                height="12"
                viewBox="0 0 12 12"
                fill="none"
                aria-hidden
              >
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
          <p className="text-primary mt-1.5 text-[11px]">
            Stocks + crypto + retirement
          </p>
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
          <p className="text-muted-foreground mt-1.5 text-[11px]">
            Property value
          </p>
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
            <p className="text-muted-foreground font-heading text-[22px] font-semibold">
              —
            </p>
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
            <h2 className="font-heading text-sm font-semibold">
              Net worth over time
            </h2>
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
            <NetWorthChart
              data={chartSnapshots}
              loading={historyForChart.isLoading}
            />
          </div>
          {historyForChart.isError ? (
            <p className="text-destructive mt-2 text-sm">
              Could not load history.
            </p>
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

      <TransactionFormDialog
        open={addTransactionOpen}
        onOpenChange={setAddTransactionOpen}
        initial={null}
        title="Add transaction"
        pending={createTx.isPending}
        defaultCategory={
          assetCategory === "all" ? undefined : assetCategory
        }
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
