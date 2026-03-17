"""
SQLAlchemy model for an application user.

The primary key `id` is an internal UUID. `firebase_id` is the stable identifier
issued by Firebase Auth and is used as the lookup key in `get_current_user`. New
users are auto-provisioned on first authenticated request; no separate sign-up
endpoint is needed.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    firebase_id = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    accounts = relationship("Account", back_populates="user", cascade="all, delete-orphan")
    assets = relationship("Asset", back_populates="user", cascade="all, delete-orphan")
    transactions = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    networth_snapshots = relationship("NetWorthSnapshot", back_populates="user", cascade="all, delete-orphan")
