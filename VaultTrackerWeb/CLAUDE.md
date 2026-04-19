# CLAUDE.md — VaultTrackerWeb

Next.js 15 App Router web client for VaultTracker.

> **Architecture, auth flow, state management, key files, API contract, testing notes, security headers, Sentry:** [`Documentation/system_design.md`](Documentation/system_design.md)

## Status

All seven implementation phases are **complete**. Not yet deployed to Vercel — see `Documentation/Web App Spec.md` Phase 7 (items 7.3–7.9) for open checklist.

## Commands

```bash
npm run dev           # Dev server at localhost:3000
npm run build         # Production build
npm run lint          # ESLint
npx prettier --check .  # Format check (same as CI lint-web)
npx prettier --write .  # Apply Prettier project-wide
npm run test          # Vitest (unit + component), single run
npm run test:watch    # Vitest watch mode
npm run test:coverage # Vitest with coverage
npm run test:e2e      # Playwright (starts dev server automatically)
```

## Tech Stack

- **Next.js 15** — App Router
- **TypeScript 5**
- **Tailwind CSS** — `darkMode: "class"`
- **shadcn/ui** — `src/components/ui/`
- **TanStack React Query v5** — server state
- **TanStack Table v8** — transactions table
- **React Hook Form + Zod** — form validation
- **Recharts v2** — charts
- **Firebase Auth Web SDK v10** — Google Sign-In
- **@sentry/nextjs** — production error monitoring
- **date-fns** — date formatting

## Route Structure

| Route           | Purpose                                                                          |
| --------------- | -------------------------------------------------------------------------------- |
| `/dashboard`    | Net worth chart, category bar, holdings grid, price refresh                      |
| `/analytics`    | Bento grid: portfolio hero, category cards, net worth chart, performance summary |
| `/fire`         | FIRE calculator                                                                  |
| `/transactions` | Sortable table, add/edit/delete, CSV export                                      |
| `/accounts`     | Account CRUD                                                                     |
| `/profile`      | User info, sign out, theme toggle, delete all data                               |

Unauthenticated: `/login` and `/` (redirects based on auth state).

## Environment Setup

Copy `.env.local.example` → `.env.local`:

```
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
NEXT_PUBLIC_FIREBASE_APP_ID=...
NEXT_PUBLIC_SENTRY_DSN=   # optional
```

`NEXT_PUBLIC_API_HOST` also accepted as fallback for API base URL.

When deploying to Vercel: set env vars in Vercel dashboard and add the Vercel domain to `ALLOWED_ORIGINS` in `VaultTrackerAPI/app/config.py`.

## Testing

**Vitest** (`vitest.config.ts`): runs in `jsdom`; `e2e/` excluded. Tests live in `src/**/__tests__/` and `src/app/(authenticated)/**/__tests__/`.

**Playwright** (`playwright.config.ts`): `testDir: ./e2e`, `baseURL: http://localhost:3000`. Install browsers once: `npx playwright install --with-deps chromium`.
