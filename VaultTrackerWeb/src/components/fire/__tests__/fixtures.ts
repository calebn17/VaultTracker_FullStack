import type { FireProjectionResponse } from "@/types/api";

const baseInputs = {
  currentAge: 35,
  annualIncome: 120_000,
  annualExpenses: 55_000,
  currentNetWorth: 250_000,
  targetRetirementAge: 55 as number | null,
};

export const fireProjectionReachable: FireProjectionResponse = {
  status: "reachable",
  unreachableReason: null,
  inputs: { ...baseInputs },
  allocation: {
    crypto: { value: 25_000, percentage: 10, expectedReturn: 0.1 },
    stocks: { value: 125_000, percentage: 50, expectedReturn: 0.08 },
    cash: { value: 25_000, percentage: 10, expectedReturn: 0.02 },
    realEstate: { value: 50_000, percentage: 20, expectedReturn: 0.05 },
    retirement: { value: 25_000, percentage: 10, expectedReturn: 0.07 },
  },
  blendedReturn: 0.07,
  realBlendedReturn: 0.04,
  inflationRate: 0.03,
  annualSavings: 65_000,
  savingsRate: 65_000 / 120_000,
  fireTargets: {
    leanFire: { targetAmount: 962_500, yearsToTarget: 8, targetAge: 43 },
    fire: { targetAmount: 1_375_000, yearsToTarget: 12, targetAge: 47 },
    fatFire: { targetAmount: 2_062_500, yearsToTarget: 18, targetAge: 53 },
  },
  projectionCurve: Array.from({ length: 31 }, (_, i) => ({
    age: 35 + i,
    year: 2026 + i,
    projectedValue: 250_000 + i * 45_000,
  })),
  monthlyBreakdown: { monthlySurplus: 65_000 / 12, monthsToFire: 144 },
  goalAssessment: {
    targetAge: 55,
    requiredSavingsRate: 0.42,
    currentSavingsRate: 65_000 / 120_000,
    status: "on_track",
    gapAmount: 25_000,
    computedBeyondProjectionHorizon: false,
  },
};

export const fireProjectionUnreachable: FireProjectionResponse = {
  status: "unreachable",
  unreachableReason: "non_positive_savings",
  inputs: {
    ...baseInputs,
    annualIncome: 50_000,
    annualExpenses: 55_000,
    currentNetWorth: 100_000,
    targetRetirementAge: null,
  },
  allocation: null,
  blendedReturn: null,
  realBlendedReturn: null,
  inflationRate: null,
  annualSavings: null,
  savingsRate: null,
  fireTargets: {
    leanFire: { targetAmount: 962_500, yearsToTarget: null, targetAge: null },
    fire: { targetAmount: 1_375_000, yearsToTarget: null, targetAge: null },
    fatFire: { targetAmount: 2_062_500, yearsToTarget: null, targetAge: null },
  },
  projectionCurve: [],
  monthlyBreakdown: { monthlySurplus: 0, monthsToFire: null },
  goalAssessment: null,
};

export const fireProjectionBeyondHorizon: FireProjectionResponse = {
  status: "beyond_horizon",
  unreachableReason: null,
  inputs: { ...baseInputs, currentNetWorth: 10_000 },
  allocation: null,
  blendedReturn: 0.07,
  realBlendedReturn: 0.04,
  inflationRate: 0.03,
  annualSavings: 2_000,
  savingsRate: 2_000 / 120_000,
  fireTargets: {
    leanFire: { targetAmount: 962_500, yearsToTarget: null, targetAge: null },
    fire: { targetAmount: 1_375_000, yearsToTarget: null, targetAge: null },
    fatFire: { targetAmount: 2_062_500, yearsToTarget: null, targetAge: null },
  },
  projectionCurve: Array.from({ length: 31 }, (_, i) => ({
    age: 35 + i,
    year: 2026 + i,
    projectedValue: 10_000 + i * 1_500,
  })),
  monthlyBreakdown: { monthlySurplus: 2_000 / 12, monthsToFire: null },
  goalAssessment: {
    targetAge: 55,
    requiredSavingsRate: 0.55,
    currentSavingsRate: 2_000 / 120_000,
    status: "behind",
    gapAmount: 400_000,
    computedBeyondProjectionHorizon: true,
  },
};
