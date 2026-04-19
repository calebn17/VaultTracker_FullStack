"""
Historical net worth points for a household (sum of members' portfolio values).

Written alongside per-user NetWorthSnapshot when a member's portfolio changes.
"""

import uuid

from sqlalchemy import Column, DateTime, Float, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import relationship

from app.database import Base


class HouseholdNetWorthSnapshot(Base):
    __tablename__ = "household_networth_snapshots"
    __table_args__ = (
        UniqueConstraint(
            "household_id",
            "date",
            name="uq_household_networth_snapshot_household_date",
        ),
    )

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id = Column(
        String,
        ForeignKey("households.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date = Column(DateTime(timezone=True), nullable=False)
    value = Column(Float, nullable=False)

    household = relationship("Household", back_populates="networth_snapshots")
