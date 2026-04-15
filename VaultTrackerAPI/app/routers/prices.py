from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from starlette.requests import Request

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.rate_limit import coerce_json_response, limiter, rate_limit_external
from app.schemas.price import PriceLookupResponse
from app.services.price_service import PriceService

router = APIRouter(prefix="/prices", tags=["Prices"])


@router.post("/refresh")
@limiter.limit(rate_limit_external)
@coerce_json_response
async def refresh_prices(
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = PriceService()
    return await service.refresh_user_assets(user, db)


@router.get("/{symbol}", response_model=PriceLookupResponse)
@limiter.limit(rate_limit_external)
@coerce_json_response
async def get_price(request: Request, symbol: str):
    service = PriceService()
    price = await service.get_crypto_price(symbol)
    src = "coingecko"
    if price is None:
        price = await service.get_stock_price(symbol)
        src = "alphavantage"
    if price is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Price not found for {symbol}",
        )
    return PriceLookupResponse(symbol=symbol.upper(), price=price, source=src)
