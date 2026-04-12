import { test, expect } from "@playwright/test";

/**
 * Debug auth lives only in React memory. Navigate from /dashboard via header links
 * so the session survives (same pattern as dashboard.spec.ts).
 */
async function debugLoginToDashboard(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
}

const profileFixture = {
  id: "e2e-fire-profile",
  currentAge: 35,
  annualIncome: 120_000,
  annualExpenses: 55_000,
  targetRetirementAge: 55,
  createdAt: "2026-01-01T00:00:00.000Z",
  updatedAt: "2026-01-01T00:00:00.000Z",
};

const projectionReachable = {
  status: "reachable" as const,
  unreachableReason: null,
  inputs: {
    currentAge: 35,
    annualIncome: 120_000,
    annualExpenses: 55_000,
    currentNetWorth: 250_000,
    targetRetirementAge: 55,
  },
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
    status: "on_track" as const,
    gapAmount: 25_000,
    computedBeyondProjectionHorizon: false,
  },
};

const projectionUnreachable = {
  status: "unreachable" as const,
  unreachableReason: "non_positive_savings" as const,
  inputs: {
    currentAge: 40,
    annualIncome: 50_000,
    annualExpenses: 55_000,
    currentNetWorth: 100_000,
    targetRetirementAge: null,
  },
  allocation: {
    crypto: { value: 0, percentage: 0, expectedReturn: 0.1 },
    stocks: { value: 100_000, percentage: 100, expectedReturn: 0.08 },
    cash: { value: 0, percentage: 0, expectedReturn: 0.02 },
    realEstate: { value: 0, percentage: 0, expectedReturn: 0.05 },
    retirement: { value: 0, percentage: 0, expectedReturn: 0.07 },
  },
  blendedReturn: 0.08,
  realBlendedReturn: 0.05,
  inflationRate: 0.03,
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

const projectionBeyondHorizon = {
  status: "beyond_horizon" as const,
  unreachableReason: null,
  inputs: {
    currentAge: 35,
    annualIncome: 120_000,
    annualExpenses: 55_000,
    currentNetWorth: 10_000,
    targetRetirementAge: 55,
  },
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
  goalAssessment: null,
};

function stubFireApi(
  page: import("@playwright/test").Page,
  projection:
    | typeof projectionReachable
    | typeof projectionUnreachable
    | typeof projectionBeyondHorizon
) {
  return page.route("**/api/v1/fire/**", async (route) => {
    const url = route.request().url();
    const method = route.request().method();

    if (url.includes("/fire/profile")) {
      if (method === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(profileFixture),
        });
        return;
      }
      if (method === "PUT") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify(profileFixture),
        });
        return;
      }
    }

    if (url.includes("/fire/projection") && method === "GET") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(projection),
      });
      return;
    }

    await route.continue();
  });
}

test.describe("FIRE calculator", () => {
  test("FIRE Calc nav opens /fire with inputs region", async ({ page }) => {
    await page.route("**/api/v1/fire/profile", async (route) => {
      if (route.request().method() === "GET") {
        await route.fulfill({
          status: 404,
          contentType: "application/json",
          body: JSON.stringify({ detail: "FIRE profile not found" }),
        });
        return;
      }
      await route.continue();
    });

    await debugLoginToDashboard(page);

    await page.getByRole("link", { name: "FIRE Calc" }).click();
    await expect(page).toHaveURL(/\/fire$/);

    await expect(page.getByRole("region", { name: /FIRE calculator/i })).toBeVisible();
    await expect(page.getByRole("heading", { name: /FIRE calculator/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /run simulation/i })).toBeVisible();
  });

  test("reachable projection shows targets table and chart", async ({ page }) => {
    await stubFireApi(page, projectionReachable);
    await debugLoginToDashboard(page);

    await page.getByRole("link", { name: "FIRE Calc" }).click();
    await expect(page).toHaveURL(/\/fire$/);

    await expect(page.getByRole("cell", { name: "Regular FIRE" })).toBeVisible({
      timeout: 15_000,
    });
    await expect(page.getByText(/\$1,375,000/)).toBeVisible();

    await expect(
      page.locator("[data-slot='fire-projection-chart'] .recharts-surface")
    ).toBeVisible();
  });

  test("unreachable projection shows savings warning and hides chart", async ({ page }) => {
    await stubFireApi(page, projectionUnreachable);
    await debugLoginToDashboard(page);

    await page.getByRole("link", { name: "FIRE Calc" }).click();
    await expect(page).toHaveURL(/\/fire$/);

    await expect(
      page.getByText(/At your current savings rate, FIRE is not achievable/i)
    ).toBeVisible({ timeout: 15_000 });

    await expect(page.locator("[data-slot='fire-unreachable-panel']")).toBeVisible();
    await expect(page.locator("[data-slot='fire-projection-chart']")).toHaveCount(0);
  });

  test("beyond_horizon shows horizon copy and chart", async ({ page }) => {
    await stubFireApi(page, projectionBeyondHorizon);
    await debugLoginToDashboard(page);

    await page.getByRole("link", { name: "FIRE Calc" }).click();
    await expect(page).toHaveURL(/\/fire$/);

    await expect(page.getByText(/30-year projection window/i)).toBeVisible({
      timeout: 15_000,
    });
    await expect(
      page.locator("[data-slot='fire-projection-chart'] .recharts-surface")
    ).toBeVisible();
  });
});
