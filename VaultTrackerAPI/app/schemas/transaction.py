from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, field_validator, model_validator


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


_ALLOWED_CATEGORIES = frozenset(
    {"crypto", "stocks", "cash", "realEstate", "retirement"}
)
_SYMBOL_CATEGORIES = frozenset({"crypto", "stocks", "retirement"})


class SmartTransactionCreate(BaseModel):
    transaction_type: str
    category: str
    asset_name: str
    symbol: str | None = None
    quantity: float
    price_per_unit: float
    account_name: str
    account_type: str
    date: datetime | None = None

    @field_validator("transaction_type")
    @classmethod
    def transaction_type_lower(cls, v: str) -> str:
        t = v.lower()
        if t not in ("buy", "sell"):
            raise ValueError('transaction_type must be "buy" or "sell"')
        return t

    @field_validator("category")
    @classmethod
    def category_ok(cls, v: str) -> str:
        if v not in _ALLOWED_CATEGORIES:
            raise ValueError(f"category must be one of: {sorted(_ALLOWED_CATEGORIES)}")
        return v

    @model_validator(mode="after")
    def symbol_when_needed(self) -> SmartTransactionCreate:
        if self.category in _SYMBOL_CATEGORIES:
            if not (self.symbol and self.symbol.strip()):
                raise ValueError(f"symbol is required for category {self.category!r}")
        return self


class AssetSummary(BaseModel):
    id: str
    name: str
    symbol: str | None = None
    category: str


class AccountSummary(BaseModel):
    id: str
    name: str
    account_type: str


class EnrichedTransactionResponse(BaseModel):
    id: str
    user_id: str
    asset_id: str
    account_id: str
    transaction_type: str
    quantity: float
    price_per_unit: float
    total_value: float
    date: datetime
    asset: AssetSummary
    account: AccountSummary

    class Config:
        from_attributes = True
