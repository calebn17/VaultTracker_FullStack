"use client";

import type { FireProjectionResponse } from "@/types/api";

export function FireHeroHeadline({
  projection,
  loading,
}: {
  projection: FireProjectionResponse | undefined;
  loading?: boolean;
}) {
  if (loading) {
    return (
      <div
        className="bg-muted/40 h-20 animate-pulse rounded-lg"
        aria-hidden
        data-slot="fire-hero-skeleton"
      />
    );
  }

  if (!projection) {
    return (
      <p className="text-muted-foreground text-sm" data-slot="fire-hero-empty">
        Save your inputs and run a simulation to see your FIRE trajectory.
      </p>
    );
  }

  if (projection.status === "unreachable") {
    return (
      <p className="text-foreground text-base leading-relaxed" role="status">
        At your current savings rate, FIRE is not achievable. Consider reducing expenses or
        increasing income.
      </p>
    );
  }

  if (projection.status === "beyond_horizon") {
    return (
      <p className="text-foreground text-base leading-relaxed" role="status">
        None of Lean, Regular, or Fat FIRE targets are reached within the 30-year projection window.
        The chart still shows projected wealth; target lines are for context.
      </p>
    );
  }

  const fire = projection.fireTargets.fire;
  if (fire.yearsToTarget != null && fire.targetAge != null) {
    const years = fire.yearsToTarget;
    const age = fire.targetAge;
    if (years === 0) {
      return (
        <p className="font-serif text-xl tracking-tight text-foreground md:text-2xl" role="status">
          You are already at or above your Regular FIRE target (age {age}).
        </p>
      );
    }
    return (
      <p className="font-serif text-xl tracking-tight text-foreground md:text-2xl" role="status">
        You can reach Regular FIRE in <strong className="text-primary">{years}</strong>{" "}
        {years === 1 ? "year" : "years"} by age <strong className="text-primary">{age}</strong>.
      </p>
    );
  }

  if (projection.fireTargets.leanFire.yearsToTarget != null) {
    const y = projection.fireTargets.leanFire.yearsToTarget;
    const a = projection.fireTargets.leanFire.targetAge;
    return (
      <p className="text-foreground text-base leading-relaxed" role="status">
        Lean FIRE is reachable in {y} {y === 1 ? "year" : "years"}
        {a != null ? ` (by age ${a})` : ""}. Regular FIRE is not reached within the 30-year window.
      </p>
    );
  }

  return (
    <p className="text-muted-foreground text-sm" role="status">
      A FIRE milestone is within the projection window; see targets and chart for details.
    </p>
  );
}
