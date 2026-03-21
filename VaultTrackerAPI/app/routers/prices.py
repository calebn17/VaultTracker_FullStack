from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.price import PriceLookupResponse
from app.services.price_service import PriceService

router = APIRouter(prefix="/prices", tags=["Prices"])


@router.post("/refresh")
async def refresh_prices(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = PriceService()
    return await service.refresh_user_assets(user, db)


@router.get("/{symbol}", response_model=PriceLookupResponse)
async def get_price(symbol: str):
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
