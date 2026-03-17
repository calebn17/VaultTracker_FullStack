import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Float, ForeignKey
from sqlalchemy.orm import relationship

from app.database import Base


class NetWorthSnapshot(Base):
    __tablename__ = "networth_snapshots"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    value = Column(Float, nullable=False)

    user = relationship("User", back_populates="networth_snapshots")
