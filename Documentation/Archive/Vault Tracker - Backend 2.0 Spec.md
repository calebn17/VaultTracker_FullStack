---
tags:
  - vaultTracker
  - python
  - backend
title: Vault Tracker - Backend 2.0 Spec
---

# VaultTracker Backend 2.0 — Design Spec

> **Purpose:** AI-agent consumable spec for evolving the FastAPI backend from a simple CRUD API into a smart service layer. Read the [Backend Context](VaultTracker/VaultTrackerSecondBrain/Archive/Vault%20Tracker%20-%20Backend%20Context.md) first for current state.

---

## Context

The current backend is a straightforward CRUD API. Business logic like asset resolution, account resolution, and transaction denormalization lives in the iOS client. This creates two problems:

1. **Every new client must reimplement the same logic.** The upcoming web app would need to duplicate iOS resolution code.
2. **The backend can't enforce business rules.** If a client has a bug in resolution logic, the database gets inconsistent data.

Backend 2.0 moves all business logic server-side and adds new capabilities (analytics, pricing, caching) so that clients are pure presentation layers.

---

## Overview

### What Changes

| Area | Current State | Backend 2.0 |
|------|--------------|-------------|
| Database | SQLite (local file) | PostgreSQL (Neon free tier) |
| Auth | Raw token used as firebase_id (no verification) | Firebase Admin SDK verifies JWT |
| CORS | `allow_origins=["*"]` | Env-driven allowed origins list |
| Transaction creation | Client resolves asset + account, then calls 3 endpoints | Single `POST /transactions/smart` does everything |
| Transaction list | Returns IDs only, client joins asset + account | Returns denormalized data with asset + account inline |
| Analytics | None | `GET /analytics` — allocation %, trends, gain/loss |
| Net worth history | `period` param accepted but ignored | Actually aggregates by day/week/month |
| Pricing | Manual entry only | CoinGecko (crypto) + Alpha Vantage (stocks) auto-pricing |
| Caching | None | In-memory TTL cache on read-heavy endpoints |

### What Doesn't Change

- All existing endpoints remain backward-compatible (no breaking changes for iOS)
- Database schema (tables, columns) stays the same
- Auth debug bypass stays for local dev
- Pydantic schemas are extended, not replaced

---

## Architecture

### New Directory Structure

```
VaultTrackerAPI/
├── app/
│   ├── main.py                    # + mount analytics, prices routers
│   ├── config.py                  # + ALLOWED_ORIGINS, FIREBASE_CREDENTIALS_PATH, ALPHA_VANTAGE_API_KEY
│   ├── database.py                # SQLite → PostgreSQL
│   ├── dependencies.py            # Firebase JWT verification
│   ├── models/                    # unchanged
│   │   ├── user.py
│   │   ├── account.py
│   │   ├── asset.py
│   │   ├── transaction.py
│   │   └── networth_snapshot.py
│   ├── schemas/
│   │   ├── account.py             # unchanged
│   │   ├── asset.py               # unchanged
│   │   ├── dashboard.py           # unchanged
│   │   ├── networth.py            # unchanged
│   │   ├── user.py                # unchanged
│   │   ├── transaction.py         # + SmartTransactionCreate, EnrichedTransactionResponse
│   │   ├── analytics.py           # NEW
│   │   └── price.py               # NEW
│   ├── routers/
│   │   ├── accounts.py            # unchanged
│   │   ├── assets.py              # unchanged
│   │   ├── dashboard.py           # + cache integration
│   │   ├── transactions.py        # + smart endpoint, enriched response
│   │   ├── networth.py            # + period aggregation
│   │   ├── users.py               # unchanged
│   │   ├── analytics.py           # NEW
│   │   └── prices.py              # NEW
│   └── services/                  # NEW — all business logic
│       ├── transaction_service.py
│       ├── analytics_service.py
│       ├── price_service.py
│       └── cache_service.py
├── requirements.txt               # + psycopg2-binary, firebase-admin, httpx, cachetools
├── .env
└── start.sh
```

### Service Layer Pattern

Routers handle HTTP concerns (request parsing, status codes, auth). Services handle business logic. This keeps routers thin and services testable.

```
Router (HTTP) → Service (logic) → Model (ORM) → PostgreSQL
                    ↓
              Cache Service (read-through)
                    ↓
              External APIs (CoinGecko, Alpha Vantage)
```

---

## Technical Spec

### Phase 1: Infrastructure

#### 1.1 PostgreSQL Migration

**File:** `app/database.py`

Current:
```python
SQLALCHEMY_DATABASE_URL = "sqlite:///./vaulttracker.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
```

New:
```python
SQLALCHEMY_DATABASE_URL = settings.database_url  # from .env
engine = create_engine(SQLALCHEMY_DATABASE_URL)
# No connect_args needed for PostgreSQL
```

**File:** `requirements.txt` — add `psycopg2-binary`

**File:** `.env` — `DATABASE_URL=postgresql://user:pass@host:5432/vaulttracker`

SQLAlchemy ORM code is database-agnostic — no model changes needed. The `Base.metadata.create_all(bind=engine)` call in `main.py` lifespan creates tables on startup.

#### 1.2 Firebase JWT Verification

**File:** `app/dependencies.py`

```python
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials

# Initialize once at module load
cred = credentials.Certificate(settings.firebase_credentials_path)
firebase_admin.initialize_app(cred)

async def get_current_user(authorization: str = Header(...), db: Session = Depends(get_db)) -> User:
    token = authorization.replace("Bearer ", "")

    # Debug bypass (local dev only)
    if settings.debug_auth_enabled and token == "vaulttracker-debug-user":
        firebase_id = "debug-user"
    else:
        try:
            decoded = firebase_auth.verify_id_token(token)
            firebase_id = decoded["uid"]
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid or expired token")

    # Find or create user (existing logic)
    user = db.query(User).filter(User.firebase_id == firebase_id).first()
    if not user:
        user = User(id=str(uuid.uuid4()), firebase_id=firebase_id)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user
```

**File:** `app/config.py` — add `firebase_credentials_path: str = "./firebase-service-account.json"`

#### 1.3 CORS Tightening

**File:** `app/config.py` — add `allowed_origins: str = "http://localhost:3000"`

**File:** `app/main.py`:
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

### Phase 2: Smart Endpoints

#### 2.1 Transaction Service

**File:** `app/services/transaction_service.py`

Consolidates logic currently in iOS `HomeViewModel.onSave` + `AddAssetFormViewModel.getOrCreateAccount()` + `routers/transactions.py`:

```python
class TransactionService:
    def smart_create(self, data: SmartTransactionCreate, user: User, db: Session) -> Transaction:
        # 1. Resolve account
        account = db.query(Account).filter(
            Account.user_id == user.id,
            Account.name == data.account_name
        ).first()
        if not account:
            account = Account(
                id=str(uuid.uuid4()),
                user_id=user.id,
                name=data.account_name,
                account_type=data.account_type
            )
            db.add(account)
            db.flush()

        # 2. Resolve asset
        if data.category in ("crypto", "stocks", "retirement") and data.symbol:
            asset = db.query(Asset).filter(
                Asset.user_id == user.id,
                Asset.symbol == data.symbol
            ).first()
        else:
            asset = db.query(Asset).filter(
                Asset.user_id == user.id,
                Asset.name == data.asset_name,
                Asset.category == data.category
            ).first()

        if not asset:
            asset = Asset(
                id=str(uuid.uuid4()),
                user_id=user.id,
                name=data.asset_name,
                symbol=data.symbol,
                category=data.category,
                quantity=0.0,
                current_value=0.0
            )
            db.add(asset)
            db.flush()

        # 3. Create transaction
        transaction = Transaction(
            id=str(uuid.uuid4()),
            user_id=user.id,
            asset_id=asset.id,
            account_id=account.id,
            transaction_type=data.transaction_type,
            quantity=data.quantity,
            price_per_unit=data.price_per_unit,
            date=data.date or datetime.utcnow()
        )
        db.add(transaction)

        # 4. Update asset value (reuse existing logic)
        update_asset_from_transaction(asset, transaction)

        # 5. Record snapshot (reuse existing logic)
        record_networth_snapshot(user, db)

        db.commit()
        db.refresh(transaction)
        return transaction
```

#### 2.2 Smart Transaction Schema

**File:** `app/schemas/transaction.py` — add:

```python
class SmartTransactionCreate(BaseModel):
    transaction_type: str          # "buy" or "sell"
    category: str                  # "crypto", "stocks", "cash", "realEstate", "retirement"
    asset_name: str                # "Bitcoin", "AAPL", "Savings Account"
    symbol: str | None = None      # "BTC", "AAPL" — required for crypto/stocks/retirement
    quantity: float
    price_per_unit: float
    account_name: str              # "Coinbase", "Fidelity"
    account_type: str              # "cryptoExchange", "brokerage", "bank"
    date: datetime | None = None
```

#### 2.3 Enriched Transaction Response

**File:** `app/schemas/transaction.py` — add:

```python
class AssetSummary(BaseModel):
    id: str
    name: str
    symbol: str | None
    category: str

class AccountSummary(BaseModel):
    id: str
    name: str
    account_type: str

class EnrichedTransactionResponse(BaseModel):
    id: str
    transaction_type: str
    quantity: float
    price_per_unit: float
    total_value: float              # computed: quantity * price_per_unit
    date: datetime
    asset: AssetSummary
    account: AccountSummary

    class Config:
        from_attributes = True
```

**File:** `app/routers/transactions.py` — update `GET /transactions` to use eager loading and return `EnrichedTransactionResponse`.

**Backward compatibility:** The existing `TransactionResponse` schema stays. The enriched response adds fields; no fields are removed. iOS can ignore the new nested objects until it's updated.

#### 2.4 Analytics Service

**File:** `app/services/analytics_service.py`

```python
class AnalyticsService:
    def get_analytics(self, user: User, db: Session) -> dict:
        assets = db.query(Asset).filter(Asset.user_id == user.id).all()
        total = sum(a.current_value for a in assets)

        # Allocation
        allocation = {}
        for category in ["crypto", "stocks", "cash", "realEstate", "retirement"]:
            cat_assets = [a for a in assets if a.category == category]
            value = sum(a.current_value for a in cat_assets)
            allocation[category] = {
                "value": value,
                "percentage": round((value / total * 100) if total > 0 else 0, 1)
            }

        # Category trends (from snapshots — simplified: overall net worth over time)
        # For per-category trends, would need per-category snapshots (future enhancement)
        snapshots = db.query(NetWorthSnapshot)\
            .filter(NetWorthSnapshot.user_id == user.id)\
            .order_by(NetWorthSnapshot.date).all()

        # Performance (gain/loss from transaction history)
        transactions = db.query(Transaction).filter(Transaction.user_id == user.id).all()
        total_invested = sum(
            t.quantity * t.price_per_unit
            for t in transactions if t.transaction_type == "buy"
        )
        total_sold = sum(
            t.quantity * t.price_per_unit
            for t in transactions if t.transaction_type == "sell"
        )
        cost_basis = total_invested - total_sold
        gain_loss = total - cost_basis

        return {
            "allocation": allocation,
            "performance": {
                "totalGainLoss": round(gain_loss, 2),
                "totalGainLossPercent": round((gain_loss / cost_basis * 100) if cost_basis > 0 else 0, 1),
                "costBasis": round(cost_basis, 2),
                "currentValue": round(total, 2)
            }
        }
```

#### 2.5 Analytics Endpoint

**File:** `app/routers/analytics.py`

```python
router = APIRouter(prefix="/analytics", tags=["analytics"])

@router.get("/", response_model=AnalyticsResponse)
def get_analytics(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AnalyticsService()
    return service.get_analytics(user, db)
```

**File:** `app/main.py` — add `app.include_router(analytics.router, prefix="/api/v1")`

#### 2.6 Net Worth History Period Aggregation

**File:** `app/routers/networth.py`

```python
@router.get("/history")
def get_history(period: str = "daily", user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    snapshots = db.query(NetWorthSnapshot)\
        .filter(NetWorthSnapshot.user_id == user.id)\
        .order_by(NetWorthSnapshot.date).all()

    if period == "daily":
        # Group by date (day), take last snapshot per day
        grouped = {}
        for s in snapshots:
            day = s.date.date()
            grouped[day] = s  # last one wins
        return {"snapshots": [{"date": k.isoformat(), "value": v.value} for k, v in sorted(grouped.items())]}
    elif period == "weekly":
        # Group by ISO week
        ...
    elif period == "monthly":
        # Group by year-month
        ...
    else:
        # Return all (backward compatible)
        return {"snapshots": [{"date": s.date.isoformat(), "value": s.value} for s in snapshots]}
```

---

### Phase 3: Price Service

**File:** `app/services/price_service.py`

```python
import httpx

class PriceService:
    COINGECKO_BASE = "https://api.coingecko.com/api/v3"
    ALPHA_VANTAGE_BASE = "https://www.alphavantage.co/query"

    # Common crypto symbol → CoinGecko ID mapping
    CRYPTO_MAP = {
        "BTC": "bitcoin", "ETH": "ethereum", "SOL": "solana",
        "ADA": "cardano", "DOT": "polkadot", "DOGE": "dogecoin",
        "XRP": "ripple", "AVAX": "avalanche-2", "MATIC": "matic-network",
        "LINK": "chainlink", "UNI": "uniswap", "ATOM": "cosmos",
        # Extend as needed
    }

    async def get_crypto_price(self, symbol: str) -> float | None:
        coin_id = self.CRYPTO_MAP.get(symbol.upper())
        if not coin_id:
            return None
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.COINGECKO_BASE}/simple/price",
                params={"ids": coin_id, "vs_currencies": "usd"}
            )
            data = resp.json()
            return data.get(coin_id, {}).get("usd")

    async def get_stock_price(self, symbol: str) -> float | None:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                self.ALPHA_VANTAGE_BASE,
                params={
                    "function": "GLOBAL_QUOTE",
                    "symbol": symbol,
                    "apikey": settings.alpha_vantage_api_key
                }
            )
            data = resp.json()
            quote = data.get("Global Quote", {})
            price_str = quote.get("05. price")
            return float(price_str) if price_str else None

    async def refresh_user_assets(self, user: User, db: Session) -> dict:
        assets = db.query(Asset).filter(
            Asset.user_id == user.id,
            Asset.symbol.isnot(None)
        ).all()

        updated, skipped, errors = [], [], []

        for asset in assets:
            try:
                if asset.category == "crypto":
                    new_price = await self.get_crypto_price(asset.symbol)
                elif asset.category in ("stocks", "retirement"):
                    new_price = await self.get_stock_price(asset.symbol)
                else:
                    skipped.append(asset.name)
                    continue

                if new_price:
                    old_value = asset.current_value
                    asset.current_value = asset.quantity * new_price
                    asset.last_updated = datetime.utcnow()
                    updated.append({
                        "asset_id": asset.id,
                        "symbol": asset.symbol,
                        "old_value": old_value,
                        "new_value": asset.current_value,
                        "price": new_price
                    })
            except Exception as e:
                errors.append({"symbol": asset.symbol, "error": str(e)})

        # Record new net worth snapshot
        if updated:
            record_networth_snapshot(user, db)
            db.commit()

        return {"updated": updated, "skipped": skipped, "errors": errors}
```

**File:** `app/routers/prices.py`

```python
router = APIRouter(prefix="/prices", tags=["prices"])

@router.post("/refresh")
async def refresh_prices(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = PriceService()
    result = await service.refresh_user_assets(user, db)
    return result

@router.get("/{symbol}")
async def get_price(symbol: str):
    service = PriceService()
    # Try crypto first, then stocks
    price = await service.get_crypto_price(symbol)
    source = "coingecko"
    if price is None:
        price = await service.get_stock_price(symbol)
        source = "alphavantage"
    if price is None:
        raise HTTPException(status_code=404, detail=f"Price not found for {symbol}")
    return {"symbol": symbol, "price": price, "source": source}
```

---

### Phase 4: Caching

**File:** `app/services/cache_service.py`

```python
from cachetools import TTLCache
from typing import Any

class CacheService:
    """In-memory cache. Drop-in replaceable with Redis later."""

    def __init__(self):
        self._cache = TTLCache(maxsize=1000, ttl=300)

    def get(self, key: str) -> Any | None:
        return self._cache.get(key)

    def set(self, key: str, value: Any, ttl: int | None = None):
        # cachetools TTLCache uses a single TTL; for per-key TTL, use a dict of caches
        self._cache[key] = value

    def invalidate_user(self, user_id: str):
        """Invalidate all cached data for a user."""
        keys = [k for k in self._cache if f":{user_id}" in k]
        for k in keys:
            del self._cache[k]

# Singleton
cache = CacheService()
```

**Cache integration in routers:**

```python
# Example: dashboard router
@router.get("/")
def get_dashboard(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    cache_key = f"dashboard:{user.id}"
    cached = cache.get(cache_key)
    if cached:
        return cached

    # ... existing logic ...
    result = compute_dashboard(user, db)
    cache.set(cache_key, result)
    return result
```

**Cache invalidation:** Called in `transaction_service.smart_create()` and `price_service.refresh_user_assets()` after any data mutation: `cache.invalidate_user(user.id)`.

**TTL strategy:**

| Endpoint | TTL | Rationale |
|----------|-----|-----------|
| Dashboard | 5 min | Changes only on transaction/price writes |
| Analytics | 5 min | Same data source as dashboard |
| Price lookup | 15 min (crypto), 60 min (stocks) | CoinGecko rate limits; Alpha Vantage daily limit |
| Net worth history | 5 min | Changes only on transaction writes |

---

## Implementation Todo List

### Phase 1: Infrastructure

- [ ] **1.1** PostgreSQL migration — `database.py`, `requirements.txt`, `.env`
- [ ] **1.2** Firebase JWT verification — `dependencies.py`, `requirements.txt`, `config.py`
- [ ] **1.3** CORS tightening — `config.py`, `main.py`
- [ ] **1.4** Deploy to Render + Neon — verify `/health` endpoint

### Phase 2: Smart Endpoints

- [ ] **2.1** Create `app/services/` directory
- [ ] **2.2** Build `transaction_service.py` — `smart_create()` with asset + account resolution
- [ ] **2.3** Extract `update_asset_from_transaction()` and `record_networth_snapshot()` into reusable functions (if not already)
- [ ] **2.4** Add `SmartTransactionCreate` schema
- [ ] **2.5** Add `POST /api/v1/transactions/smart` route
- [ ] **2.6** Add `EnrichedTransactionResponse` schema with nested asset + account
- [ ] **2.7** Update `GET /api/v1/transactions` to return enriched responses
- [ ] **2.8** Build `analytics_service.py` — allocation, performance
- [ ] **2.9** Add `AnalyticsResponse` schema
- [ ] **2.10** Add `GET /api/v1/analytics` route + mount in `main.py`
- [ ] **2.11** Implement `period` aggregation in `GET /api/v1/networth/history`
- [ ] **2.12** Test all new endpoints via Swagger UI
- [ ] **2.13** Verify iOS app still works (backward compatibility)

### Phase 3: Price Service

- [ ] **3.1** Add `httpx` to `requirements.txt`
- [ ] **3.2** Add `ALPHA_VANTAGE_API_KEY` to `config.py`
- [ ] **3.3** Build `price_service.py` — CoinGecko + Alpha Vantage
- [ ] **3.4** Add `POST /api/v1/prices/refresh` route
- [ ] **3.5** Add `GET /api/v1/prices/{symbol}` route
- [ ] **3.6** Mount prices router in `main.py`
- [ ] **3.7** Test with real crypto + stock symbols

### Phase 4: Caching

- [ ] **4.1** Add `cachetools` to `requirements.txt`
- [ ] **4.2** Build `cache_service.py`
- [ ] **4.3** Integrate cache into dashboard router
- [ ] **4.4** Integrate cache into analytics router
- [ ] **4.5** Add cache invalidation to transaction service
- [ ] **4.6** Add cache invalidation to price service
- [ ] **4.7** Test cache hit/miss behavior

---

## Verification

1. Start backend locally with `DEBUG_AUTH_ENABLED=true`
2. Open Swagger UI at `http://localhost:8000/docs`
3. Test smart transaction: `POST /api/v1/transactions/smart` with new asset + account → verify both created
4. Test enriched list: `GET /api/v1/transactions` → verify asset + account inline
5. Test analytics: `GET /api/v1/analytics` → verify allocation + performance
6. Test period: `GET /api/v1/networth/history?period=daily` → verify aggregated
7. Test price refresh: `POST /api/v1/prices/refresh` → verify asset values updated
8. Test cache: call dashboard twice, second should be faster (check logs)
9. Test iOS app still works with existing endpoints (no regressions)
10. Deploy to Render, verify `/health` and all endpoints work remotely

---

## Files Modified

| File | Change |
|------|--------|
| `app/database.py` | SQLite → PostgreSQL |
| `app/dependencies.py` | Firebase JWT verification |
| `app/config.py` | New settings |
| `app/main.py` | CORS + mount new routers |
| `app/routers/transactions.py` | Smart endpoint + enriched response |
| `app/routers/networth.py` | Period aggregation |
| `app/schemas/transaction.py` | SmartTransactionCreate + EnrichedTransactionResponse |
| `requirements.txt` | psycopg2-binary, firebase-admin, httpx, cachetools |

## Files Created

| File | Purpose |
|------|---------|
| `app/services/transaction_service.py` | Asset/account resolution, smart create |
| `app/services/analytics_service.py` | Allocation, trends, performance |
| `app/services/price_service.py` | CoinGecko + Alpha Vantage |
| `app/services/cache_service.py` | In-memory TTL cache |
| `app/routers/analytics.py` | GET /analytics |
| `app/routers/prices.py` | Price refresh + lookup |
| `app/schemas/analytics.py` | Analytics response schema |
| `app/schemas/price.py` | Price response schema |
