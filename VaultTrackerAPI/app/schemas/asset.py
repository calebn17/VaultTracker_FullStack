from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

ASSET_CATEGORY = Literal["crypto", "stocks", "cash", "realEstate", "retirement"]


class AssetBase(BaseModel):
    name: str = Field(max_length=200)
    symbol: str | None = Field(default=None, max_length=20)
    category: ASSET_CATEGORY
    quantity: float = Field(default=0.0, ge=0)
    current_value: float = Field(default=0.0, ge=0)


class AssetCreate(AssetBase):
    pass


class AssetResponse(AssetBase):
    id: str
    user_id: str
    last_updated: datetime

    class Config:
        from_attributes = True
