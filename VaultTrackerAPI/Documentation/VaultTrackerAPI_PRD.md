
# Product Requirement Document: VaultTracker API

**Author:** Gemini
**Date:** October 12, 2025
**Version:** 1.0

---

## 1. Overview

The VaultTracker API is a backend service designed to support the VaultTracker iOS application. Its primary purpose is to manage user financial data, including assets, transactions, and accounts. The API will serve as the central source of truth for all user data, offloading data storage, aggregation, and price fetching from the client application. This will lead to a more robust, scalable, and consistent user experience.

## 2. Goals

- **Centralize Data:** Provide a single, secure source of truth for user financial data.
- **Offload Client Logic:** Move heavy computations, data aggregation, and third-party API calls from the iOS app to the backend.
- **Improve Performance:** Deliver pre-computed and aggregated data to the client for faster load times.
- **Enhance Scalability:** Build a foundation that can support future features and a growing user base.
- **Ensure Security:** Protect user data through robust authentication and authorization mechanisms.

## 3. User Roles & Personas

| Role                | Description                                                                 |
| ------------------- | --------------------------------------------------------------------------- |
| **Authenticated User** | A registered user of the VaultTracker app. They can access and manage their own financial data. |

---

## 4. Features & Functionality

### 4.1. User Authentication

- Users will authenticate using their existing Firebase credentials.
- The API will be protected, requiring a valid Firebase JWT in the `Authorization` header for all requests.
- A new user record will be created in the database upon first authenticated access.

### 4.2. Account Management

- Users can create, read, update, and delete their financial accounts (e.g., "Coinbase", "Fidelity", "Chase Bank").

### 4.3. Asset Management

- The system will track all user assets (Stocks, Crypto, Real Estate, etc.).
- The backend will be responsible for periodically fetching the latest market prices for `Stock` and `Crypto` assets from a third-party financial data provider.
- Assets will be automatically created or updated based on user transactions.

### 4.4. Transaction Management

- Users can add, view, edit, and delete their financial transactions (buy/sell).
- Adding a transaction will trigger updates to the relevant asset's quantity and value.

### 4.5. Dashboard / Home View Data

- The API will provide a dedicated endpoint to deliver all the necessary data for the app's home screen in a single call. This includes:
    - Total Net Worth
    - Net worth breakdown by asset category (Cash, Stocks, Crypto, etc.)
    - Grouped asset holdings (e.g., all assets within the "Coinbase" account).

### 4.6. Net Worth History

- The system will automatically generate and store daily snapshots of a user's total net worth.
- The API will provide an endpoint to retrieve this historical data for charting purposes.

---

## 5. API Endpoint Definitions

**Base URL:** `/api/v1`

### 5.1. Authentication

- All endpoints require an `Authorization: Bearer <FIREBASE_JWT>` header.

### 5.2. Dashboard

- **`GET /dashboard`**
    - **Description:** Retrieves all aggregated data needed for the main dashboard/home view.
    - **Response (200 OK):**
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
            "cash": [/* ... */],
            "stocks": [/* ... */],
            "crypto": [/* ... */],
            "realEstate": [/* ... */],
            "retirement": [/* ... */]
          }
        }
        ```

### 5.3. Accounts

- **`GET /accounts`**: Get all of the user's accounts.
- **`POST /accounts`**: Create a new account.
- **`GET /accounts/{accountId}`**: Get a specific account.
- **`PUT /accounts/{accountId}`**: Update an account.
- **`DELETE /accounts/{accountId}`**: Delete an account.

### 5.4. Assets

- **`GET /assets`**: Get all of the user's assets. Can be filtered by category (e.g., `?category=stocks`).
- **`GET /assets/{assetId}`**: Get a specific asset.

### 5.5. Transactions

- **`GET /transactions`**: Get all of the user's transactions.
- **`POST /transactions`**: Create a new transaction. This will trigger asset and net worth updates.
- **`GET /transactions/{transactionId}`**: Get a specific transaction.
- **`PUT /transactions/{transactionId}`**: Update a transaction.
- **`DELETE /transactions/{transactionId}`**: Delete a transaction.

### 5.6. Net Worth History

- **`GET /networth/history`**
    - **Description:** Retrieves the user's historical net worth snapshots.
    - **Query Params:** `?period=daily|weekly|monthly`
    - **Response (200 OK):**
        ```json
        {
          "snapshots": [
            { "date": "2025-10-10T10:00:00Z", "value": 380000.00 },
            { "date": "2025-10-11T10:00:00Z", "value": 382500.00 },
            { "date": "2025-10-12T10:00:00Z", "value": 385500.00 }
          ]
        }
        ```

---

## 6. Data Models

```json
// User
{
  "id": "string (UUID)",
  "firebaseId": "string",
  "email": "user@example.com",
  "createdAt": "timestamp"
}

// Account
{
  "id": "string (UUID)",
  "userId": "string (UUID)",
  "name": "Coinbase",
  "accountType": "cryptoExchange | brokerage | bank | etc."
}

// Asset
{
  "id": "string (UUID)",
  "userId": "string (UUID)",
  "name": "Bitcoin",
  "symbol": "BTC",
  "category": "crypto | stocks | cash | realEstate | retirement",
  "quantity": 1.5,
  "currentValue": 75000.00,
  "lastUpdated": "timestamp"
}

// Transaction
{
  "id": "string (UUID)",
  "userId": "string (UUID)",
  "assetId": "string (UUID)",
  "accountId": "string (UUID)",
  "transactionType": "buy | sell",
  "quantity": 1.5,
  "pricePerUnit": 50000.00,
  "date": "timestamp"
}

// NetWorthSnapshot
{
    "id": "string (UUID)",
    "userId": "string (UUID)",
    "date": "timestamp",
    "value": 385500.00
}
```

---

## 7. Non-Functional Requirements

- **Security:** All API endpoints must be authenticated. Sensitive data should be encrypted at rest.
- **Performance:** The `/dashboard` endpoint must respond in under 200ms. Price fetching should be done in the background and not block user requests.
- **Scalability:** The architecture should be able to handle an increase in users and data without significant degradation in performance.

## 8. Future Considerations

- Integration with Plaid for automatic account and transaction syncing.
- Advanced portfolio analysis features.
- Customizable alerts and notifications.
- Web-based dashboard.
