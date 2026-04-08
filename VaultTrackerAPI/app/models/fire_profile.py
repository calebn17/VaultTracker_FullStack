"""
SQLAlchemy model for persisted FIRE calculator inputs (one row per user).
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base


class FIREProfile(Base):
    __tablename__ = "fire_profiles"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(
        String, ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    current_age = Column(Integer, nullable=False)
    annual_income = Column(Float, nullable=False)
    annual_expenses = Column(Float, nullable=False)
    target_retirement_age = Column(Integer, nullable=True)
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    user = relationship("User", back_populates="fire_profile")
