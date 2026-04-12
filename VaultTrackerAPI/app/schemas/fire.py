"""
Pydantic schemas for FIRE calculator API (profile + projection).

JSON uses camelCase field names, matching other API schemas (e.g. dashboard).
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class FIREProfileInput(BaseModel):
    """Request body for PUT /fire/profile."""

    currentAge: int = Field(ge=18, le=100)
    annualIncome: float = Field(ge=0)
    annualExpenses: float = Field(ge=0)
    targetRetirementAge: int | None = None

    @model_validator(mode="after")
    def target_retirement_age_bounds(self) -> FIREProfileInput:
        if self.targetRetirementAge is None:
            return self
        if self.targetRetirementAge <= self.currentAge:
            raise ValueError("targetRetirementAge must be greater than currentAge")
        if self.targetRetirementAge > 100:
            raise ValueError("targetRetirementAge must be at most 100")
        return self


class FIREProfileResponse(BaseModel):
    """Response for GET /fire/profile."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    currentAge: int
    annualIncome: float
    annualExpenses: float
    targetRetirementAge: int | None
    createdAt: datetime
    updatedAt: datetime


class FIREProjectionInputs(BaseModel):
    currentAge: int
    annualIncome: float
    annualExpenses: float
    currentNetWorth: float
    targetRetirementAge: int | None


class FIREAllocationSlice(BaseModel):
    value: float
    percentage: float
    expectedReturn: float


class FIREAllocation(BaseModel):
    crypto: FIREAllocationSlice
    stocks: FIREAllocationSlice
    cash: FIREAllocationSlice
    realEstate: FIREAllocationSlice
    retirement: FIREAllocationSlice


class FIREFireTargetTier(BaseModel):
    targetAmount: float
    yearsToTarget: int | None = None
    targetAge: int | None = None


class FIREFireTargets(BaseModel):
    leanFire: FIREFireTargetTier
    fire: FIREFireTargetTier
    fatFire: FIREFireTargetTier


class FIREProjectionCurvePoint(BaseModel):
    age: int
    year: int
    projectedValue: float


class FIREMonthlyBreakdown(BaseModel):
    monthlySurplus: float
    monthsToFire: int | None = None


class FIREGoalAssessment(BaseModel):
    targetAge: int
    requiredSavingsRate: float
    currentSavingsRate: float
    status: Literal["ahead", "on_track", "behind"]
    gapAmount: float
    computedBeyondProjectionHorizon: bool = Field(
        default=False,
        description=(
            "True when goal age is past the fixed projection window; wealth at "
            "goal age uses the same return/savings model as the chart, extrapolated."
        ),
    )


class FIREProjectionResponse(BaseModel):
    """Response for GET /fire/projection."""

    status: Literal["reachable", "beyond_horizon", "unreachable"]
    unreachableReason: Literal["non_positive_savings"] | None = None
    inputs: FIREProjectionInputs
    allocation: FIREAllocation | None = None
    blendedReturn: float | None = None
    realBlendedReturn: float | None = None
    inflationRate: float | None = None
    annualSavings: float | None = None
    savingsRate: float | None = None
    fireTargets: FIREFireTargets
    projectionCurve: list[FIREProjectionCurvePoint]
    monthlyBreakdown: FIREMonthlyBreakdown
    goalAssessment: FIREGoalAssessment | None = None
