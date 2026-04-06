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
