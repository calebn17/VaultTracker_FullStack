# Accounts Page: Grid/List View Toggle

**Date:** 2026-04-19

## Context

The accounts page (`src/app/(authenticated)/accounts/page.tsx`) currently only has a card grid view. We want to add a list/table view with edit/delete actions and a toggle button to switch between grid and list views.

## Approach

Extract the existing grid into its own component, add a new list component using existing shadcn `Table` primitives, and add a toggle to the page header. No new dependencies needed.

## Implementation Steps

### Step 1: Create `AccountGridView` component

**New file:** `src/components/accounts/account-grid.tsx`

- Extract the existing card grid markup from the page into this component
- Props: `accounts: AccountResponse[]`, `txCountByAccount: Map<string, number>`, `onEdit: (a: AccountResponse) => void`, `onDelete: (a: AccountResponse) => void`
- No behavior changes — pure extraction of lines 63–84 from the current page

### Step 2: Create `AccountListView` component

**New file:** `src/components/accounts/account-list.tsx`

- Table using existing `Table`, `TableHeader`, `TableBody`, `TableRow`, `TableHead`, `TableCell` from `src/components/ui/table.tsx`
- Columns: Name, Type, Created, Transactions, Actions (Edit / Delete buttons)
- Same props as `AccountGridView`
- Use `formatDate` from `src/lib/format.ts` for the created date
- Display `account_type` as-is (matching current card behavior)

### Step 3: Update the accounts page

**File:** `src/app/(authenticated)/accounts/page.tsx`

- Add `viewMode` state: `"grid" | "list"` (default `"grid"` to preserve current behavior)
- Add toggle buttons in the header row (next to "Add account") using `LayoutGrid` and `List` icons from `lucide-react`
- Use the same `aria-pressed` + `cn()` toggle pattern from the dashboard's Household/Just me toggle (`src/app/(authenticated)/dashboard/page.tsx` lines 144–170)
- Toggle container: `div` with `flex items-center gap-1 rounded-md border p-0.5`
- Each toggle button: `button` with `rounded p-1.5 transition-colors`, active state uses `bg-card text-primary`, inactive uses `text-muted-foreground hover:text-foreground`
- Render `AccountGridView` or `AccountListView` based on `viewMode`
- Pass shared props (`accounts`, `txCountByAccount`, `onEdit`, `onDelete`) to the active view

### Step 4: Update system design doc

**File:** `Documentation/VaultTracker System Design.md`

- Update the `/accounts` route description to mention grid/list toggle

## Files Summary

| File                                          | Action                                    |
| --------------------------------------------- | ----------------------------------------- |
| `src/components/accounts/account-grid.tsx`    | Create — extracted card grid              |
| `src/components/accounts/account-list.tsx`    | Create — table list view                  |
| `src/app/(authenticated)/accounts/page.tsx`   | Modify — add toggle state + render switch |
| `Documentation/VaultTracker System Design.md` | Modify — update route description         |

## Reuse

- `Table` / `TableHeader` / `TableBody` / `TableRow` / `TableHead` / `TableCell` — `src/components/ui/table.tsx`
- `Button` — `src/components/ui/button.tsx` (edit/delete in table rows)
- `Card`, `CardHeader`, `CardTitle`, `CardDescription`, `CardContent` — `src/components/ui/card.tsx` (grid view)
- `formatDate` — `src/lib/format.ts`
- `cn` — `src/lib/utils`
- `LayoutGrid`, `List` — `lucide-react` (already a project dependency)
- Toggle pattern — `src/app/(authenticated)/dashboard/page.tsx` lines 144–170

## Verification

1. `npm run build` — no type errors
2. `npm run lint` — no lint errors
3. `npx prettier --check src/components/accounts/ src/app/\(authenticated\)/accounts/`
4. Manual: dev server → `/accounts` → grid view is default, toggle switches views, edit/delete work in both views
