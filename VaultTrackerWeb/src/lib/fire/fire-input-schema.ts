import { z } from "zod";

/**
 * Client-side FIRE profile form / PUT body. Matches API `FIREProfileInput`
 * (ages, income, expenses, optional goal age).
 */
export const fireInputSchema = z
  .object({
    currentAge: z.number().int().min(18).max(100),
    annualIncome: z.number().min(0),
    annualExpenses: z.number().min(0),
    targetRetirementAge: z.number().int().max(100).nullable().optional(),
  })
  .refine(
    (data) => data.targetRetirementAge == null || data.targetRetirementAge > data.currentAge,
    {
      message: "Target age must be greater than current age",
      path: ["targetRetirementAge"],
    }
  );

export type FireProfileInputForm = z.infer<typeof fireInputSchema>;
