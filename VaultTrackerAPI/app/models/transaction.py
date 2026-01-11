import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, Float, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    asset_id = Column(String, ForeignKey("assets.id"), nullable=False)
    account_id = Column(String, ForeignKey("accounts.id"), nullable=False)
    transaction_type = Column(String, nullable=False)  # buy, sell
    quantity = Column(Float, nullable=False)
    price_per_unit = Column(Float, nullable=False)
    date = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="transactions")
    asset = relationship("Asset", back_populates="transactions")
    account = relationship("Account", back_populates="transactions")
