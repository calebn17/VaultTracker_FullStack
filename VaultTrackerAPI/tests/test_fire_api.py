"""Integration tests for /api/v1/fire (TestClient)."""

import pytest

from app.models.asset import Asset


def test_get_fire_profile_creates_defaults_when_missing(client, test_user, db_session):
    r = client.get("/api/v1/fire/profile")
    assert r.status_code == 200
    data = r.json()
    assert data["currentAge"] == 30
    assert data["annualIncome"] == 0
    assert data["annualExpenses"] == 0
    assert data["targetRetirementAge"] is None
    assert "id" in data


def test_delete_user_data_removes_fire_profile(client, test_user, db_session):
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 33,
            "annualIncome": 90_000,
            "annualExpenses": 45_000,
            "targetRetirementAge": 55,
        },
    )
    assert client.get("/api/v1/fire/profile").status_code == 200

    r_del = client.delete("/api/v1/users/me/data")
    assert r_del.status_code == 204

    r = client.get("/api/v1/fire/profile")
    assert r.status_code == 200
    reset = r.json()
    assert reset["currentAge"] == 30
    assert reset["annualIncome"] == 0
    assert reset["annualExpenses"] == 0
    assert reset["targetRetirementAge"] is None


def test_put_get_fire_profile_round_trip(client, test_user, db_session):
    body = {
        "currentAge": 35,
        "annualIncome": 120_000,
        "annualExpenses": 55_000,
        "targetRetirementAge": 55,
    }
    r1 = client.put("/api/v1/fire/profile", json=body)
    assert r1.status_code == 200, r1.text
    data = r1.json()
    assert data["currentAge"] == 35
    assert data["annualIncome"] == 120_000
    assert data["targetRetirementAge"] == 55
    assert "id" in data

    r2 = client.get("/api/v1/fire/profile")
    assert r2.status_code == 200
    assert r2.json()["id"] == data["id"]


def test_put_fire_profile_updates_existing(client, test_user, db_session):
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 30,
            "annualIncome": 80_000,
            "annualExpenses": 50_000,
            "targetRetirementAge": 50,
        },
    )
    r = client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 31,
            "annualIncome": 85_000,
            "annualExpenses": 50_000,
            "targetRetirementAge": 51,
        },
    )
    assert r.status_code == 200
    assert r.json()["currentAge"] == 31


def test_put_fire_profile_validation_error(client, test_user, db_session):
    r = client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 40,
            "annualIncome": 100_000,
            "annualExpenses": 60_000,
            "targetRetirementAge": 40,
        },
    )
    assert r.status_code == 422


def test_get_projection_creates_profile_when_missing(client, test_user, db_session):
    r = client.get("/api/v1/fire/projection")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "unreachable"
    assert body["unreachableReason"] == "non_positive_savings"
    assert body["inputs"]["currentAge"] == 30
    assert body["inputs"]["annualIncome"] == 0
    assert body["inputs"]["annualExpenses"] == 0
    # No holdings: empty-portfolio default return still shown for the form label.
    assert body["allocation"] is None
    assert body["blendedReturn"] == pytest.approx(0.07)
    assert body["realBlendedReturn"] == pytest.approx(0.04)
    assert body["inflationRate"] == pytest.approx(0.03)


def test_fire_projection_unreachable_non_positive_savings(
    client, test_user, db_session
):
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 40,
            "annualIncome": 50_000,
            "annualExpenses": 55_000,
            "targetRetirementAge": None,
        },
    )
    r = client.get("/api/v1/fire/projection")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "unreachable"
    assert body["unreachableReason"] == "non_positive_savings"
    assert body["projectionCurve"] == []
    assert body["monthlyBreakdown"]["monthsToFire"] is None
    assert body["goalAssessment"] is None
    assert body["allocation"] is None
    assert body["blendedReturn"] == pytest.approx(0.07)


def test_fire_projection_unreachable_still_shows_blend_with_holdings(
    client, test_user, db_session
):
    """Non-positive savings hides the chart but portfolio mix + return still show."""
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 35,
            "annualIncome": 40_000,
            "annualExpenses": 50_000,
            "targetRetirementAge": None,
        },
    )
    db_session.add(
        Asset(
            user_id=test_user.id,
            name="Test",
            symbol="TST",
            category="stocks",
            quantity=1.0,
            current_value=100_000.0,
        )
    )
    db_session.commit()

    r = client.get("/api/v1/fire/projection")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "unreachable"
    assert body["allocation"] is not None
    assert body["allocation"]["stocks"]["percentage"] == pytest.approx(100.0)
    assert body["blendedReturn"] == pytest.approx(0.08)
    assert body["realBlendedReturn"] == pytest.approx(0.05)
    assert body["inputs"]["currentNetWorth"] == pytest.approx(100_000.0)


def test_fire_projection_beyond_horizon(client, test_user, db_session):
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 28,
            "annualIncome": 35_000,
            "annualExpenses": 33_000,
            "targetRetirementAge": None,
        },
    )
    r = client.get("/api/v1/fire/projection")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "beyond_horizon"
    assert body["unreachableReason"] is None
    assert len(body["projectionCurve"]) == 31
    assert body["monthlyBreakdown"]["monthsToFire"] is None
    assert body["goalAssessment"] is None
    for tier in (
        body["fireTargets"]["leanFire"],
        body["fireTargets"]["fire"],
        body["fireTargets"]["fatFire"],
    ):
        assert tier["yearsToTarget"] is None
        assert tier["targetAge"] is None


def test_fire_projection_beyond_horizon_goal_assessment_extrapolated(
    client, test_user, db_session
):
    # Goal age beyond PROJECTION_YEARS window: still return goalAssessment + flag.
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 28,
            "annualIncome": 35_000,
            "annualExpenses": 33_000,
            "targetRetirementAge": 65,
        },
    )
    r = client.get("/api/v1/fire/projection")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "beyond_horizon"
    ga = body["goalAssessment"]
    assert ga is not None
    assert ga["targetAge"] == 65
    assert ga["computedBeyondProjectionHorizon"] is True


def test_fire_projection_reachable_when_already_over_regular_target(
    client, test_user, db_session
):
    client.put(
        "/api/v1/fire/profile",
        json={
            "currentAge": 45,
            "annualIncome": 200_000,
            "annualExpenses": 40_000,
            "targetRetirementAge": 60,
        },
    )
    db_session.add(
        Asset(
            user_id=test_user.id,
            name="Big",
            symbol="BIG",
            category="stocks",
            quantity=1.0,
            current_value=5_000_000.0,
        )
    )
    db_session.commit()

    r = client.get("/api/v1/fire/projection")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "reachable"
    assert body["fireTargets"]["fire"]["yearsToTarget"] == 0
    assert body["fireTargets"]["fire"]["targetAge"] == 45
    assert body["monthlyBreakdown"]["monthsToFire"] == 0
    assert body["allocation"] is not None
    assert body["blendedReturn"] is not None
    assert body["goalAssessment"] is not None
