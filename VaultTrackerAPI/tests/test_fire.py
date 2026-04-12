"""Unit tests for fire_service pure functions (no DB / HTTP)."""

import pytest

from app.services import fire_service as fs


def test_default_returns_and_projection_constants() -> None:
    assert fs.DEFAULT_RETURNS["cash"] == 0.02
    assert fs.DEFAULT_INFLATION == 0.03
    assert fs.FIRE_MULTIPLIER == 25
    assert fs.LEAN_FIRE_EXPENSE_RATIO == 0.7
    assert fs.FAT_FIRE_EXPENSE_RATIO == 1.5
    assert fs.PROJECTION_YEARS == 30


def test_compute_blended_return_weighted_nominal_and_real() -> None:
    # 50% stocks (8%), 50% cash (2%) -> 5% nominal, 2% real after 3% inflation.
    alloc = {
        "stocks": {"value": 50_000, "percentage": 50.0},
        "cash": {"value": 50_000, "percentage": 50.0},
    }
    nominal, real = fs.compute_blended_return(alloc)
    assert nominal == pytest.approx(0.05)
    assert real == pytest.approx(0.02)


def test_compute_blended_return_all_cash_matches_spec_edge_case() -> None:
    # Spec §3: 100% cash -> 2% nominal, -1% real.
    alloc = {"cash": {"value": 100_000, "percentage": 100.0}}
    nominal, real = fs.compute_blended_return(alloc)
    assert nominal == pytest.approx(0.02)
    assert real == pytest.approx(-0.01)


def test_compute_blended_return_empty_uses_default_7_percent() -> None:
    # No portfolio breakdown -> 7% nominal per spec edge case.
    nominal, real = fs.compute_blended_return({})
    assert nominal == pytest.approx(fs.DEFAULT_EMPTY_PORTFOLIO_NOMINAL_RETURN)
    assert real == pytest.approx(0.04)


def test_compute_blended_return_all_zero_percentages_use_default() -> None:
    nominal, real = fs.compute_blended_return(
        {"stocks": {"value": 0, "percentage": 0.0}}
    )
    assert nominal == pytest.approx(0.07)


def test_compute_fire_targets_formulas() -> None:
    expenses = 62_000.0
    targets = fs.compute_fire_targets(expenses)
    assert targets["fire"]["targetAmount"] == expenses * 25
    assert targets["leanFire"]["targetAmount"] == pytest.approx(expenses * 0.7 * 25)
    assert targets["fatFire"]["targetAmount"] == pytest.approx(expenses * 1.5 * 25)


def test_generate_projection_curve_year_zero_and_recurrence() -> None:
    # r=0: linear accumulation of savings.
    curve = fs.generate_projection_curve(1000.0, 500.0, 0.0, years=3)
    assert len(curve) == 4
    assert curve[0]["projectedValue"] == 1000.0
    assert curve[1]["projectedValue"] == 1500.0
    assert curve[2]["projectedValue"] == 2000.0
    assert curve[3]["projectedValue"] == 2500.0


def test_generate_projection_curve_with_real_return() -> None:
    curve = fs.generate_projection_curve(10_000.0, 0.0, 0.1, years=2)
    assert curve[0]["projectedValue"] == 10_000.0
    assert curve[1]["projectedValue"] == pytest.approx(11_000.0)
    assert curve[2]["projectedValue"] == pytest.approx(12_100.0)


def test_generate_projection_curve_zero_net_worth_savings_only() -> None:
    curve = fs.generate_projection_curve(0.0, 1_000.0, 0.0, years=2)
    assert curve[0]["projectedValue"] == 0.0
    assert curve[1]["projectedValue"] == 1_000.0
    assert curve[2]["projectedValue"] == 2_000.0


def test_find_crossover_year_first_index_at_or_above_target() -> None:
    curve = [
        {"projectedValue": 0.0},
        {"projectedValue": 40.0},
        {"projectedValue": 120.0},
    ]
    assert fs.find_crossover_year(curve, 100.0) == 2
    assert fs.find_crossover_year(curve, 0.0) == 0


def test_find_crossover_year_none_when_never_reached() -> None:
    curve = [{"projectedValue": float(i)} for i in range(5)]
    assert fs.find_crossover_year(curve, 100.0) is None


def test_compute_goal_assessment_none_without_target_age() -> None:
    profile = {
        "current_age": 40,
        "target_retirement_age": None,
        "annual_income": 100_000,
        "annual_expenses": 60_000,
        "current_net_worth": 0.0,
    }
    curve = [{"projectedValue": 0.0}]
    assert (
        fs.compute_goal_assessment(profile, curve, fire_target=1.0, real_return=0.0)
        is None
    )


def test_compute_goal_assessment_ahead_on_track_behind() -> None:
    base_profile = {
        "current_age": 40,
        "target_retirement_age": 50,
        "annual_income": 100_000,
        "annual_expenses": 40_000,
        "current_net_worth": 500_000,
    }
    fire_target = 1_000_000.0
    real_ret = 0.0

    def curve_at_goal(pv: float) -> list[dict[str, float]]:
        c = [{"projectedValue": 0.0} for _ in range(11)]
        c[10] = {"projectedValue": pv}
        return c

    ahead = fs.compute_goal_assessment(
        base_profile,
        curve_at_goal(1_100_000.0),
        fire_target,
        real_return=real_ret,
    )
    assert ahead is not None
    assert ahead["computedBeyondProjectionHorizon"] is False
    assert ahead["status"] == "ahead"
    assert ahead["gapAmount"] == pytest.approx(-100_000.0)

    on_track = fs.compute_goal_assessment(
        base_profile,
        curve_at_goal(970_000.0),
        fire_target,
        real_return=real_ret,
    )
    assert on_track is not None
    assert on_track["status"] == "on_track"

    behind = fs.compute_goal_assessment(
        base_profile,
        curve_at_goal(800_000.0),
        fire_target,
        real_return=real_ret,
    )
    assert behind is not None
    assert behind["status"] == "behind"
    assert behind["gapAmount"] == pytest.approx(200_000.0)


def test_compute_goal_assessment_current_savings_rate() -> None:
    profile = {
        "current_age": 30,
        "target_retirement_age": 40,
        "annual_income": 200_000,
        "annual_expenses": 50_000,
        "current_net_worth": 0.0,
    }
    curve = [{"projectedValue": 0.0} for _ in range(11)]
    curve[10] = {"projectedValue": 1.0}
    out = fs.compute_goal_assessment(profile, curve, fire_target=2.0, real_return=0.0)
    assert out is not None
    assert out["computedBeyondProjectionHorizon"] is False
    assert out["currentSavingsRate"] == pytest.approx(0.75)


def test_required_savings_rate_binary_search_flat_return() -> None:
    # 10 years, r=0, start 0: need 5k/yr to reach 50k; income 100k -> 5%.
    rate = fs._required_annual_savings_rate(
        net_worth=0.0,
        annual_income=100_000.0,
        real_return=0.0,
        years_to_goal=10,
        regular_fire_target=50_000.0,
    )
    assert rate == pytest.approx(0.05, abs=1e-4)


def test_compute_goal_assessment_extrapolates_when_goal_past_curve() -> None:
    # Curve has 5 points; goal at +10 years still gets an assessment via _value_at_horizon.
    profile = {
        "current_age": 30,
        "target_retirement_age": 40,
        "annual_income": 100_000,
        "annual_expenses": 50_000,
        "current_net_worth": 0.0,
    }
    short_curve = [{"projectedValue": float(i)} for i in range(5)]
    out = fs.compute_goal_assessment(
        profile, short_curve, fire_target=1.0, real_return=0.0
    )
    assert out is not None
    assert out["computedBeyondProjectionHorizon"] is True
    # 10 years × 50k savings, r=0
    assert out["gapAmount"] == pytest.approx(1.0 - 500_000.0)
    assert out["status"] == "ahead"
