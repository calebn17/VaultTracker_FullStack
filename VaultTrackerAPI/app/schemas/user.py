from datetime import datetime

from pydantic import BaseModel


class UserBase(BaseModel):
    email: str | None = None


class UserCreate(UserBase):
    firebase_id: str


class UserResponse(UserBase):
    id: str
    firebase_id: str
    created_at: datetime

    class Config:
        from_attributes = True
