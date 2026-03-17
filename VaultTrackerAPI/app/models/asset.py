"""
SQLAlchemy model for a financial asset.

Represents a single holding (e.g. "Bitcoin", "AAPL", "Checking Account").
`quantity` and `current_value` are kept current by `update_asset_from_transaction`
whenever a transaction is created, updated, or deleted. `symbol` is nullable
because cash and real-estate assets have no ticker.
Category must be one of: crypto, stocks, cash, realEstate, retirement.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Float, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class Asset(Base):
    __tablename__ = "assets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    symbol = Column(String, nullable=True)
    category = Column(String, nullable=False)  # crypto, stocks, cash, realEstate, retirement
    quantity = Column(Float, default=0.0)
    current_value = Column(Float, default=0.0)
    last_updated = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="assets")
    transactions = relationship("Transaction", back_populates="asset", cascade="all, delete-orphan")
