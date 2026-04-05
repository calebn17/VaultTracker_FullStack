import { test, expect } from "@playwright/test";

/**
 * Debug auth lives only in React memory. Navigate to Analytics via the sidebar
 * link after landing on /dashboard — do NOT use page.goto("/analytics") which
 * would clear the debug session and redirect to /login.
 */
async function debugLoginAndGoToAnalytics(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
  await page.getByRole("link", { name: "Analytics" }).click();
  await expect(page).toHaveURL(/\/analytics/);
}

test.describe("Analytics", () => {
  test.describe.configure({ mode: "serial" });

  test.beforeEach(async ({ page }) => {
    await debugLoginAndGoToAnalytics(page);
  });

  test("shows portfolio hero and category cards after load", async ({ page }) => {
    await expect(page.getByText("Total portfolio")).toBeVisible();
    await expect(page.getByText("Stocks & ETFs")).toBeVisible();
    await expect(page.getByText("Digital Assets")).toBeVisible();
  });

  test("price lookup shows symbol and price after API response", async ({ page }) => {
    await page.route("**/api/v1/prices/BTC", async (route) => {
      if (route.request().method() !== "GET") {
        await route.continue();
        return;
      }
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          symbol: "BTC",
          price: 95000,
          source: "e2e_stub",
        }),
      });
    });

    const priceCard = page
      .locator("div.rounded-2xl.border")
      .filter({ has: page.getByText("Price lookup") });

    await priceCard.locator("#sym").fill("BTC");
    await priceCard.getByRole("button", { name: /^Look up$/i }).click();

    const resultBlock = priceCard.locator("div.border-t.pt-4");
    await expect(resultBlock.getByText("Loading…")).toBeHidden({
      timeout: 15_000,
    });
    await expect(resultBlock.locator(".font-medium")).toHaveText("BTC", {
      timeout: 5_000,
    });
    await expect(resultBlock.getByText(/95,?000/)).toBeVisible();
    await expect(resultBlock.getByText("e2e_stub")).toBeVisible();
  });
});
