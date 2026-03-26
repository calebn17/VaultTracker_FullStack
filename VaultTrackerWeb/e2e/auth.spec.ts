import { test, expect } from "@playwright/test";

test.describe("Login", () => {
  test("shows Google sign-in or Firebase setup notice", async ({ page }) => {
    await page.goto("/login");
    const google = page.getByRole("button", { name: /continue with google/i });
    const notice = page.getByText(/add firebase keys/i);
    await expect(google.or(notice).first()).toBeVisible();
  });

  test("shows debug sign-in in development", async ({ page }) => {
    await page.goto("/login");
    await expect(
      page.getByRole("button", { name: /debug api session/i })
    ).toBeVisible();
  });
});

test.describe("Auth guard", () => {
  test("unauthenticated visit to /dashboard redirects to /login", async ({
    page,
  }) => {
    await page.goto("/dashboard");
    await expect(page).toHaveURL(/\/login/);
  });
});

test.describe("Debug sign-in", () => {
  test("lands on /dashboard after debug sign-in", async ({ page }) => {
    await page.goto("/login");
    await page.getByRole("button", { name: /debug api session/i }).click();
    await expect(page).toHaveURL(/\/dashboard/);
  });
});
