"""Pydantic validation for FIRE schemas (no HTTP)."""

from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.schemas.fire import (
    FIREProfileInput,
    FIREProfileResponse,
    FIREProjectionResponse,
)


def test_fire_profile_input_accepts_valid_payload_with_target_age() -> None:
    # Valid PUT body: ages, income, expenses, and goal age above current age.
    body = FIREProfileInput.model_validate(
        {
            "currentAge": 32,
            "annualIncome": 145_000,
            "annualExpenses": 62_000,
            "targetRetirementAge": 45,
        }
    )
    assert body.currentAge == 32
    assert body.targetRetirementAge == 45


def test_fire_profile_input_accepts_omitted_target_retirement_age() -> None:
    # Omitting target retirement age is allowed; the field stays None.
    body = FIREProfileInput.model_validate(
        {
            "currentAge": 40,
            "annualIncome": 100_000,
            "annualExpenses": 50_000,
        }
    )
    assert body.targetRetirementAge is None


def test_fire_profile_input_rejects_current_age_below_minimum() -> None:
    # currentAge must be at least 18.
    with pytest.raises(ValidationError):
        FIREProfileInput.model_validate(
            {
                "currentAge": 17,
                "annualIncome": 50_000,
                "annualExpenses": 40_000,
            }
        )


def test_fire_profile_input_rejects_current_age_above_maximum() -> None:
    # currentAge must be at most 100.
    with pytest.raises(ValidationError):
        FIREProfileInput.model_validate(
            {
                "currentAge": 101,
                "annualIncome": 50_000,
                "annualExpenses": 40_000,
            }
        )


def test_fire_profile_input_rejects_negative_annual_income() -> None:
    # Post-tax income cannot be negative.
    with pytest.raises(ValidationError):
        FIREProfileInput.model_validate(
            {
                "currentAge": 30,
                "annualIncome": -1,
                "annualExpenses": 40_000,
            }
        )


def test_fire_profile_input_rejects_negative_annual_expenses() -> None:
    # Expenses cannot be negative.
    with pytest.raises(ValidationError):
        FIREProfileInput.model_validate(
            {
                "currentAge": 30,
                "annualIncome": 80_000,
                "annualExpenses": -100,
            }
        )


def test_fire_profile_input_rejects_target_retirement_age_not_above_current() -> None:
    # When set, target retirement age must be strictly greater than current age.
    with pytest.raises(ValidationError) as exc:
        FIREProfileInput.model_validate(
            {
                "currentAge": 50,
                "annualIncome": 100_000,
                "annualExpenses": 60_000,
                "targetRetirementAge": 50,
            }
        )
    assert "targetRetirementAge" in str(exc.value)


def test_fire_profile_input_rejects_target_retirement_age_above_100() -> None:
    # Goal age cannot exceed 100 even when it is greater than current age.
    with pytest.raises(ValidationError) as exc:
        FIREProfileInput.model_validate(
            {
                "currentAge": 99,
                "annualIncome": 50_000,
                "annualExpenses": 40_000,
                "targetRetirementAge": 101,
            }
        )
    assert "targetRetirementAge" in str(exc.value)


def test_fire_profile_response_parses_iso_datetimes() -> None:
    # GET profile JSON with ISO timestamps maps onto the response model.
    now = datetime.now(timezone.utc)
    row = FIREProfileResponse.model_validate(
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "currentAge": 32,
            "annualIncome": 145_000.0,
            "annualExpenses": 62_000.0,
            "targetRetirementAge": 45,
            "createdAt": now.isoformat(),
            "updatedAt": now.isoformat(),
        }
    )
    assert row.id == "550e8400-e29b-41d4-a716-446655440000"
    assert row.createdAt.tzinfo is not None


def test_fire_projection_response_reachable_example_from_spec() -> None:
    # A reachable projection payload from the design doc round-trips through the schema.
    payload = {
        "status": "reachable",
        "unreachableReason": None,
        "inputs": {
            "currentAge": 32,
            "annualIncome": 145_000,
            "annualExpenses": 62_000,
            "currentNetWorth": 312_450,
            "targetRetirementAge": 45,
        },
        "allocation": {
            "crypto": {"value": 45_000, "percentage": 14.4, "expectedReturn": 0.10},
            "stocks": {"value": 180_000, "percentage": 57.6, "expectedReturn": 0.08},
            "cash": {"value": 25_000, "percentage": 8.0, "expectedReturn": 0.02},
            "realEstate": {"value": 40_000, "percentage": 12.8, "expectedReturn": 0.05},
            "retirement": {"value": 22_450, "percentage": 7.2, "expectedReturn": 0.07},
        },
        "blendedReturn": 0.072,
        "realBlendedReturn": 0.042,
        "inflationRate": 0.03,
        "annualSavings": 83_000,
        "savingsRate": 0.572,
        "fireTargets": {
            "leanFire": {
                "targetAmount": 1_085_000,
                "yearsToTarget": 10,
                "targetAge": 42,
            },
            "fire": {"targetAmount": 1_550_000, "yearsToTarget": 14, "targetAge": 46},
            "fatFire": {
                "targetAmount": 2_325_000,
                "yearsToTarget": None,
                "targetAge": None,
            },
        },
        "projectionCurve": [
            {"age": 32, "year": 2026, "projectedValue": 312_450},
            {"age": 33, "year": 2027, "projectedValue": 418_000},
        ],
        "monthlyBreakdown": {"monthlySurplus": 6916, "monthsToFire": 168},
        "goalAssessment": {
            "targetAge": 45,
            "requiredSavingsRate": 0.65,
            "currentSavingsRate": 0.572,
            "status": "behind",
            "gapAmount": 120_000,
        },
    }
    model = FIREProjectionResponse.model_validate(payload)
    assert model.status == "reachable"
    assert model.allocation is not None
    assert model.allocation.crypto.percentage == 14.4
    assert model.goalAssessment is not None
    assert model.goalAssessment.status == "behind"
    assert model.goalAssessment.computedBeyondProjectionHorizon is False


def test_fire_projection_response_unreachable_example_from_spec() -> None:
    # Unreachable: no allocation curve; still has targets and empty projectionCurve.
    payload = {
        "status": "unreachable",
        "unreachableReason": "non_positive_savings",
        "inputs": {
            "currentAge": 40,
            "annualIncome": 50_000,
            "annualExpenses": 55_000,
            "currentNetWorth": 100_000,
            "targetRetirementAge": None,
        },
        "fireTargets": {
            "leanFire": {
                "targetAmount": 875_000,
                "yearsToTarget": None,
                "targetAge": None,
            },
            "fire": {
                "targetAmount": 1_250_000,
                "yearsToTarget": None,
                "targetAge": None,
            },
            "fatFire": {
                "targetAmount": 1_875_000,
                "yearsToTarget": None,
                "targetAge": None,
            },
        },
        "projectionCurve": [],
        "monthlyBreakdown": {"monthlySurplus": 0, "monthsToFire": None},
        "goalAssessment": None,
    }
    model = FIREProjectionResponse.model_validate(payload)
    assert model.status == "unreachable"
    assert model.unreachableReason == "non_positive_savings"
    assert model.allocation is None
    assert model.projectionCurve == []
