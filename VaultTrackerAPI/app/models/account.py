"""
SQLAlchemy model for a financial account (e.g. brokerage, bank, crypto exchange).

Transactions are always posted to a specific account so the user can track which
institution holds each asset. `account_type` uses snake_case strings that map to
the iOS `AccountType` enum via `AccountMapper.mapAccountType`.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, String
from sqlalchemy.orm import relationship

from app.database import Base


class Account(Base):
    __tablename__ = "accounts"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    account_type = Column(
        String, nullable=False
    )  # cryptoExchange, brokerage, bank, etc.
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    user = relationship("User", back_populates="accounts")
    transactions = relationship(
        "Transaction", back_populates="account", cascade="all, delete-orphan"
    )
