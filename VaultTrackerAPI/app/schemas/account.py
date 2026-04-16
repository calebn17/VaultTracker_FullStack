from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

ACCOUNT_TYPE = Literal["cryptoExchange", "brokerage", "bank", "retirement", "other"]


class AccountBase(BaseModel):
    name: str = Field(max_length=200)
    account_type: ACCOUNT_TYPE


class AccountCreate(AccountBase):
    pass


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=200)
    account_type: ACCOUNT_TYPE | None = None


class AccountResponse(AccountBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True
