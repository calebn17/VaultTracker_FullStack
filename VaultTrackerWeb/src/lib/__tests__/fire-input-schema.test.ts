import { describe, expect, it } from "vitest";
import { fireInputSchema } from "@/lib/fire/fire-input-schema";

const baseValid = {
  currentAge: 32,
  annualIncome: 145_000,
  annualExpenses: 62_000,
  targetRetirementAge: 45 as number | null,
};

describe("fireInputSchema", () => {
  it("accepts a full valid payload", () => {
    const r = fireInputSchema.safeParse(baseValid);
    expect(r.success).toBe(true);
  });

  it("accepts omitted targetRetirementAge", () => {
    const r = fireInputSchema.safeParse({
      currentAge: baseValid.currentAge,
      annualIncome: baseValid.annualIncome,
      annualExpenses: baseValid.annualExpenses,
    });
    expect(r.success).toBe(true);
  });

  it("accepts null targetRetirementAge", () => {
    const r = fireInputSchema.safeParse({
      ...baseValid,
      targetRetirementAge: null,
    });
    expect(r.success).toBe(true);
  });

  it("rejects currentAge below 18", () => {
    const r = fireInputSchema.safeParse({ ...baseValid, currentAge: 17 });
    expect(r.success).toBe(false);
  });

  it("rejects currentAge above 100", () => {
    const r = fireInputSchema.safeParse({ ...baseValid, currentAge: 101 });
    expect(r.success).toBe(false);
  });

  it("rejects negative annualIncome", () => {
    const r = fireInputSchema.safeParse({ ...baseValid, annualIncome: -1 });
    expect(r.success).toBe(false);
  });

  it("rejects negative annualExpenses", () => {
    const r = fireInputSchema.safeParse({ ...baseValid, annualExpenses: -0.01 });
    expect(r.success).toBe(false);
  });

  it("rejects targetRetirementAge not greater than currentAge", () => {
    const r = fireInputSchema.safeParse({
      ...baseValid,
      currentAge: 50,
      targetRetirementAge: 50,
    });
    expect(r.success).toBe(false);
    if (!r.success) {
      expect(r.error.flatten().fieldErrors.targetRetirementAge?.length).toBeGreaterThan(0);
    }
  });

  it("rejects targetRetirementAge above 100", () => {
    const r = fireInputSchema.safeParse({
      ...baseValid,
      currentAge: 99,
      targetRetirementAge: 101,
    });
    expect(r.success).toBe(false);
  });
});
