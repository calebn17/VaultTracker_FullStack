# PRD: API Implementation - iOS Client Integration

**Author:** Claude
**Date:** January 11, 2026
**Version:** 1.0

---

## 1. Overview

This document outlines the implementation plan for integrating the VaultTracker iOS application with the VaultTrackerAPI backend. This corresponds to **Phase 3: Backend Integration** from the PROJECT_ROADMAP.md.

The goal is to refactor the existing data layer, replacing the local SwiftData implementation with network calls to the FastAPI backend while maintaining the application's existing functionality and user experience.

---

## 2. Goals

- **Replace Local Storage:** Migrate from SwiftData persistence to API-based data management
- **Maintain Functionality:** Ensure all existing features continue to work as expected
- **Leverage Test Suite:** Use the HomeViewModel tests from Phase 1 to verify functionality during refactoring
- **Enable Multi-Device Sync:** Allow users to access their data from multiple devices
- **Improve Scalability:** Offload data aggregation and price fetching to the backend

---

## 3. Current Architecture

### 3.1 Data Models (SwiftData)

| Model | Properties |
|-------|------------|
| **Asset** | id, name, category, symbol, quantity, price, currentValue, notes, lastUpdated |
| **Account** | id, name, accountType, creationDate |
| **Transaction** | id, transactionType, quantity, pricePerUnit, date, name, symbol, category, account |
| **NetWorthSnapshot** | date, value |

### 3.2 Current Data Flow

```
HomeView (@Query transactions)
    ↓
HomeViewModel (state aggregation, coordinates operations)
    ↓
DataService (SwiftData ModelContext, CRUD, price fetching)
    ↓
AssetManager → NetworkService (Alpha Vantage API for prices)
```

### 3.3 Key Components

- **DataService:** Central orchestrator for all database operations
- **HomeViewModel:** Manages home screen state, asset aggregation, transaction processing
- **NetworkService:** Generic HTTP client (already exists)
- **AssetManager:** Handles price fetching from Alpha Vantage

---

## 4. Target Architecture

### 4.1 API Endpoints to Consume

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/dashboard` | GET | Aggregated home screen data |
| `/api/v1/accounts` | GET/POST | List/create accounts |
| `/api/v1/accounts/{id}` | GET/PUT/DELETE | Account CRUD |
| `/api/v1/assets` | GET/POST | List/create assets |
| `/api/v1/assets/{id}` | GET | Get specific asset |
| `/api/v1/transactions` | GET/POST | List/create transactions |
| `/api/v1/transactions/{id}` | GET/PUT/DELETE | Transaction CRUD |
| `/api/v1/networth/history` | GET | Historical net worth snapshots |

### 4.2 New Data Flow

```
HomeView
    ↓
HomeViewModel (simplified - consumes pre-aggregated data)
    ↓
APIService (new - handles all API calls)
    ↓
NetworkService (existing - enhanced with auth headers)
    ↓
VaultTrackerAPI Backend
```

### 4.3 Authentication Flow

1. User authenticates via Firebase (existing)
2. Firebase JWT token is obtained
3. Token is included in `Authorization: Bearer <token>` header for all API calls
4. Backend validates token and identifies user

---

## 5. Implementation Phases

### Phase 1: API Client Layer

Create the networking infrastructure to communicate with the VaultTrackerAPI.

**Components:**
- **APIConfiguration:** Base URL, endpoints, environment configuration
- **APIService:** Protocol-based service for all API calls
- **API Response Models:** Swift structs matching API JSON responses
- **Auth Token Provider:** Integration with AuthManager for JWT tokens
- **Error Handling:** API-specific error types and handling

### Phase 2: Response Model Mapping

Create Swift models that match the API response format and mappers to convert between API models and existing app models.

**Components:**
- **DashboardResponse:** Matches `/api/v1/dashboard` response
- **AccountResponse/AccountRequest:** Account CRUD models
- **AssetResponse:** Asset list/detail models
- **TransactionResponse/TransactionRequest:** Transaction CRUD models
- **NetWorthHistoryResponse:** Snapshot history model
- **Model Mappers:** Convert API models to/from existing domain models

### Phase 3: DataService Refactoring

Replace SwiftData operations with API calls while maintaining the same interface.

**Changes:**
- **Transaction Operations:** Replace ModelContext operations with API calls
- **Asset Operations:** Fetch from API instead of local storage
- **Account Operations:** Full CRUD via API
- **Price Fetching:** Remove client-side price fetching (handled by backend)
- **Snapshot Fetching:** Use `/api/v1/networth/history` endpoint

### Phase 4: ViewModel Simplification

Simplify HomeViewModel to consume pre-aggregated data from the dashboard endpoint.

**Changes:**
- **Dashboard Loading:** Single API call replaces multiple local queries
- **State Updates:** Map API response directly to HomeViewState
- **Transaction Submission:** POST to API, refresh dashboard data
- **Remove Local Aggregation:** Backend now handles grouping and calculations

### Phase 5: Offline Support (Future)

Optional phase for handling offline scenarios.

**Considerations:**
- Local caching of dashboard data
- Transaction queue for offline submissions
- Conflict resolution strategy
- SwiftData as local cache (not source of truth)

---

## 6. Technical Requirements

### 6.1 Networking

- All API calls must include Firebase JWT in Authorization header
- Handle 401 Unauthorized by refreshing token or logging out
- Implement proper error handling and user feedback
- Support request retry for transient failures

### 6.2 Threading

- All UI updates must occur on @MainActor
- Network calls should be async/await
- Maintain existing concurrency patterns

### 6.3 Testing

- Existing HomeViewModel tests must pass after refactoring
- APIService should be protocol-based for mock injection
- Add integration tests for API communication

### 6.4 Migration

- No data migration needed (backend starts fresh)
- Consider option to export/import local data to backend
- Clear local SwiftData on successful API connection

---

## 7. API Response Formats

### Dashboard Response
```json
{
  "totalNetWorth": 385500.00,
  "categoryTotals": {
    "crypto": 75000.00,
    "stocks": 5000.00,
    "cash": 10000.00,
    "realEstate": 300000.00,
    "retirement": 5500.00
  },
  "groupedHoldings": {
    "crypto": [
      {
        "id": "uuid",
        "name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 1.5,
        "current_value": 75000.00
      }
    ],
    "stocks": [],
    "cash": [],
    "realEstate": [],
    "retirement": []
  }
}
```

### Account Response
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "Coinbase",
  "account_type": "cryptoExchange",
  "created_at": "2025-01-11T10:00:00Z"
}
```

### Transaction Request
```json
{
  "asset_id": "uuid",
  "account_id": "uuid",
  "transaction_type": "buy",
  "quantity": 1.5,
  "price_per_unit": 50000.00,
  "date": "2025-01-11T10:00:00Z"
}
```

---

## 8. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| API unavailability | High | Implement graceful error handling, show cached data |
| Token expiration | Medium | Implement token refresh, auto-logout on persistent failure |
| Data inconsistency | Medium | Use server as source of truth, refresh after mutations |
| Network latency | Low | Show loading states, optimistic UI updates |
| Breaking API changes | Medium | Version API endpoints, handle unknown fields gracefully |

---

## 9. Success Criteria

- [ ] All existing HomeViewModel tests pass
- [ ] Users can view dashboard with real-time data from API
- [ ] Users can create/edit/delete transactions via API
- [ ] Users can manage accounts via API
- [ ] Net worth history chart displays data from API
- [ ] Authentication integrates seamlessly with existing Firebase flow
- [ ] Error states are handled gracefully with user feedback

---

## 10. Out of Scope

- Offline-first architecture (deferred to future phase)
- Push notifications for price alerts
- Background sync
- Data export/import from local SwiftData
- Plaid integration
