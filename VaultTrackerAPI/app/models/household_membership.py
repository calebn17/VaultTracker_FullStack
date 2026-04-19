"""
Join table linking users to households. Each user may belong to at most one household.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import relationship

from app.database import Base


class HouseholdMembership(Base):
    __tablename__ = "household_memberships"
    __table_args__ = (
        UniqueConstraint(
            "household_id",
            "user_id",
            name="uq_household_membership_household_user",
        ),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id = Column(
        String,
        ForeignKey("households.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id = Column(
        String,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    joined_at = Column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    household = relationship("Household", back_populates="memberships")
    user = relationship("User", back_populates="household_membership")
