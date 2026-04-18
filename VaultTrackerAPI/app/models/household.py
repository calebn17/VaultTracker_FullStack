"""
Household model: a shared container for household members (e.g. net worth dashboard).

The v1 client caps membership at two users; the schema supports more.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, String
from sqlalchemy.orm import relationship

from app.database import Base


class Household(Base):
    __tablename__ = "households"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    memberships = relationship(
        "HouseholdMembership",
        back_populates="household",
        cascade="all, delete-orphan",
    )
    invite_codes = relationship(
        "HouseholdInviteCode",
        back_populates="household",
        cascade="all, delete-orphan",
    )
