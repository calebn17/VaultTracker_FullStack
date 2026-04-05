from datetime import datetime

from pydantic import BaseModel


class AccountBase(BaseModel):
    name: str
    account_type: str  # cryptoExchange, brokerage, bank, etc.


class AccountCreate(AccountBase):
    pass


class AccountUpdate(BaseModel):
    name: str | None = None
    account_type: str | None = None


class AccountResponse(AccountBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True
