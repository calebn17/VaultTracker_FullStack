---
title: VaultTracker - To Do
tags:
  - vaultTracker
  - todo
date: 2026-03-24
---

# VaultTracker — To Do

## Backend

- [x] Migrate from SQLite to PostgreSQL (Neon)
- [x] Add Firebase JWT verification via Firebase Admin SDK
- [x] Implement smart transaction endpoint (`POST /api/v1/transactions/smart`)
- [x] Add price service (CoinGecko, Alpha Vantage integration)
- [x] Add caching layer for price lookups
- [x] Add proper migration scripts (replace `create_all` on startup)
- [x] Write tests for smart transaction deduplication logic
- [x] Disable `DEBUG_AUTH_ENABLED` before any production deploy

## iOS App

- [x] Refactor to consume Backend 2.0 smart endpoints
- [x] Update `DashboardMapper` for enriched API responses
- [x] Add analytics tab
- [x] Implement price refresh flow
- [x] Add period chart

## Web App (Next.js)

- [ ] Scaffold Next.js project
- [ ] Set up React Query hooks
- [ ] Define TypeScript types matching backend response shapes
- [ ] Implement Google Sign-In with Firebase Auth
- [ ] Build dashboard, transactions, and analytics pages

## Cross-cutting

- [ ] Ensure all three clients enforce Cash & Real Estate encoding (`quantity = dollar_amount`, `price_per_unit = 1.0`)
- [ ] Verify category strings are consistent (`crypto`, `stocks`, `cash`, `realEstate`, `retirement`)
- [ ] Set up shared Firebase Auth project for all three clients
- [ ] Configure production `ALLOWED_ORIGINS` for CORS

## Misc.
- [ ] Learn more about Docker
## Done

<!-- Move completed items here -->
