from datetime import datetime

from pydantic import BaseModel


class AssetBase(BaseModel):
    name: str
    symbol: str | None = None
    category: str  # crypto, stocks, cash, realEstate, retirement
    quantity: float = 0.0
    current_value: float = 0.0


class AssetCreate(AssetBase):
    pass


class AssetResponse(AssetBase):
    id: str
    user_id: str
    last_updated: datetime

    class Config:
        from_attributes = True
