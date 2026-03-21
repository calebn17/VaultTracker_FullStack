from app.routers.dashboard import router as dashboard_router
from app.routers.accounts import router as accounts_router
from app.routers.assets import router as assets_router
from app.routers.transactions import router as transactions_router
from app.routers.networth import router as networth_router
from app.routers.users import router as users_router
from app.routers.analytics import router as analytics_router
from app.routers.prices import router as prices_router

__all__ = [
    "dashboard_router",
    "accounts_router",
    "assets_router",
    "transactions_router",
    "networth_router",
    "users_router",
    "analytics_router",
    "prices_router",
]
