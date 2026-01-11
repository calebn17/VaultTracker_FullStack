from datetime import datetime
from pydantic import BaseModel


class TransactionBase(BaseModel):
    asset_id: str
    account_id: str
    transaction_type: str  # buy, sell
    quantity: float
    price_per_unit: float
    date: datetime | None = None


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    transaction_type: str | None = None
    quantity: float | None = None
    price_per_unit: float | None = None
    date: datetime | None = None


class TransactionResponse(TransactionBase):
    id: str
    user_id: str
    date: datetime

    class Config:
        from_attributes = True
