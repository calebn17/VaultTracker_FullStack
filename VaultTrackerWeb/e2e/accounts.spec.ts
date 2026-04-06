import { test, expect } from "@playwright/test";

/**
 * Debug auth lives only in React memory. Navigate to Accounts via the sidebar
 * link after landing on /dashboard — do NOT use page.goto("/accounts") which
 * would clear the debug session and redirect to /login.
 */
async function debugLoginAndGoToAccounts(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
  await page.getByRole("link", { name: "Accounts" }).click();
  await expect(page).toHaveURL(/\/accounts/);
}

test.describe("Accounts", () => {
  test.describe.configure({ mode: "serial" });

  test.beforeEach(async ({ page }) => {
    await debugLoginAndGoToAccounts(page);
  });

  test("loads with Accounts heading and list UI", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "Accounts" })).toBeVisible();
    await expect(page.getByRole("button", { name: /add account/i })).toBeVisible();
    await expect(page.getByText("Loading…")).not.toBeVisible({
      timeout: 15_000,
    });
  });

  function accountCard(page: import("@playwright/test").Page, name: string) {
    return page.locator('[data-slot="card"]').filter({ hasText: name });
  }

  test("create account shows new card in list", async ({ page }) => {
    const suffix = Date.now();
    const accountName = `E2E Test Bank ${suffix}`;

    // Open the Add Account dialog
    await page.getByRole("button", { name: /add account/i }).click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();

    // Fill in the form
    await dialog.locator('input[name="name"]').fill(accountName);

    // Save
    await dialog.getByRole("button", { name: /^Save$/i }).click();

    await expect(accountCard(page, accountName)).toBeVisible({
      timeout: 10_000,
    });
  });

  test("delete account removes its card from the list", async ({ page }) => {
    const suffix = Date.now();
    const accountName = `E2E Delete Test ${suffix}`;

    // Create an account first
    await page.getByRole("button", { name: /add account/i }).click();
    const dialog = page.getByRole("dialog");
    await dialog.locator('input[name="name"]').fill(accountName);
    await dialog.getByRole("button", { name: /^Save$/i }).click();

    const card = accountCard(page, accountName);
    await expect(card).toBeVisible({ timeout: 10_000 });

    await card.getByRole("button", { name: /delete/i }).click();

    // Confirm the deletion in the alert dialog
    const alertDialog = page.getByRole("alertdialog");
    await expect(alertDialog).toBeVisible();
    await alertDialog.getByRole("button", { name: /^Delete$/i }).click();

    await expect(card).not.toBeVisible({ timeout: 10_000 });
  });
});
