import { test, expect } from "@playwright/test";

/**
 * Debug auth lives only in React memory. Use client navigation from /dashboard
 * (header or bottom nav link) so the session survives; a full reload to /transactions would
 * clear it and bounce to /login.
 */
async function debugLoginAndGoToTransactions(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
  await page.getByRole("link", { name: "Transactions" }).click();
  await expect(page).toHaveURL(/\/transactions/);
}

test.describe("Transactions", () => {
  test.describe.configure({ mode: "serial" });

  test.beforeEach(async ({ page }) => {
    await debugLoginAndGoToTransactions(page);
  });

  test("loads with heading and table", async ({ page }) => {
    await expect(
      page.getByRole("heading", { name: "Transactions" })
    ).toBeVisible();
    await expect(page.getByRole("table")).toBeVisible();
  });

  test('"Add transaction" opens dialog with key fields', async ({ page }) => {
    await page.getByRole("button", { name: /add transaction/i }).click();
    const dialog = page.getByRole("dialog", { name: /add transaction/i });
    await expect(dialog).toBeVisible();
    await expect(dialog.locator('input[name="asset_name"]')).toBeVisible();
    await expect(dialog.locator('input[name="account_name"]')).toBeVisible();
  });

  test("create valid buy shows toast and new row", async ({ page }) => {
    const suffix = Date.now();
    const assetName = `Bitcoin E2E ${suffix}`;
    const symbol = `TB${suffix}`;
    await page.getByRole("button", { name: /add transaction/i }).click();
    const dialog = page.getByRole("dialog");

    await dialog.locator('input[name="asset_name"]').fill(assetName);
    await dialog.locator('input[name="symbol"]').fill(symbol);
    await dialog.locator('input[name="quantity"]').fill("0.1");
    await dialog.locator('input[name="price_per_unit"]').fill("50000");
    await dialog.locator('input[name="account_name"]').fill("E2E Broker");

    await dialog.getByRole("button", { name: /^Save$/i }).click();

    await expect(page.getByText(/transaction added/i)).toBeVisible({
      timeout: 20_000,
    });
    await expect(
      page.getByRole("row").filter({ hasText: assetName })
    ).toBeVisible({
      timeout: 20_000,
    });
  });

  test("delete shows confirmation and removes row", async ({ page }) => {
    const suffix = Date.now();
    const assetName = `Ethereum E2E ${suffix}`;
    const symbol = `ETH${suffix}`;
    await page.getByRole("button", { name: /add transaction/i }).click();
    const dialog = page.getByRole("dialog");

    await dialog.locator('input[name="asset_name"]').fill(assetName);
    await dialog.locator('input[name="symbol"]').fill(symbol);
    await dialog.locator('input[name="quantity"]').fill("0.2");
    await dialog.locator('input[name="price_per_unit"]').fill("3000");
    await dialog.locator('input[name="account_name"]').fill("E2E Del");

    await dialog.getByRole("button", { name: /^Save$/i }).click();
    await expect(page.getByText(/transaction added/i)).toBeVisible({
      timeout: 20_000,
    });

    const row = page.getByRole("row").filter({ hasText: assetName });
    await row.getByRole("button", { name: "Delete" }).click();

    await expect(
      page.getByRole("alertdialog", { name: /delete transaction/i })
    ).toBeVisible();

    await page
      .getByRole("alertdialog")
      .getByRole("button", { name: /^Delete$/ })
      .click();

    await expect(page.getByText(/deleted/i)).toBeVisible({ timeout: 20_000 });
    await expect(
      page.getByRole("cell", { name: assetName })
    ).not.toBeVisible({ timeout: 10_000 });
  });
});
