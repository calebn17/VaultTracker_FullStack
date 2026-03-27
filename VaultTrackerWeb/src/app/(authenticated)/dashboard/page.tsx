"use client";

import { useState } from "react";
import { RefreshCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { StatCard } from "@/components/dashboard/stat-card";
import { CategoryBar } from "@/components/dashboard/category-bar";
import { CategorySummaryList } from "@/components/dashboard/category-summary-list";
import { NetWorthChart } from "@/components/dashboard/net-worth-chart";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";
import { TransactionFormDialog } from "@/components/transactions/transaction-form";
import { useDashboard } from "@/lib/queries/use-dashboard";
import { useNetWorthHistory } from "@/lib/queries/use-networth";
import { useAssets } from "@/lib/queries/use-assets";
import { useRefreshPrices } from "@/lib/queries/use-prices";
import { useCreateTransaction } from "@/lib/queries/use-transactions";
import { formatCurrency } from "@/lib/format";
import type { Category, NetWorthPeriod } from "@/types/api";
import { cn } from "@/lib/utils";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
  { key: "realEstate", label: "Real Estate" },
  { key: "retirement", label: "Retirement" },
];

export default function DashboardPage() {
  const [period, setPeriod] = useState<NetWorthPeriod>("daily");
  const [assetCategory, setAssetCategory] = useState<Category | "all">("all");
  const [addTransactionOpen, setAddTransactionOpen] = useState(false);

  const dashboard = useDashboard();
  const createTx = useCreateTransaction();
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
      <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
        <div className="space-y-4">
          <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
          <StatCard
            variant="hero"
            title="Total net worth"
            value={formatCurrency(d?.totalNetWorth ?? 0)}
            loading={loading}
          />
        </div>
        <div className="flex flex-wrap items-center gap-2 lg:pt-1">
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

      <div className="grid gap-6 lg:grid-cols-12 lg:items-start">
        <Card className="lg:col-span-8">
          <CardHeader className="border-b border-border/60">
            <CardTitle>Net worth history</CardTitle>
          </CardHeader>
          <CardContent className="pt-4">
            <NetWorthChart
              data={history.data?.snapshots ?? []}
              loading={history.isLoading}
            />
            {history.isError ? (
              <p className="text-destructive text-sm">Could not load history.</p>
            ) : null}
          </CardContent>
        </Card>

        <div className="flex flex-col gap-4 lg:col-span-4">
          <Card size="sm">
            <CardHeader className="border-b border-border/60">
              <CardTitle>By category</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 pt-4">
              <CategorySummaryList
                totals={d?.categoryTotals}
                loading={loading}
              />
              <div className="space-y-2">
                <p className="text-muted-foreground text-xs font-medium">
                  Allocation
                </p>
                <CategoryBar
                  totals={d?.categoryTotals}
                  total={d?.totalNetWorth ?? 0}
                  loading={loading}
                  showLegend={false}
                />
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      <section className="space-y-3">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-lg font-medium">Holdings</h2>
          <div className="flex flex-wrap items-center gap-2">
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
            <Button
              type="button"
              size="sm"
              onClick={() => setAddTransactionOpen(true)}
            >
              Add transaction
            </Button>
          </div>
        </div>
        <HoldingsGrid
          grouped={groupedForFilter}
          loading={loading || assetsFiltered.isLoading}
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
        onSubmit={(payload) => {
          createTx.mutate(payload, {
            onSuccess: () => {
              toast.success("Transaction added");
              setAddTransactionOpen(false);
            },
            onError: (e) =>
              toast.error(e instanceof Error ? e.message : "Create failed"),
          });
        }}
      />
    </div>
  );
}
