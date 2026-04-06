import { test, expect } from "@playwright/test";

async function debugLoginToDashboard(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /debug api session/i }).click();
  await expect(page).toHaveURL(/\/dashboard/);
}

async function openProfile(page: import("@playwright/test").Page) {
  await page.locator('header a[href="/profile"]').click();
  await expect(page).toHaveURL(/\/profile/);
}

test.describe("Profile", () => {
  test.describe.configure({ mode: "serial" });

  test("Toggle theme changes the document theme class", async ({ page }) => {
    await debugLoginToDashboard(page);
    await openProfile(page);

    await expect(page.getByRole("heading", { name: "Profile" })).toBeVisible();

    const html = page.locator("html");
    const before = await html.evaluate((el) => el.className);

    await page
      .locator("main")
      .getByRole("button", { name: /toggle theme/i })
      .click();

    await expect.poll(async () => html.evaluate((el) => el.className)).not.toBe(before);
  });

  test("delete all financial data confirms, shows toast, and signs out", async ({ page }) => {
    await page.route("**/api/v1/users/me/data", async (route) => {
      if (route.request().method() === "DELETE") {
        await route.fulfill({ status: 204 });
      } else {
        await route.continue();
      }
    });

    await debugLoginToDashboard(page);
    await openProfile(page);

    await page.getByRole("button", { name: /delete all financial data/i }).click();

    const dialog = page.getByRole("alertdialog");
    await expect(dialog).toBeVisible();
    await dialog.locator("#confirm").fill("DELETE");
    await dialog.getByRole("button", { name: /confirm delete/i }).click();

    await expect(page.getByText("All financial data removed")).toBeVisible({
      timeout: 10_000,
    });
    await expect(page).toHaveURL(/\/login/, { timeout: 10_000 });
  });
});
