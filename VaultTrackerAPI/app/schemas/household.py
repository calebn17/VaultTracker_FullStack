"""
Pydantic schemas for household API (camelCase JSON, matching dashboard/FIRE).
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


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


class HouseholdInviteCodeResponse(BaseModel):
    """Response for POST /households/invite-codes."""

    code: str
    expiresAt: datetime


class HouseholdJoinRequest(BaseModel):
    """Body for POST /households/join."""

    code: str = Field(min_length=1)
