"""
Single-use invite codes for joining a household (expires after a short TTL).
"""

import uuid

from sqlalchemy import Column, DateTime, ForeignKey, String
from sqlalchemy.orm import relationship

from app.database import Base

# Default TTL; tests may monkeypatch `household_invite_code.TTL_SECONDS`.
TTL_SECONDS = 15 * 60


class HouseholdInviteCode(Base):
    __tablename__ = "household_invite_codes"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id = Column(
        String,
        ForeignKey("households.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    code = Column(String, unique=True, nullable=False, index=True)
    created_by_user_id = Column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used_at = Column(DateTime(timezone=True), nullable=True)
    used_by_user_id = Column(String, ForeignKey("users.id"), nullable=True)

    household = relationship("Household", back_populates="invite_codes")
