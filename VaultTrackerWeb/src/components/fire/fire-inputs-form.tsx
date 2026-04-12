"use client";

import { useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { fireInputSchema, type FireProfileInputForm } from "@/lib/fire/fire-input-schema";
import { formatCurrency } from "@/lib/format";
import { useSaveFireProfile } from "@/lib/queries/use-fire";
import { ApiError } from "@/lib/api-client";
import type { FireAllocation, FireProfileResponse, FireProjectionResponse } from "@/types/api";

const CATEGORY_ORDER = ["crypto", "stocks", "cash", "realEstate", "retirement"] as const;
const CATEGORY_LABEL: Record<(typeof CATEGORY_ORDER)[number], string> = {
  crypto: "Crypto",
  stocks: "Stocks",
  cash: "Cash",
  realEstate: "Real estate",
  retirement: "Retirement",
};

const BAR_COLORS: Record<(typeof CATEGORY_ORDER)[number], string> = {
  crypto: "bg-amber-500",
  stocks: "bg-blue-500",
  cash: "bg-emerald-500",
  realEstate: "bg-orange-600",
  retirement: "bg-violet-500",
};

function FireAllocationBar({ allocation }: { allocation: FireAllocation | null | undefined }) {
  if (!allocation) {
    return (
      <p className="text-muted-foreground text-xs">
        No allocation breakdown (empty portfolio uses a default expected return).
      </p>
    );
  }
  return (
    <div className="space-y-1.5" data-slot="fire-allocation-bar">
      <div className="flex h-2.5 w-full overflow-hidden rounded-full bg-muted">
        {CATEGORY_ORDER.map((key) => {
          const pct = Math.max(0, Math.min(100, allocation[key].percentage));
          if (pct <= 0) return null;
          return (
            <div
              key={key}
              className={BAR_COLORS[key]}
              style={{ width: `${pct}%` }}
              title={`${CATEGORY_LABEL[key]}: ${pct.toFixed(1)}%`}
            />
          );
        })}
      </div>
      <ul className="text-muted-foreground flex flex-wrap gap-x-3 gap-y-0.5 text-[10px]">
        {CATEGORY_ORDER.map((key) => (
          <li key={key}>
            {CATEGORY_LABEL[key]} {allocation[key].percentage.toFixed(1)}%
          </li>
        ))}
      </ul>
    </div>
  );
}

export function FireInputsForm({
  profile,
  projection,
  projectionLoading,
}: {
  profile: FireProfileResponse | null | undefined;
  projection: FireProjectionResponse | undefined;
  projectionLoading?: boolean;
}) {
  const save = useSaveFireProfile();

  const form = useForm<FireProfileInputForm>({
    resolver: zodResolver(fireInputSchema),
    defaultValues: {
      currentAge: 30,
      annualIncome: 0,
      annualExpenses: 0,
      targetRetirementAge: null,
    },
  });

  useEffect(() => {
    if (profile) {
      form.reset({
        currentAge: profile.currentAge,
        annualIncome: profile.annualIncome,
        annualExpenses: profile.annualExpenses,
        targetRetirementAge: profile.targetRetirementAge,
      });
    }
  }, [profile, form]);

  const onSubmit = form.handleSubmit(async (values) => {
    try {
      await save.mutateAsync({
        ...values,
        targetRetirementAge: values.targetRetirementAge ?? null,
      });
    } catch {
      /* surfaced below */
    }
  });

  const nw = projection?.inputs.currentNetWorth;
  const blended = projection?.blendedReturn;
  const realR = projection?.realBlendedReturn;
  const infl = projection?.inflationRate ?? 0.03;

  const returnLabel =
    projectionLoading || !projection
      ? "—"
      : realR != null && blended != null
        ? `${(realR * 100).toFixed(1)}% real (${(blended * 100).toFixed(1)}% nominal − ${(infl * 100).toFixed(0)}% inflation)`
        : "—";

  const saveErr = save.error;
  const errMessage =
    saveErr instanceof ApiError ? saveErr.message : saveErr ? "Could not save profile." : null;

  return (
    <Card data-slot="fire-inputs-form">
      <CardHeader>
        <CardTitle className="text-base">Inputs</CardTitle>
      </CardHeader>
      <form onSubmit={onSubmit}>
        <CardContent className="space-y-4">
          <div className="grid gap-2">
            <label htmlFor="fire-current-age" className="text-muted-foreground text-xs font-medium">
              Current age (yrs)
            </label>
            <Input
              id="fire-current-age"
              type="number"
              min={18}
              max={100}
              aria-invalid={!!form.formState.errors.currentAge}
              {...form.register("currentAge", { valueAsNumber: true })}
            />
            {form.formState.errors.currentAge ? (
              <p className="text-destructive text-xs">{form.formState.errors.currentAge.message}</p>
            ) : null}
          </div>

          <div className="grid gap-2">
            <label htmlFor="fire-income" className="text-muted-foreground text-xs font-medium">
              Annual income, post-tax
            </label>
            <Input
              id="fire-income"
              type="number"
              min={0}
              step="1000"
              aria-invalid={!!form.formState.errors.annualIncome}
              {...form.register("annualIncome", { valueAsNumber: true })}
            />
            {form.formState.errors.annualIncome ? (
              <p className="text-destructive text-xs">
                {form.formState.errors.annualIncome.message}
              </p>
            ) : null}
          </div>

          <div className="grid gap-2">
            <label htmlFor="fire-expenses" className="text-muted-foreground text-xs font-medium">
              Annual expenses
            </label>
            <Input
              id="fire-expenses"
              type="number"
              min={0}
              step="1000"
              aria-invalid={!!form.formState.errors.annualExpenses}
              {...form.register("annualExpenses", { valueAsNumber: true })}
            />
            {form.formState.errors.annualExpenses ? (
              <p className="text-destructive text-xs">
                {form.formState.errors.annualExpenses.message}
              </p>
            ) : null}
          </div>

          <div className="grid gap-2">
            <label htmlFor="fire-target-age" className="text-muted-foreground text-xs font-medium">
              Target retirement age (optional)
            </label>
            <Input
              id="fire-target-age"
              type="number"
              min={19}
              max={100}
              placeholder="Optional"
              aria-invalid={!!form.formState.errors.targetRetirementAge}
              {...form.register("targetRetirementAge", {
                setValueAs: (v) => (v === "" || v === undefined || v === null ? null : Number(v)),
              })}
            />
            {form.formState.errors.targetRetirementAge ? (
              <p className="text-destructive text-xs">
                {form.formState.errors.targetRetirementAge.message}
              </p>
            ) : null}
          </div>

          <div className="border-border space-y-2 border-t pt-4">
            <p className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
              From your portfolio
            </p>
            <div className="grid gap-1">
              <span className="text-muted-foreground text-xs">Current net worth</span>
              <span className="font-mono text-sm font-medium tabular-nums">
                {projectionLoading ? "…" : nw != null ? formatCurrency(nw) : "—"}
              </span>
            </div>
            <FireAllocationBar allocation={projection?.allocation ?? null} />
            <div className="grid gap-1">
              <span className="text-muted-foreground text-xs">Blended expected return</span>
              <span className="font-mono text-sm leading-snug">{returnLabel}</span>
            </div>
          </div>

          {errMessage ? <p className="text-destructive text-sm">{errMessage}</p> : null}
        </CardContent>
        <CardFooter className="flex flex-col gap-2 sm:flex-row sm:justify-end">
          <Button type="submit" disabled={save.isPending} className="w-full sm:w-auto">
            {save.isPending ? "Saving…" : "Run simulation"}
          </Button>
        </CardFooter>
      </form>
    </Card>
  );
}
