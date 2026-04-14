# Playwright Strict Mode Data Collision

## Problem
Playwright's strict mode requires a locator to match exactly one node. When the debug user's test data accumulated multiple rows with the same asset (e.g., multiple "Bitcoin" entries from earlier test runs), `getByRole("cell", { name: "Bitcoin" })` matched three cells instead of one, causing the test to fail.

## Root Cause
- Test data wasn't isolated per run
- Multiple rows shared the same asset name across different test executions
- Playwright's strict mode caught this ambiguity

## Solution
Implemented in `e2e/transactions.spec.ts`:

1. **Unique identifiers per run**: Generate unique asset names and symbols using a timestamp suffix
   ```
   Asset: Bitcoin E2E ${Date.now()}
   Symbol: TB${suffix}
   ```

2. **Assert on the entire row**: Instead of querying a single cell, filter for the row containing that asset name
   ```javascript
   expect(page.getByRole("row").filter({ hasText: assetName })).toBeVisible()
   ```

## Why It Works
- Each test run targets a brand new row that doesn't collide with historical data
- Row-level assertion is more resilient than cell-level assertion
- Avoids strict mode ambiguity by ensuring only one match exists

## Key Takeaway
When E2E tests interact with shared test data, use **timestamp-based uniqueness** and **assert on parent containers** (rows, sections) rather than individual cells with generic labels.
