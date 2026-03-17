# FastAPI application entry point for VaultTracker API.
#
# Routers included (all prefixed /api/v1):
#   dashboard, accounts, assets, transactions, networth, users
#
# Database tables are created on startup via SQLAlchemy's create_all.
# CORS is open for all origins during development; restrict for production.

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.routers import (
    dashboard_router,
    accounts_router,
    assets_router,
    transactions_router,
    networth_router,
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

# CORS middleware for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
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


@app.get("/")
async def root():
    return {"message": "VaultTracker API", "version": "1.0.0"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
