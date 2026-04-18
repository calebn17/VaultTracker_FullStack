"""
Pydantic schemas for household API (camelCase JSON, matching dashboard/FIRE).
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class HouseholdMemberResponse(BaseModel):
    """One member row for GET /households/me and POST /households."""

    model_config = ConfigDict(from_attributes=True)

    userId: str
    email: str | None = None


class HouseholdResponse(BaseModel):
    """Household summary including member list ordered by join time."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    createdAt: datetime
    members: list[HouseholdMemberResponse]
