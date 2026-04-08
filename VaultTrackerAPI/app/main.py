# FastAPI application entry point for VaultTracker API.
#
# Routers included (all prefixed /api/v1):
#   dashboard, accounts, assets, transactions, networth, users, analytics, prices
#
# Database tables are created on startup via SQLAlchemy's create_all.
# CORS allowed origins come from settings (comma-separated). Tighten for production.

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import app.models  # noqa: F401 — register all ORM tables with Base.metadata
from app.config import settings
from app.database import Base, engine
from app.routers import (
    accounts_router,
    analytics_router,
    assets_router,
    dashboard_router,
    networth_router,
    prices_router,
    transactions_router,
    users_router,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create database tables on startup
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan,
)

# CORS: browsers (e.g. web client, Swagger UI) send an Origin header;
# native iOS URLSession does not.
_origins = [o.strip() for o in settings.allowed_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers with /api/v1 prefix
app.include_router(dashboard_router, prefix="/api/v1")
app.include_router(accounts_router, prefix="/api/v1")
app.include_router(assets_router, prefix="/api/v1")
app.include_router(transactions_router, prefix="/api/v1")
app.include_router(networth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(prices_router, prefix="/api/v1")


@app.get("/")
async def root():
    return {"message": "VaultTracker API", "version": "1.0.0"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
