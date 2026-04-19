---

name: household multi account support
overview: Add a Household entity that two users can share, with a household-aware dashboard (collapsible per-member sections) and a single shared FIRE profile, while Accounts/Assets/Transactions remain strictly personal. API + Web in v1; iOS follows after.
todos:

- id: api-household-model
content: "API: add Household, HouseholdMembership models + get_current_household dependency + create/get-mine endpoints + tests"
status: completed
- id: api-invite-join
content: "API: add HouseholdInviteCode model + generate/join endpoints with cap-of-2 enforcement and TTL/single-use + tests"
status: completed
- id: api-leave
content: "API: add leave-household endpoint with cascade cleanup when last member leaves + tests"
status: completed
- id: api-dashboard-household
content: "API: add GET /dashboard/household (reuses per-user aggregator for each member) + household cache key + invalidation hooks from member writes + tests"
status: completed
- id: api-household-networth
content: "API: add HouseholdNetWorthSnapshot model + upsert hook in record_networth_snapshot + GET /networth/history/household endpoint + tests"
status: completed
- id: api-household-fire
content: "API: add HouseholdFIREProfile model + GET/PUT /households/me/fire-profile endpoints + tests"
status: completed
- id: web-household-hooks-types
content: "Web: add Household/HouseholdDashboard/HouseholdFIRE types and useHousehold + create/join/leave/invite-code mutations with query invalidation"
status: pending
- id: web-household-settings-ui
content: "Web: add household management UI in Settings/Profile (create, generate code, join via code, leave) + tests"
status: pending
- id: web-household-dashboard
content: "Web: implement household dashboard view (hero, household allocation, per-member collapsible MemberSection) with Household/Just me toggle defaulting to household + tests"
status: pending
- id: web-household-networth-chart
content: "Web: wire net worth history chart to useNetWorthHistoryHousehold when in household mode"
status: pending
- id: web-household-fire-page
content: "Web: switch FIRE page to household profile when in a household; keep personal FIRE page otherwise + tests"
status: pending
- id: docs-system-design
content: Update Documentation/VaultTracker System Design.md (new entities, endpoints, data flow) and refresh VaultTrackerAPI/CLAUDE.md and VaultTrackerWeb/CLAUDE.md with household commands/notes
status: completed
isProject: false

---

## Decisions locked in

- **Sharing primitive:** `Household` entity with membership rows (schema supports N, v1 caps at 2).
- **Write access:** View-only across members (each user still only creates/edits their own Accounts/Assets/Transactions).
- **Onboarding:** Short-lived, single-use share codes. No email invite infra in v1.
- **Dashboard default:** Household view, with a "Just me" toggle.
- **Shared pages:** Dashboard + FIRE. Transactions and Accounts stay personal.
- **FIRE semantics:** Single shared `HouseholdFIREProfile`. Per-user `FIREProfile` is preserved but hidden while in a household.
- **Membership:** Exactly one household per user; leaving is supported; household dissolves when last member leaves.
- **Net-worth history:** New `household_networth_snapshots` table, written alongside per-user snapshots.
- **Migrations:** Continue current `Base.metadata.create_all` pattern (no Alembic). New tables only; no destructive changes.

## Data model changes (API)

New tables under `[VaultTrackerAPI/app/models/](VaultTrackerAPI/app/models/)`:

- `Household` — `id` (UUID), `created_at`.
- `HouseholdMembership` — `id`, `household_id` (FK), `user_id` (FK, **unique** — enforces one household per user), `joined_at`. Composite unique `(household_id, user_id)`.
- `HouseholdInviteCode` — `id`, `household_id`, `code` (unique, short e.g. 8 chars), `created_by_user_id`, `expires_at`, `used_at` nullable, `used_by_user_id` nullable. Single-use.
- `HouseholdNetWorthSnapshot` — `id`, `household_id`, `date`, `value`. Upsert on `(household_id, date)`.
- `HouseholdFIREProfile` — 1:1 with `Household`, mirrors fields in `[VaultTrackerAPI/app/models/fire_profile.py](VaultTrackerAPI/app/models/fire_profile.py)`.

`User` gets a relationship to `HouseholdMembership`. No change to existing `Account`/`Asset`/`Transaction` schemas — they keep `user_id` and stay personal.

## API changes

Helpers in `[VaultTrackerAPI/app/dependencies.py](VaultTrackerAPI/app/dependencies.py)`:

- `get_current_household(db, current_user) -> Household | None` — resolves the caller's household via membership.
- `require_current_household(...)` — 409/404 when absent. Used by household endpoints to enforce member-only access.

New router `VaultTrackerAPI/app/routers/households.py`:

- `POST /api/v1/households` — create household, auto-join caller. 409 if already in one.
- `GET /api/v1/households/me` — returns `{ id, members: [{ user_id, email, display_name }], created_at }`.
- `POST /api/v1/households/invite-codes` — generate a short-lived single-use code (member-only). Returns `{ code, expires_at }`.
- `POST /api/v1/households/join` — body `{ code }`. Rejects if caller already in a household, code expired/used, or household is full (cap at 2 in v1).
- `DELETE /api/v1/households/me/membership` — leave; if last member, cascade-delete the household and its dependents (snapshots, FIRE, invite codes).

Dashboard (`[VaultTrackerAPI/app/routers/dashboard.py](VaultTrackerAPI/app/routers/dashboard.py)` + `[VaultTrackerAPI/app/services/dashboard_aggregate.py](VaultTrackerAPI/app/services/dashboard_aggregate.py)`):

- Keep `GET /api/v1/dashboard` unchanged (personal view).
- Add `GET /api/v1/dashboard/household` returning:
  ```
  {
    household_id,
    total_net_worth,           // sum of members
    category_totals,           // merged 5 buckets
    members: [                 // length = household size (1 or 2)
      { user_id, display_name, total, category_totals, grouped_holdings }
    ]
  }
  ```
- Member payload reuses the existing per-user aggregation (`aggregate_dashboard`) run for each member. Wrap with a new `aggregate_household_dashboard(db, household_id)`.
- Cache keys: add `household:{household_id}:dashboard`. Extend `[VaultTrackerAPI/app/services/cache_service.py](VaultTrackerAPI/app/services/cache_service.py)` with `invalidate_household(household_id)`; on any member's writes (asset/transaction/account mutations), also invalidate the member's household cache.

Net-worth history:

- Keep `GET /api/v1/networth/history` (personal).
- Add `GET /api/v1/networth/history/household` — reads from `household_networth_snapshots`.
- In `[VaultTrackerAPI/app/services/asset_sync.py](VaultTrackerAPI/app/services/asset_sync.py)` `record_networth_snapshot`: after writing the per-user snapshot, if the user is in a household, recompute the household total (sum of all members' current portfolio values or sum of members' latest-per-date snapshots) and upsert `HouseholdNetWorthSnapshot` for that date.

FIRE:

- Add `GET/PUT /api/v1/households/me/fire-profile` (member-only) backed by `HouseholdFIREProfile`.
- Personal `/fire-profile` endpoints stay functional; web hides them while in a household. No data migration of existing per-user FIRE rows.

## Web changes

New data hooks in `[VaultTrackerWeb/src/lib/queries/](VaultTrackerWeb/src/lib/queries/)` (mirroring `[use-dashboard.ts](VaultTrackerWeb/src/lib/queries/use-dashboard.ts)`):

- `useHousehold()` — `GET /households/me`; drives "am I in a household?" everywhere.
- `useDashboardHousehold()`, `useNetWorthHistoryHousehold()`, `useHouseholdFireProfile()`.
- Mutations: `useCreateHousehold`, `useGenerateInviteCode`, `useJoinHousehold`, `useLeaveHousehold`, `useUpdateHouseholdFire`. Each invalidates `["household"]`, `["dashboard"]`, `["networth-history"]`, `["fire"]` as appropriate.

New types in `[VaultTrackerWeb/src/types/api.ts](VaultTrackerWeb/src/types/api.ts)` for `Household`, `HouseholdDashboardResponse`, `HouseholdFireProfile`, `HouseholdInviteCode`.

Dashboard page `[VaultTrackerWeb/src/app/(authenticated)/dashboard/page.tsx](VaultTrackerWeb/src/app/(authenticated)`/dashboard/page.tsx):

- If `useHousehold()` returns a household → default to household view; add a `Household | Just me` segmented toggle in the header.
- Household view layout:
  1. Hero stat card with household `total_net_worth` and % change (reuse `[stat-card.tsx](VaultTrackerWeb/src/components/dashboard/stat-card.tsx)`).
  2. Household-level allocation using `[category-summary-list.tsx](VaultTrackerWeb/src/components/dashboard/category-summary-list.tsx)`.
  3. New component `VaultTrackerWeb/src/components/dashboard/member-section.tsx`: a collapsible card per member (reuse the chevron/open-state pattern from `[holdings-grid.tsx](VaultTrackerWeb/src/components/dashboard/holdings-grid.tsx)`). When expanded, render the member's `category_totals` summary + their `HoldingsGrid` (category-grouped, still collapsible inside).
- Net-worth chart uses `useNetWorthHistoryHousehold()` when in household mode.

Household management UI in the existing Settings/Profile area:

- Not in household: "Create household" button and "Join with code" input.
- In household: member list, "Generate invite code" (shows code + copy + expiry), "Leave household" (confirm).

FIRE page:

- In household: edit the single `HouseholdFIREProfile`. UI banner explains any member can edit.
- Not in household: unchanged personal FIRE profile.

## Caching, scaling, and security notes

- All household endpoints check membership via `require_current_household`; read/write stays scoped either to `current_user.id` (personal resources) or to the caller's household (shared resources). No cross-household access is possible.
- Dashboard aggregation for a household runs the existing per-user aggregator `N` times (N ≤ 2 in v1). With per-user caches and a household cache layered on top, reads stay O(1) for cache hits; cold reads are O(members × assets_per_member) — in line with the current dashboard.
- Invite codes are short, single-use, with an `expires_at` (e.g. 15 minutes) and are deleted on consumption. Codes never leave the authenticated session.

## Testing

- API (`pytest` under `[VaultTrackerAPI/tests/](VaultTrackerAPI/tests/)`):
  - Household create/join/leave, cap-of-2 enforcement, invite code expiry and single-use.
  - `GET /dashboard/household` payload shape, membership enforcement, non-member gets 403/404.
  - `record_networth_snapshot` triggers `HouseholdNetWorthSnapshot` upsert.
  - `HouseholdFIREProfile` CRUD by either member.
  - Cache invalidation: a member's write invalidates the household dashboard cache.
- Web (`vitest` under `[VaultTrackerWeb/src/](VaultTrackerWeb/src/)`):
  - `useHousehold`, `useDashboardHousehold` hooks (fetch + error states).
  - Household dashboard rendering: hero total, per-member collapsible sections, toggle switches to personal view.
  - Household settings flows: create, generate code, join (happy path + invalid code), leave.
  - FIRE page renders household profile when in household; personal profile when not.

## Out of scope (documented as follow-ups)

- iOS client support (fast-follow; plan keeps API contract stable for iOS consumption).
- Write access by a partner to the other's Accounts/Assets/Transactions.
- Email-based invitations.
- Households with more than 2 members (schema-ready; lift the cap when ready).
- Historical backfill of `HouseholdNetWorthSnapshot` from existing per-user snapshots.

