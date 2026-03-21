# VaultTracker API Technical Specification

**Version:** 1.0.0
**Base URL:** `/api/v1`

---

## Overview

The VaultTracker API is a RESTful backend service built with FastAPI that manages user financial data including accounts, assets, transactions, and net worth tracking. It serves as the central data source for the VaultTracker iOS application.

---

## Authentication

All endpoints require authentication via the `Authorization` header.

**Header Format:**
```
Authorization: Bearer <token>
```

**Current Implementation:** Mock authentication accepting any user identifier as the token. Users are automatically created on first request.

**Production Implementation:** Firebase JWT verification (to be implemented).

**Response Codes:**
- `401 Unauthorized` - Missing or invalid authorization header

---

## Endpoints

### Health & Root

#### `GET /`
Returns API information.

**Response:** `200 OK`
```json
{
  "message": "VaultTracker API",
  "version": "1.0.0"
}
```

#### `GET /health`
Health check endpoint.

**Response:** `200 OK`
```json
{
  "status": "healthy"
}
```

---

### Dashboard

#### `GET /api/v1/dashboard`

Returns aggregated financial data for the home screen.

**Response:** `200 OK`
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

---

### Accounts

Financial accounts represent where assets are held (e.g., Coinbase, Fidelity, Chase Bank).

#### `GET /api/v1/accounts`

Returns all accounts for the authenticated user.

**Response:** `200 OK`
```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "name": "Coinbase",
    "account_type": "cryptoExchange",
    "created_at": "2025-01-11T10:00:00Z"
  }
]
```

#### `POST /api/v1/accounts`

Creates a new account.

**Request Body:**
```json
{
  "name": "Coinbase",
  "account_type": "cryptoExchange"
}
```

**Account Types:** `cryptoExchange`, `brokerage`, `bank`, `retirement`, `other`

**Response:** `201 Created`
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "Coinbase",
  "account_type": "cryptoExchange",
  "created_at": "2025-01-11T10:00:00Z"
}
```

#### `GET /api/v1/accounts/{account_id}`

Returns a specific account.

**Response:** `200 OK` | `404 Not Found`

#### `PUT /api/v1/accounts/{account_id}`

Updates an existing account.

**Request Body:**
```json
{
  "name": "Coinbase Pro",
  "account_type": "cryptoExchange"
}
```

All fields are optional.

**Response:** `200 OK` | `404 Not Found`

#### `DELETE /api/v1/accounts/{account_id}`

Deletes an account and all associated transactions.

**Response:** `204 No Content` | `404 Not Found`

---

### Assets

Assets represent individual holdings (stocks, crypto, cash, real estate, retirement accounts).

#### `GET /api/v1/assets`

Returns all assets for the authenticated user.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `category` | string | Filter by category: `crypto`, `stocks`, `cash`, `realEstate`, `retirement` |

**Example:** `GET /api/v1/assets?category=crypto`

**Response:** `200 OK`
```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "name": "Bitcoin",
    "symbol": "BTC",
    "category": "crypto",
    "quantity": 1.5,
    "current_value": 75000.00,
    "last_updated": "2025-01-11T10:00:00Z"
  }
]
```

#### `POST /api/v1/assets`

Creates a new asset.

**Request Body:**
```json
{
  "name": "Bitcoin",
  "symbol": "BTC",
  "category": "crypto",
  "quantity": 0.0,
  "current_value": 0.0
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Asset name |
| `symbol` | string | No | Ticker symbol (e.g., BTC, AAPL) |
| `category` | string | Yes | One of: `crypto`, `stocks`, `cash`, `realEstate`, `retirement` |
| `quantity` | float | No | Initial quantity (default: 0.0) |
| `current_value` | float | No | Initial value (default: 0.0) |

**Response:** `201 Created`

#### `GET /api/v1/assets/{asset_id}`

Returns a specific asset.

**Response:** `200 OK` | `404 Not Found`

---

### Transactions

Transactions record buy/sell activity and automatically update asset quantities and values.

#### `GET /api/v1/transactions`

Returns all transactions for the authenticated user.

**Response:** `200 OK`
```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "asset_id": "uuid",
    "account_id": "uuid",
    "transaction_type": "buy",
    "quantity": 1.5,
    "price_per_unit": 50000.00,
    "date": "2025-01-11T10:00:00Z"
  }
]
```

#### `POST /api/v1/transactions`

Creates a new transaction. **Automatically updates the associated asset's quantity and value.**

**Request Body:**
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

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `asset_id` | string | Yes | UUID of the asset |
| `account_id` | string | Yes | UUID of the account |
| `transaction_type` | string | Yes | `buy` or `sell` |
| `quantity` | float | Yes | Number of units |
| `price_per_unit` | float | Yes | Price per unit at time of transaction |
| `date` | datetime | No | Transaction date (default: current time) |

**Side Effects:**
- `buy`: Increases asset quantity
- `sell`: Decreases asset quantity
- Asset `current_value` is recalculated as `quantity * price_per_unit`

**Response:** `201 Created` | `404 Not Found` (if asset or account doesn't exist)

#### `GET /api/v1/transactions/{transaction_id}`

Returns a specific transaction.

**Response:** `200 OK` | `404 Not Found`

#### `PUT /api/v1/transactions/{transaction_id}`

Updates an existing transaction. **Reverses the old transaction effect and applies the new values.**

**Request Body:**
```json
{
  "transaction_type": "sell",
  "quantity": 0.5,
  "price_per_unit": 55000.00,
  "date": "2025-01-11T12:00:00Z"
}
```

All fields are optional.

**Response:** `200 OK` | `404 Not Found`

#### `DELETE /api/v1/transactions/{transaction_id}`

Deletes a transaction. **Reverses the transaction's effect on the associated asset.**

**Response:** `204 No Content` | `404 Not Found`

---

### Net Worth History

Historical snapshots of user net worth for charting.

#### `GET /api/v1/networth/history`

Returns historical net worth snapshots.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `period` | string | `daily` | Filter period: `daily`, `weekly`, `monthly` |

**Response:** `200 OK`
```json
{
  "snapshots": [
    {
      "date": "2025-01-11T10:00:00Z",
      "value": 385500.00
    },
    {
      "date": "2025-01-10T10:00:00Z",
      "value": 382500.00
    }
  ]
}
```

**Note:** Snapshots are returned in descending order by date.

---

## Data Models

### User
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `firebase_id` | string | Firebase authentication ID |
| `email` | string | User email (optional) |
| `created_at` | datetime | Account creation timestamp |

### Account
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key to User |
| `name` | string | Account name |
| `account_type` | string | Type of account |
| `created_at` | datetime | Creation timestamp |

### Asset
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key to User |
| `name` | string | Asset name |
| `symbol` | string | Ticker symbol (nullable) |
| `category` | string | Asset category |
| `quantity` | float | Current quantity held |
| `current_value` | float | Current total value |
| `last_updated` | datetime | Last update timestamp |

### Transaction
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key to User |
| `asset_id` | UUID | Foreign key to Asset |
| `account_id` | UUID | Foreign key to Account |
| `transaction_type` | string | `buy` or `sell` |
| `quantity` | float | Transaction quantity |
| `price_per_unit` | float | Price at transaction time |
| `date` | datetime | Transaction date |

### NetWorthSnapshot
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Foreign key to User |
| `date` | datetime | Snapshot date |
| `value` | float | Total net worth |

---

## Error Responses

All errors follow this format:

```json
{
  "detail": "Error message description"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| `200` | Success |
| `201` | Created |
| `204` | No Content (successful deletion) |
| `400` | Bad Request (validation error) |
| `401` | Unauthorized (missing/invalid auth) |
| `404` | Not Found |
| `422` | Unprocessable Entity (validation error) |
| `500` | Internal Server Error |

---

## Running the API

### Prerequisites
- Python 3.10+
- pip

### Installation
```bash
cd VaultTrackerAPI
pip install -r requirements.txt
```

### Development Server
```bash
uvicorn app.main:app --reload
```

### Endpoints
- **API:** http://localhost:8000
- **Interactive Docs (Swagger):** http://localhost:8000/docs
- **Alternative Docs (ReDoc):** http://localhost:8000/redoc

---

## Database

**Current:** SQLite (`vaulttracker.db` in project root)

The database is automatically created on first startup. Tables are created based on SQLAlchemy model definitions.

---

## Future Enhancements

- Firebase JWT verification for production authentication
- Background task scheduler for automatic price fetching
- Plaid integration for account syncing
- PostgreSQL support for production deployment
- Rate limiting and request throttling
- Comprehensive logging and monitoring
