"use client";

import { FireHeroHeadline } from "@/components/fire/fire-hero-headline";
import { FireInputsForm } from "@/components/fire/fire-inputs-form";
import { FireProjectionChart } from "@/components/fire/fire-projection-chart";
import { FireSummaryCards } from "@/components/fire/fire-summary-cards";
import { FireTargetsTable } from "@/components/fire/fire-targets-table";
import { useFireProfile, useFireProjection } from "@/lib/queries/use-fire";
import { formatCurrency } from "@/lib/format";
import type { FireProjectionResponse } from "@/types/api";

function FireGoalNote({ projection }: { projection: FireProjectionResponse }) {
  const g = projection.goalAssessment;
  if (!g) return null;
  return (
    <div
      className="bg-muted/40 text-muted-foreground rounded-lg border border-border px-3 py-2 text-sm"
      data-slot="fire-goal-note"
    >
      <p>
        <span className="text-foreground font-medium">Retirement goal (age {g.targetAge}):</span>{" "}
        {g.status === "ahead" && "Ahead of the Regular FIRE target at that age."}
        {g.status === "on_track" && "Roughly on track (within 5% of the target)."}
        {g.status === "behind" && "Behind the Regular FIRE target at that age."} Gap{" "}
        {formatCurrency(g.gapAmount)} vs target. Suggested savings rate{" "}
        {(g.requiredSavingsRate * 100).toFixed(0)}% of income; you save{" "}
        {(g.currentSavingsRate * 100).toFixed(0)}%.
      </p>
      {g.computedBeyondProjectionHorizon ? (
        <p className="mt-1 text-xs italic">
          Projected wealth at your goal age uses the same assumptions as the chart, extended past
          the 30-year window.
        </p>
      ) : null}
    </div>
  );
}

export default function FirePage() {
  const profileQ = useFireProfile();
  const hasProfile = profileQ.isSuccess && profileQ.data != null;
  const projectionQ = useFireProjection({ enabled: hasProfile });

  const profile = profileQ.data ?? null;
  const projection = projectionQ.data;

  const projectionBusy = hasProfile && (projectionQ.isLoading || projectionQ.isFetching);

  return (
    <section aria-labelledby="fire-title" className="space-y-8">
      <div>
        <h1 id="fire-title" className="font-serif text-2xl tracking-tight text-foreground">
          FIRE calculator
        </h1>
        <p className="text-muted-foreground mt-1 text-sm">
          Simulations use your saved inputs plus live portfolio totals (same as the dashboard).
        </p>
      </div>

      {profileQ.isError ? (
        <p className="text-destructive text-sm" role="alert">
          Could not load your FIRE profile. Check your connection and try again.
        </p>
      ) : null}

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2 lg:gap-10">
        <div className="space-y-6">
          <FireHeroHeadline projection={projection} loading={projectionBusy} />
          <FireInputsForm
            profile={profile}
            projection={projection}
            projectionLoading={projectionBusy}
          />
        </div>

        <div className="space-y-6" aria-label="FIRE projection results">
          {projectionQ.isError ? (
            <p className="text-destructive text-sm" role="alert">
              Could not load projection.
            </p>
          ) : null}

          <FireSummaryCards projection={projection} loading={projectionBusy} />

          {projection?.status === "unreachable" ? (
            <div
              className="bg-muted/50 rounded-lg border border-dashed border-border px-4 py-10 text-center"
              data-slot="fire-unreachable-panel"
            >
              <p className="text-muted-foreground text-sm">
                Chart is hidden when annual savings are zero or negative.
              </p>
            </div>
          ) : projection && projection.projectionCurve.length > 0 ? (
            <FireProjectionChart projection={projection} />
          ) : hasProfile && !projectionBusy && projection ? (
            <p className="text-muted-foreground text-sm">No projection curve available.</p>
          ) : null}

          {projection ? (
            <>
              <FireTargetsTable targets={projection.fireTargets} />
              <FireGoalNote projection={projection} />
            </>
          ) : null}
        </div>
      </div>
    </section>
  );
}
