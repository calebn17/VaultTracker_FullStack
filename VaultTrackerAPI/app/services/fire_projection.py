"""
Assemble FIRE GET /fire/projection from DB profile + dashboard aggregate + pure math.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal, cast

from sqlalchemy.orm import Session

from app.models.fire_profile import FIREProfile
from app.schemas.fire import (
    FIREAllocation,
    FIREAllocationSlice,
    FIREFireTargets,
    FIREFireTargetTier,
    FIREGoalAssessment,
    FIREMonthlyBreakdown,
    FIREProfileResponse,
    FIREProjectionCurvePoint,
    FIREProjectionInputs,
    FIREProjectionResponse,
)
from app.services import fire_service as fs
from app.services.dashboard_aggregate import aggregate_dashboard

_CATEGORY_KEYS = ("crypto", "stocks", "cash", "realEstate", "retirement")


def profile_to_response(profile: FIREProfile) -> FIREProfileResponse:
    return FIREProfileResponse(
        id=profile.id,
        currentAge=profile.current_age,
        annualIncome=profile.annual_income,
        annualExpenses=profile.annual_expenses,
        targetRetirementAge=profile.target_retirement_age,
        createdAt=profile.created_at,
        updatedAt=profile.updated_at,
    )


def build_fire_projection(db: Session, profile: FIREProfile) -> FIREProjectionResponse:
    dash = aggregate_dashboard(db, profile.user_id)
    nw = float(dash.totalNetWorth)
    ct = dash.categoryTotals

    inputs = FIREProjectionInputs(
        currentAge=profile.current_age,
        annualIncome=profile.annual_income,
        annualExpenses=profile.annual_expenses,
        currentNetWorth=nw,
        targetRetirementAge=profile.target_retirement_age,
    )

    annual_income = float(profile.annual_income)
    annual_expenses = float(profile.annual_expenses)
    annual_savings = annual_income - annual_expenses
    savings_rate = annual_savings / annual_income if annual_income > 1e-9 else 0.0

    targets_raw = fs.compute_fire_targets(annual_expenses)

    def tiers_all_null() -> FIREFireTargets:
        return FIREFireTargets(
            leanFire=FIREFireTargetTier(
                targetAmount=targets_raw["leanFire"]["targetAmount"],
                yearsToTarget=None,
                targetAge=None,
            ),
            fire=FIREFireTargetTier(
                targetAmount=targets_raw["fire"]["targetAmount"],
                yearsToTarget=None,
                targetAge=None,
            ),
            fatFire=FIREFireTargetTier(
                targetAmount=targets_raw["fatFire"]["targetAmount"],
                yearsToTarget=None,
                targetAge=None,
            ),
        )

    if annual_savings <= 0:
        return FIREProjectionResponse(
            status="unreachable",
            unreachableReason="non_positive_savings",
            inputs=inputs,
            allocation=None,
            blendedReturn=None,
            realBlendedReturn=None,
            inflationRate=None,
            annualSavings=None,
            savingsRate=None,
            fireTargets=tiers_all_null(),
            projectionCurve=[],
            monthlyBreakdown=FIREMonthlyBreakdown(
                monthlySurplus=0.0, monthsToFire=None
            ),
            goalAssessment=None,
        )

    alloc_for_blended: dict[str, dict[str, float]] = {}
    allocation: FIREAllocation | None = None
    if nw > 1e-9:
        for key in _CATEGORY_KEYS:
            val = float(getattr(ct, key))
            pct = (val / nw) * 100.0
            alloc_for_blended[key] = {"value": val, "percentage": pct}
        nominal, real_br = fs.compute_blended_return(alloc_for_blended)
        slices = {
            key: FIREAllocationSlice(
                value=float(getattr(ct, key)),
                percentage=(float(getattr(ct, key)) / nw) * 100.0,
                expectedReturn=fs.DEFAULT_RETURNS[key],
            )
            for key in _CATEGORY_KEYS
        }
        allocation = FIREAllocation(**slices)
    else:
        nominal, real_br = fs.compute_blended_return({})

    internal_curve = fs.generate_projection_curve(
        nw, annual_savings, real_br, years=fs.PROJECTION_YEARS
    )
    base_year = datetime.now(timezone.utc).year
    projection_curve = [
        FIREProjectionCurvePoint(
            age=profile.current_age + i,
            year=base_year + i,
            projectedValue=pt["projectedValue"],
        )
        for i, pt in enumerate(internal_curve)
    ]

    cross_lean = fs.find_crossover_year(
        internal_curve, targets_raw["leanFire"]["targetAmount"]
    )
    cross_regular = fs.find_crossover_year(
        internal_curve, targets_raw["fire"]["targetAmount"]
    )
    cross_fat = fs.find_crossover_year(
        internal_curve, targets_raw["fatFire"]["targetAmount"]
    )

    any_cross = (
        cross_lean is not None or cross_regular is not None or cross_fat is not None
    )
    status = cast(
        Literal["reachable", "beyond_horizon"],
        "reachable" if any_cross else "beyond_horizon",
    )

    def tier_model(key: str, cross_idx: int | None) -> FIREFireTargetTier:
        amt = targets_raw[key]["targetAmount"]
        if cross_idx is None:
            return FIREFireTargetTier(
                targetAmount=amt, yearsToTarget=None, targetAge=None
            )
        return FIREFireTargetTier(
            targetAmount=amt,
            yearsToTarget=cross_idx,
            targetAge=profile.current_age + cross_idx,
        )

    fire_targets = FIREFireTargets(
        leanFire=tier_model("leanFire", cross_lean),
        fire=tier_model("fire", cross_regular),
        fatFire=tier_model("fatFire", cross_fat),
    )

    if status == "reachable" and cross_regular is not None:
        months_to_fire = cross_regular * 12
    else:
        months_to_fire = None

    monthly_surplus = annual_savings / 12.0

    goal_assessment: FIREGoalAssessment | None = None
    if profile.target_retirement_age is not None and status != "unreachable":
        g = fs.compute_goal_assessment(
            {
                "current_age": profile.current_age,
                "target_retirement_age": profile.target_retirement_age,
                "annual_income": annual_income,
                "annual_expenses": annual_expenses,
                "current_net_worth": nw,
            },
            internal_curve,
            targets_raw["fire"]["targetAmount"],
            real_return=real_br,
        )
        if g is not None:
            goal_assessment = FIREGoalAssessment(**g)

    return FIREProjectionResponse(
        status=status,
        unreachableReason=None,
        inputs=inputs,
        allocation=allocation,
        blendedReturn=nominal,
        realBlendedReturn=real_br,
        inflationRate=fs.DEFAULT_INFLATION,
        annualSavings=annual_savings,
        savingsRate=savings_rate,
        fireTargets=fire_targets,
        projectionCurve=projection_curve,
        monthlyBreakdown=FIREMonthlyBreakdown(
            monthlySurplus=monthly_surplus, monthsToFire=months_to_fire
        ),
        goalAssessment=goal_assessment,
    )
