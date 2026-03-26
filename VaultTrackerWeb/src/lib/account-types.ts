import type { AccountType, Category } from "@/types/api";

export const ACCOUNT_TYPES_BY_CATEGORY: Record<Category, AccountType[]> = {
  crypto: ["cryptoExchange", "other"],
  stocks: ["brokerage", "other"],
  cash: ["bank", "other"],
  realEstate: ["other", "bank"],
  retirement: ["retirement", "brokerage", "other"],
};

export function defaultAccountType(cat: Category): AccountType {
  return ACCOUNT_TYPES_BY_CATEGORY[cat][0];
}
