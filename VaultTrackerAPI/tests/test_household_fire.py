"""Integration tests for GET/PUT /api/v1/households/me/fire-profile."""

from fastapi.testclient import TestClient

from app.main import app
from app.models.household_fire_profile import HouseholdFIREProfile
from app.models.household_membership import HouseholdMembership
from app.models.user import User
from tests.household_auth import auth_as_user


def test_household_fire_profile_requires_household(client, test_user, db_session):
    r = client.get("/api/v1/households/me/fire-profile")
    assert r.status_code == 404
    assert r.json()["detail"] == "Not a member of a household"


def test_get_household_fire_profile_creates_defaults(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    r = client.get("/api/v1/households/me/fire-profile")
    assert r.status_code == 200
    data = r.json()
    assert data["currentAge"] == 30
    assert data["annualIncome"] == 0.0
    assert data["annualExpenses"] == 0.0
    assert data["targetRetirementAge"] is None
    assert "id" in data
    assert "createdAt" in data
    assert "updatedAt" in data


def test_put_household_fire_profile_round_trip(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    body = {
        "currentAge": 40,
        "annualIncome": 120000.0,
        "annualExpenses": 60000.0,
        "targetRetirementAge": 55,
    }
    r = client.put("/api/v1/households/me/fire-profile", json=body)
    assert r.status_code == 200
    data = r.json()
    assert data["currentAge"] == 40
    assert data["annualIncome"] == 120000.0
    assert data["annualExpenses"] == 60000.0
    assert data["targetRetirementAge"] == 55

    g = client.get("/api/v1/households/me/fire-profile")
    assert g.status_code == 200
    assert g.json() == data


def test_second_member_sees_same_household_fire_profile(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    assert inv.status_code == 200
    code = inv.json()["code"]

    other = User(firebase_id="household-fire-peer")
    db_session.add(other)
    db_session.commit()
    db_session.refresh(other)

    with auth_as_user(app, db_session, other, test_user):
        peer = TestClient(app)
        assert (
            peer.post("/api/v1/households/join", json={"code": code}).status_code == 200
        )
        body = {
            "currentAge": 35,
            "annualIncome": 90000.0,
            "annualExpenses": 45000.0,
            "targetRetirementAge": 60,
        }
        assert (
            peer.put("/api/v1/households/me/fire-profile", json=body).status_code == 200
        )

    r = client.get("/api/v1/households/me/fire-profile")
    assert r.status_code == 200
    assert r.json()["currentAge"] == 35
    assert r.json()["targetRetirementAge"] == 60


def test_leave_household_deletes_fire_profile_row(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    assert client.get("/api/v1/households/me/fire-profile").status_code == 200

    hid = (
        db_session.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == test_user.id)
        .one()
        .household_id
    )
    assert (
        db_session.query(HouseholdFIREProfile)
        .filter(HouseholdFIREProfile.household_id == hid)
        .count()
        == 1
    )

    assert client.delete("/api/v1/households/me/membership").status_code == 204
    assert (
        db_session.query(HouseholdFIREProfile)
        .filter(HouseholdFIREProfile.household_id == hid)
        .count()
        == 0
    )
