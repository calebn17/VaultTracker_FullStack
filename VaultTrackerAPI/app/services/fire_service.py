"""
FIRE calculator pure math (constants + projection helpers).

Orchestration (DB profile, dashboard aggregate, response assembly) lives in
later layers; this module stays side-effect free for unit tests.
"""

from __future__ import annotations

from typing import Any, TypedDict

DEFAULT_RETURNS: dict[str, float] = {
    "crypto": 0.10,
    "stocks": 0.08,
    "realEstate": 0.05,
    "cash": 0.02,
    "retirement": 0.07,
}
DEFAULT_INFLATION = 0.03
FIRE_MULTIPLIER = 25
LEAN_FIRE_EXPENSE_RATIO = 0.7
FAT_FIRE_EXPENSE_RATIO = 1.5
PROJECTION_YEARS = 30

# When there is no allocation (empty portfolio), spec §3 edge case.
DEFAULT_EMPTY_PORTFOLIO_NOMINAL_RETURN = 0.07


class _GoalProfile(TypedDict, total=False):
    current_age: int
    target_retirement_age: int | None
    annual_income: float
    annual_expenses: float
    current_net_worth: float


def compute_blended_return(
    category_allocations: dict[str, dict[str, float]],
) -> tuple[float, float]:
    """
    Weighted nominal return from category percentages (0–100 scale), then real
    return = nominal - DEFAULT_INFLATION. Empty or all-zero allocation uses
    DEFAULT_EMPTY_PORTFOLIO_NOMINAL_RETURN.
    """
    if not category_allocations:
        nominal = DEFAULT_EMPTY_PORTFOLIO_NOMINAL_RETURN
        return (nominal, nominal - DEFAULT_INFLATION)

    total_pct = sum(
        float(v.get("percentage", 0.0)) for v in category_allocations.values()
    )
    if total_pct < 1e-9:
        nominal = DEFAULT_EMPTY_PORTFOLIO_NOMINAL_RETURN
        return (nominal, nominal - DEFAULT_INFLATION)

    nominal = 0.0
    for category, slice_ in category_allocations.items():
        r = DEFAULT_RETURNS.get(category)
        if r is None:
            continue
        pct = float(slice_.get("percentage", 0.0))
        nominal += (pct / 100.0) * r

    return (nominal, nominal - DEFAULT_INFLATION)


def compute_fire_targets(annual_expenses: float) -> dict[str, dict[str, float]]:
    """Lean / Regular / Fat FIRE dollar targets (amounts only)."""
    return {
        "leanFire": {
            "targetAmount": annual_expenses * LEAN_FIRE_EXPENSE_RATIO * FIRE_MULTIPLIER,
        },
        "fire": {"targetAmount": annual_expenses * FIRE_MULTIPLIER},
        "fatFire": {
            "targetAmount": annual_expenses * FAT_FIRE_EXPENSE_RATIO * FIRE_MULTIPLIER,
        },
    }


def generate_projection_curve(
    net_worth: float,
    annual_savings: float,
    real_return: float,
    *,
    years: int = PROJECTION_YEARS,
) -> list[dict[str, float]]:
    """
    Year 0 = net_worth; each following year applies real return then adds savings.
    Length is years + 1 (indices 0 .. years).
    """
    out: list[dict[str, float]] = []
    v = net_worth
    for i in range(years + 1):
        out.append({"projectedValue": v})
        if i < years:
            v = v * (1.0 + real_return) + annual_savings
    return out


def find_crossover_year(
    curve: list[dict[str, float]],
    target_amount: float,
) -> int | None:
    """First index where projectedValue >= target_amount, or None."""
    for i, point in enumerate(curve):
        if point["projectedValue"] >= target_amount:
            return i
    return None


def _value_at_horizon(
    net_worth: float,
    annual_savings: float,
    real_return: float,
    years: int,
) -> float:
    v = net_worth
    for _ in range(years):
        v = v * (1.0 + real_return) + annual_savings
    return v


def _required_annual_savings_rate(
    *,
    net_worth: float,
    annual_income: float,
    real_return: float,
    years_to_goal: int,
    regular_fire_target: float,
) -> float:
    """
    Minimum annual savings (as a fraction of income) so that after years_to_goal
    discrete steps, portfolio >= regular_fire_target. Binary search on dollars;
    stop when bracket width < $1.
    """
    if annual_income <= 0:
        return 0.0

    def end_value(annual_savings: float) -> float:
        return _value_at_horizon(net_worth, annual_savings, real_return, years_to_goal)

    if end_value(0.0) >= regular_fire_target:
        return 0.0
    if end_value(annual_income) < regular_fire_target:
        return 1.0

    low, high = 0.0, annual_income
    while high - low >= 1.0:
        mid = (low + high) / 2.0
        if end_value(mid) >= regular_fire_target:
            high = mid
        else:
            low = mid

    return high / annual_income


def _goal_status(projected: float, target: float) -> str:
    if projected > target:
        return "ahead"
    if projected >= 0.95 * target:
        return "on_track"
    return "behind"


def compute_goal_assessment(
    profile: _GoalProfile,
    curve: list[dict[str, float]],
    fire_target: float,
    *,
    real_return: float,
) -> dict[str, Any] | None:
    """
    Compare projected value at goal age to Regular FIRE target; binary-search
    required savings rate.

    None when target_retirement_age is missing or goal age is in the past.

    If goal age is beyond the supplied projection curve, projected wealth uses
    the same discrete model as the curve (_value_at_horizon); callers should
    surface ``computedBeyondProjectionHorizon`` to the client.
    """
    tra = profile.get("target_retirement_age")
    if tra is None:
        return None

    current_age = int(profile["current_age"])
    annual_income = float(profile["annual_income"])
    annual_expenses = float(profile["annual_expenses"])
    net_worth = float(profile.get("current_net_worth", 0.0))
    annual_savings = annual_income - annual_expenses

    years_to_goal = tra - current_age
    if years_to_goal < 0:
        return None

    if years_to_goal < len(curve):
        projected = curve[years_to_goal]["projectedValue"]
        beyond_chart = False
    else:
        projected = _value_at_horizon(
            net_worth, annual_savings, real_return, years_to_goal
        )
        beyond_chart = True

    gap_amount = fire_target - projected
    status = _goal_status(projected, fire_target)

    current_rate = annual_savings / annual_income if annual_income > 0 else 0.0

    required_rate = _required_annual_savings_rate(
        net_worth=net_worth,
        annual_income=annual_income,
        real_return=real_return,
        years_to_goal=years_to_goal,
        regular_fire_target=fire_target,
    )

    return {
        "targetAge": tra,
        "requiredSavingsRate": required_rate,
        "currentSavingsRate": current_rate,
        "status": status,
        "gapAmount": gap_amount,
        "computedBeyondProjectionHorizon": beyond_chart,
    }
