import { z } from "zod";
import type { Category, EnrichedTransaction } from "@/types/api";
import { defaultAccountType } from "@/lib/account-types";

const categories = [
  "crypto",
  "stocks",
  "cash",
  "realEstate",
  "retirement",
] as const;

export const transactionSchema = z
  .object({
    transaction_type: z.enum(["buy", "sell"]),
    category: z.enum(categories),
    asset_name: z.string().min(1, "Required"),
    symbol: z.string().optional(),
    quantity: z.number().positive(),
    price_per_unit: z.number().positive(),
    account_name: z.string().min(1, "Required"),
    account_type: z.enum([
      "cryptoExchange",
      "brokerage",
      "bank",
      "retirement",
      "other",
    ]),
    date: z.string().min(1),
  })
  .superRefine((data, ctx) => {
    if (
      (data.category === "crypto" ||
        data.category === "stocks" ||
        data.category === "retirement") &&
      !data.symbol?.trim()
    ) {
      ctx.addIssue({
        code: "custom",
        message: "Symbol is required",
        path: ["symbol"],
      });
    }
  });

export type TransactionFormValues = z.infer<typeof transactionSchema>;

export function needsSymbol(cat: Category): boolean {
  return cat === "crypto" || cat === "stocks" || cat === "retirement";
}

export function isCashLike(cat: Category): boolean {
  return cat === "cash" || cat === "realEstate";
}

export function toFormDefaults(tx?: EnrichedTransaction | null): TransactionFormValues {
  if (!tx) {
    const cat: Category = "crypto";
    return {
      transaction_type: "buy",
      category: cat,
      asset_name: "",
      symbol: "",
      quantity: 1,
      price_per_unit: 1,
      account_name: "",
      account_type: defaultAccountType(cat),
      date: new Date().toISOString().slice(0, 10),
    };
  }
  return {
    transaction_type: tx.transaction_type,
    category: tx.asset.category,
    asset_name: tx.asset.name,
    symbol: tx.asset.symbol ?? "",
    quantity: tx.quantity,
    price_per_unit: tx.price_per_unit,
    account_name: tx.account.name,
    account_type: tx.account.account_type,
    date: tx.date.slice(0, 10),
  };
}
