export type Category = "crypto" | "stocks" | "cash" | "realEstate" | "retirement";

export type AccountType = "cryptoExchange" | "brokerage" | "bank" | "retirement" | "other";

export type TransactionType = "buy" | "sell";

export type NetWorthPeriod = "daily" | "weekly" | "monthly" | "all";

export interface CategoryTotals {
  crypto: number;
  stocks: number;
  cash: number;
  realEstate: number;
  retirement: number;
}

export interface HoldingItem {
  id: string;
  name: string;
  symbol: string | null;
  quantity: number;
  current_value: number;
}

export interface DashboardResponse {
  totalNetWorth: number;
  categoryTotals: CategoryTotals;
  groupedHoldings: Record<string, HoldingItem[]>;
}

export interface EnrichedTransaction {
  id: string;
  user_id: string;
  asset_id: string;
  account_id: string;
  transaction_type: TransactionType;
  quantity: number;
  price_per_unit: number;
  total_value: number;
  date: string;
  asset: {
    id: string;
    name: string;
    symbol: string | null;
    category: Category;
  };
  account: {
    id: string;
    name: string;
    account_type: AccountType;
  };
}

export interface AccountResponse {
  id: string;
  name: string;
  account_type: AccountType;
  created_at: string;
}

export interface AssetResponse {
  id: string;
  user_id: string;
  name: string;
  symbol: string | null;
  category: Category;
  quantity: number;
  current_value: number;
  last_updated: string;
}

export interface AllocationEntry {
  value: number;
  percentage: number;
}

export interface AnalyticsResponse {
  allocation: Record<string, AllocationEntry>;
  performance: {
    totalGainLoss: number;
    totalGainLossPercent: number;
    costBasis: number;
    currentValue: number;
  };
}

export interface NetWorthHistoryResponse {
  snapshots: Array<{ date: string; value: number }>;
}

/** GET /households/me, POST /households, POST /households/join */
export interface HouseholdMember {
  userId: string;
  email: string | null;
}

export interface HouseholdResponse {
  id: string;
  createdAt: string;
  members: HouseholdMember[];
}

export interface HouseholdInviteCodeResponse {
  code: string;
  expiresAt: string;
}

export interface HouseholdJoinRequest {
  code: string;
}

/** GET /dashboard/household */
export interface HouseholdMemberDashboard {
  userId: string;
  email: string | null;
  totalNetWorth: number;
  categoryTotals: CategoryTotals;
  groupedHoldings: Record<string, HoldingItem[]>;
}

export interface HouseholdDashboardResponse {
  householdId: string;
  totalNetWorth: number;
  categoryTotals: CategoryTotals;
  members: HouseholdMemberDashboard[];
}

export interface PriceRefreshResponse {
  updated: Array<{
    asset_id: string;
    symbol: string;
    old_value: number;
    new_value: number;
    price: number;
  }>;
  skipped: string[];
  errors: Array<{ symbol: string; error: string }>;
}

export interface SinglePriceResponse {
  symbol: string;
  price: number;
  source: string;
}

export interface SmartTransactionCreate {
  transaction_type: TransactionType;
  category: Category;
  asset_name: string;
  symbol?: string;
  quantity: number;
  price_per_unit: number;
  account_name: string;
  account_type: AccountType;
  date?: string;
}

export interface AccountCreate {
  name: string;
  account_type: AccountType;
}

export interface AccountUpdate {
  name?: string;
  account_type?: AccountType;
}

/** FIRE calculator PUT body / form — infer from Zod in `@/lib/fire/fire-input-schema`. */
export type { FireProfileInputForm } from "@/lib/fire/fire-input-schema";

export type FireProjectionStatus = "reachable" | "beyond_horizon" | "unreachable";

export interface FireProfileResponse {
  id: string;
  currentAge: number;
  annualIncome: number;
  annualExpenses: number;
  targetRetirementAge: number | null;
  createdAt: string;
  updatedAt: string;
}

/** GET /households/me/fire-profile — same shape as personal profile */
export type HouseholdFireProfile = FireProfileResponse;

export interface FireProjectionInputs {
  currentAge: number;
  annualIncome: number;
  annualExpenses: number;
  currentNetWorth: number;
  targetRetirementAge: number | null;
}

export interface FireAllocationSlice {
  value: number;
  percentage: number;
  expectedReturn: number;
}

export interface FireAllocation {
  crypto: FireAllocationSlice;
  stocks: FireAllocationSlice;
  cash: FireAllocationSlice;
  realEstate: FireAllocationSlice;
  retirement: FireAllocationSlice;
}

export interface FireTargetTier {
  targetAmount: number;
  yearsToTarget: number | null;
  targetAge: number | null;
}

export interface FireTargets {
  leanFire: FireTargetTier;
  fire: FireTargetTier;
  fatFire: FireTargetTier;
}

export interface FireProjectionCurvePoint {
  age: number;
  year: number;
  projectedValue: number;
}

export interface FireMonthlyBreakdown {
  monthlySurplus: number;
  monthsToFire: number | null;
}

export type FireGoalAssessmentStatus = "ahead" | "on_track" | "behind";

export interface FireGoalAssessment {
  targetAge: number;
  requiredSavingsRate: number;
  currentSavingsRate: number;
  status: FireGoalAssessmentStatus;
  gapAmount: number;
  /** True when goal age is past the chart window; figures use the same model extrapolated. */
  computedBeyondProjectionHorizon: boolean;
}

export interface FireProjectionResponse {
  status: FireProjectionStatus;
  unreachableReason: "non_positive_savings" | null;
  inputs: FireProjectionInputs;
  allocation: FireAllocation | null;
  blendedReturn: number | null;
  realBlendedReturn: number | null;
  inflationRate: number | null;
  annualSavings: number | null;
  savingsRate: number | null;
  fireTargets: FireTargets;
  projectionCurve: FireProjectionCurvePoint[];
  monthlyBreakdown: FireMonthlyBreakdown;
  goalAssessment: FireGoalAssessment | null;
}
