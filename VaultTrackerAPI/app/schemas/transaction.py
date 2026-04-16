from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.account import ACCOUNT_TYPE
from app.schemas.asset import ASSET_CATEGORY

TRANSACTION_SIDE = Literal["buy", "sell"]

_SYMBOL_CATEGORIES = frozenset({"crypto", "stocks", "retirement"})


class TransactionBase(BaseModel):
    asset_id: str
    account_id: str
    transaction_type: TRANSACTION_SIDE
    quantity: float = Field(gt=0)
    price_per_unit: float = Field(gt=0)
    date: datetime | None = None

    @field_validator("transaction_type", mode="before")
    @classmethod
    def transaction_type_lower(cls, v: object) -> object:
        if isinstance(v, str):
            return v.lower()
        return v


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    transaction_type: TRANSACTION_SIDE | None = None
    quantity: float | None = None
    price_per_unit: float | None = None
    date: datetime | None = None

    @field_validator("transaction_type", mode="before")
    @classmethod
    def transaction_type_lower(cls, v: object) -> object:
        if isinstance(v, str):
            return v.lower()
        return v

    @field_validator("quantity")
    @classmethod
    def quantity_positive_when_set(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("quantity must be greater than 0")
        return v

    @field_validator("price_per_unit")
    @classmethod
    def price_positive_when_set(cls, v: float | None) -> float | None:
        if v is not None and v <= 0:
            raise ValueError("price_per_unit must be greater than 0")
        return v


class TransactionResponse(TransactionBase):
    id: str
    user_id: str
    date: datetime

    class Config:
        from_attributes = True


class SmartTransactionCreate(BaseModel):
    transaction_type: TRANSACTION_SIDE
    category: ASSET_CATEGORY
    asset_name: str = Field(max_length=200)
    symbol: str | None = Field(default=None, max_length=20)
    quantity: float = Field(gt=0)
    price_per_unit: float = Field(gt=0)
    account_name: str = Field(max_length=200)
    account_type: ACCOUNT_TYPE
    date: datetime | None = None

    @field_validator("transaction_type", mode="before")
    @classmethod
    def transaction_type_lower(cls, v: object) -> object:
        if isinstance(v, str):
            return v.lower()
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
