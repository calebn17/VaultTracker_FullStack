"""
SQLAlchemy model for a historical net worth data point.

Snapshots are written by the backend to capture total portfolio value at a point
in time, enabling the net-worth history chart in the iOS app. The iOS client no
longer writes snapshots directly; all snapshot management is server-side.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, ForeignKey, String
from sqlalchemy.orm import relationship

from app.database import Base


class NetWorthSnapshot(Base):
    __tablename__ = "networth_snapshots"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    value = Column(Float, nullable=False)

    user = relationship("User", back_populates="networth_snapshots")
