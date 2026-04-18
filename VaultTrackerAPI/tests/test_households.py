"""Integration tests for /api/v1/households (TestClient)."""

from fastapi.testclient import TestClient

from app.database import get_db
from app.dependencies import get_current_user
from app.main import app
from app.models.household_membership import HouseholdMembership
from app.models.user import User


def test_get_household_me_not_in_household_returns_404(client, test_user, db_session):
    r = client.get("/api/v1/households/me")
    assert r.status_code == 404
    assert r.json()["detail"] == "Not a member of a household"


def test_post_household_creates_and_returns_one_member(client, test_user, db_session):
    r = client.post("/api/v1/households")
    assert r.status_code == 201
    data = r.json()
    assert "id" in data
    assert "createdAt" in data
    assert len(data["members"]) == 1
    assert data["members"][0]["userId"] == test_user.id
    assert data["members"][0]["email"] == test_user.email


def test_get_household_me_after_create(client, test_user, db_session):
    create = client.post("/api/v1/households")
    assert create.status_code == 201
    hid = create.json()["id"]

    r = client.get("/api/v1/households/me")
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == hid
    assert len(data["members"]) == 1
    assert data["members"][0]["userId"] == test_user.id


def test_post_household_twice_returns_409(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    r = client.post("/api/v1/households")
    assert r.status_code == 409
    assert r.json()["detail"] == "Already a member of a household"


def test_members_ordered_by_join_time(client, test_user, db_session):
    create = client.post("/api/v1/households")
    assert create.status_code == 201
    hid = create.json()["id"]

    user_b = User(firebase_id="test-firebase-member-b")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)
    db_session.add(
        HouseholdMembership(household_id=hid, user_id=user_b.id),
    )
    db_session.commit()

    r = client.get("/api/v1/households/me")
    assert r.status_code == 200
    ids = [m["userId"] for m in r.json()["members"]]
    assert ids == [test_user.id, user_b.id]


def test_alternate_user_sees_no_household_until_join_flow(
    client, test_user, db_session
):
    """Other user has no household until join (separate todo)."""
    assert client.post("/api/v1/households").status_code == 201

    other = User(firebase_id="isolated-user")
    db_session.add(other)
    db_session.commit()
    db_session.refresh(other)

    def override_get_db():
        yield db_session

    def override_get_current_user():
        return other

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user
    try:
        with TestClient(app) as alt_client:
            r = alt_client.get("/api/v1/households/me")
            assert r.status_code == 404
    finally:
        app.dependency_overrides.clear()
