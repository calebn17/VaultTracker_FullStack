import { describe, expect, it } from "vitest";
import {
  isCashLike,
  needsSymbol,
  toFormDefaults,
  transactionSchema,
} from "@/lib/transaction-schema";
import type { EnrichedTransaction } from "@/types/api";

const baseValid = {
  transaction_type: "buy" as const,
  category: "crypto" as const,
  asset_name: "Bitcoin",
  symbol: "BTC",
  quantity: 1,
  price_per_unit: 50000,
  account_name: "Main",
  account_type: "cryptoExchange" as const,
  date: "2024-01-15",
};

describe("transactionSchema", () => {
  it("fails crypto without symbol", () => {
    const r = transactionSchema.safeParse({ ...baseValid, symbol: "" });
    expect(r.success).toBe(false);
    if (!r.success) {
      expect(r.error.flatten().fieldErrors.symbol?.length).toBeGreaterThan(0);
    }
  });

  it("fails stocks without symbol", () => {
    const r = transactionSchema.safeParse({
      ...baseValid,
      category: "stocks",
      symbol: "  ",
    });
    expect(r.success).toBe(false);
  });

  it("passes cash without symbol", () => {
    const r = transactionSchema.safeParse({
      ...baseValid,
      category: "cash",
      symbol: undefined,
      price_per_unit: 1,
    });
    expect(r.success).toBe(true);
  });

  it("passes real estate without symbol", () => {
    const r = transactionSchema.safeParse({
      ...baseValid,
      category: "realEstate",
      symbol: undefined,
      price_per_unit: 1,
    });
    expect(r.success).toBe(true);
  });

  it('fails empty asset_name with "Required"', () => {
    const r = transactionSchema.safeParse({ ...baseValid, asset_name: "" });
    expect(r.success).toBe(false);
    if (!r.success) {
      expect(r.error.flatten().fieldErrors.asset_name).toContain("Required");
    }
  });

  it("fails negative quantity", () => {
    const r = transactionSchema.safeParse({ ...baseValid, quantity: -1 });
    expect(r.success).toBe(false);
  });
});

describe("needsSymbol", () => {
  it("returns true for crypto", () => {
    expect(needsSymbol("crypto")).toBe(true);
  });

  it("returns false for cash", () => {
    expect(needsSymbol("cash")).toBe(false);
  });
});

describe("isCashLike", () => {
  it("returns true for realEstate", () => {
    expect(isCashLike("realEstate")).toBe(true);
  });

  it("returns false for stocks", () => {
    expect(isCashLike("stocks")).toBe(false);
  });
});

describe("toFormDefaults", () => {
  it("returns defaults for null with crypto and price_per_unit 1", () => {
    const d = toFormDefaults(null);
    expect(d.category).toBe("crypto");
    expect(d.quantity).toBe(1);
    expect(d.price_per_unit).toBe(1);
    expect(d.transaction_type).toBe("buy");
    expect(d.asset_name).toBe("");
    expect(d.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it("maps existing transaction fields and slices date to YYYY-MM-DD", () => {
    const tx: EnrichedTransaction = {
      id: "t1",
      user_id: "u1",
      asset_id: "a1",
      account_id: "ac1",
      transaction_type: "sell",
      quantity: 2,
      price_per_unit: 10,
      total_value: 20,
      date: "2024-05-20T00:00:00Z",
      asset: {
        id: "a1",
        name: "Thing",
        symbol: "THG",
        category: "stocks",
      },
      account: {
        id: "ac1",
        name: "Broker",
        account_type: "brokerage",
      },
    };
    const d = toFormDefaults(tx);
    expect(d.transaction_type).toBe("sell");
    expect(d.category).toBe("stocks");
    expect(d.asset_name).toBe("Thing");
    expect(d.symbol).toBe("THG");
    expect(d.quantity).toBe(2);
    expect(d.price_per_unit).toBe(10);
    expect(d.account_name).toBe("Broker");
    expect(d.account_type).toBe("brokerage");
    expect(d.date).toBe("2024-05-20");
  });
});
