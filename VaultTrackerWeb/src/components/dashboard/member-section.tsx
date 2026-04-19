"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";
import type { HouseholdMemberDashboard } from "@/types/api";
import { formatCurrency } from "@/lib/format";
import { cn } from "@/lib/utils";
import { CategorySummaryList } from "@/components/dashboard/category-summary-list";
import { HoldingsGrid } from "@/components/dashboard/holdings-grid";

function memberLabel(m: HouseholdMemberDashboard): string {
  return m.email?.trim() || m.userId;
}

export function HouseholdMemberSections({
  members,
  loading,
}: {
  members: HouseholdMemberDashboard[];
  loading?: boolean;
}) {
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});

  const isExpanded = (userId: string) => expanded[userId] !== false;

  const toggle = (userId: string) => {
    setExpanded((prev) => {
      const current = prev[userId] !== false;
      return { ...prev, [userId]: !current };
    });
  };

  if (loading) {
    return (
      <div className="space-y-3">
        {[1, 2].map((i) => (
          <div key={i} className="bg-muted/40 h-16 animate-pulse rounded-2xl border" />
        ))}
      </div>
    );
  }

  return (
    <section className="space-y-3" aria-label="Household members">
      {members.map((m) => {
        const open = isExpanded(m.userId);
        return (
          <div key={m.userId} className="bg-card overflow-hidden rounded-2xl border">
            <button
              type="button"
              aria-expanded={open}
              aria-label={`${open ? "Collapse" : "Expand"} holdings for ${memberLabel(m)}`}
              className="hover:bg-secondary/60 flex w-full items-center justify-between gap-3 border-b px-5 py-4 text-left transition-colors outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 last:border-b-0"
              onClick={() => toggle(m.userId)}
            >
              <div className="min-w-0">
                <p className="font-heading text-[13px] font-semibold tracking-tight">
                  {memberLabel(m)}
                </p>
                <p className="text-muted-foreground text-[11px]">Member portfolio</p>
              </div>
              <div className="flex shrink-0 items-center gap-3">
                <span className="font-mono text-sm font-medium tabular-nums">
                  {formatCurrency(m.totalNetWorth)}
                </span>
                <ChevronDown
                  className={cn(
                    "text-muted-foreground size-4 shrink-0 transition-transform",
                    !open && "-rotate-90"
                  )}
                  aria-hidden
                />
              </div>
            </button>
            {open ? (
              <div className="space-y-6 px-5 py-5">
                <div>
                  <h3 className="text-muted-foreground mb-3 text-[10px] font-medium tracking-[0.1em] uppercase">
                    Allocation
                  </h3>
                  <CategorySummaryList
                    totals={m.categoryTotals}
                    total={m.totalNetWorth}
                    loading={false}
                  />
                </div>
                <div>
                  <h3 className="text-muted-foreground mb-3 text-[10px] font-medium tracking-[0.1em] uppercase">
                    Holdings
                  </h3>
                  <HoldingsGrid
                    grouped={m.groupedHoldings}
                    totalNetWorth={m.totalNetWorth}
                    loading={false}
                    categoryFilter="all"
                  />
                </div>
              </div>
            ) : null}
          </div>
        );
      })}
    </section>
  );
}
