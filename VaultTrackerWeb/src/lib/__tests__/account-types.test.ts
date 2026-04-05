import { describe, expect, it } from "vitest";
import { ACCOUNT_TYPES_BY_CATEGORY, defaultAccountType } from "@/lib/account-types";
import type { Category } from "@/types/api";

describe("ACCOUNT_TYPES_BY_CATEGORY", () => {
  it("has all five category keys", () => {
    expect(Object.keys(ACCOUNT_TYPES_BY_CATEGORY).sort()).toEqual(
      ["cash", "crypto", "realEstate", "retirement", "stocks"].sort()
    );
  });

  it("each category maps to a non-empty array of account types", () => {
    const categories: Category[] = ["crypto", "stocks", "cash", "realEstate", "retirement"];
    for (const c of categories) {
      const list = ACCOUNT_TYPES_BY_CATEGORY[c];
      expect(Array.isArray(list)).toBe(true);
      expect(list.length).toBeGreaterThan(0);
    }
  });
});

describe("defaultAccountType", () => {
  it('returns "cryptoExchange" for crypto', () => {
    expect(defaultAccountType("crypto")).toBe("cryptoExchange");
  });

  it('returns "bank" for cash', () => {
    expect(defaultAccountType("cash")).toBe("bank");
  });
});
