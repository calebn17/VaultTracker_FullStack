"""Integration tests for /api/v1/households (TestClient)."""

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.database import get_db
from app.dependencies import get_current_user
from app.main import app
from app.models.household_invite_code import HouseholdInviteCode
from app.models.household_membership import HouseholdMembership
from app.models.user import User


def _bind_client_user(app, db_session, user: User) -> None:
    def override_get_db():
        yield db_session

    def override_get_current_user():
        return user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user


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
    """Other user has no household until they join."""
    assert client.post("/api/v1/households").status_code == 201

    other = User(firebase_id="isolated-user")
    db_session.add(other)
    db_session.commit()
    db_session.refresh(other)

    _bind_client_user(app, db_session, other)
    try:
        with TestClient(app) as alt_client:
            r = alt_client.get("/api/v1/households/me")
            assert r.status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_post_invite_codes_requires_household(client, test_user, db_session):
    r = client.post("/api/v1/households/invite-codes")
    assert r.status_code == 404


def test_invite_code_flow_second_user_joins(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    assert inv.status_code == 200
    payload = inv.json()
    assert "code" in payload
    assert len(payload["code"]) == 8
    assert "expiresAt" in payload

    user_b = User(firebase_id="join-flow-user-b")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    _bind_client_user(app, db_session, user_b)
    try:
        with TestClient(app) as alt:
            jr = alt.post("/api/v1/households/join", json={"code": payload["code"]})
            assert jr.status_code == 200
            data = jr.json()
            assert len(data["members"]) == 2
            ids = [m["userId"] for m in data["members"]]
            assert test_user.id in ids
            assert user_b.id in ids
    finally:
        app.dependency_overrides.clear()


def test_join_normalizes_code_case_and_whitespace(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]
    spaced = f"  {code[:4]}  {code[4:]} "

    user_b = User(firebase_id="join-case-user")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    _bind_client_user(app, db_session, user_b)
    try:
        with TestClient(app) as alt:
            jr = alt.post("/api/v1/households/join", json={"code": spaced.lower()})
            assert jr.status_code == 200
    finally:
        app.dependency_overrides.clear()


def test_join_invalid_code_returns_400(client, test_user, db_session):
    user_b = User(firebase_id="bad-code-user")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    _bind_client_user(app, db_session, user_b)
    try:
        with TestClient(app) as alt:
            r = alt.post("/api/v1/households/join", json={"code": "ZZZZZZZZ"})
            assert r.status_code == 400
            assert r.json()["detail"] == "Invalid or expired invite code"
    finally:
        app.dependency_overrides.clear()


def test_post_invite_codes_when_household_full_returns_409(
    client, test_user, db_session
):
    create = client.post("/api/v1/households")
    assert create.status_code == 201
    hid = create.json()["id"]
    user_b = User(firebase_id="full-household-b")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)
    db_session.add(HouseholdMembership(household_id=hid, user_id=user_b.id))
    db_session.commit()

    r = client.post("/api/v1/households/invite-codes")
    assert r.status_code == 409
    assert r.json()["detail"] == "Household is full"


def test_join_rejects_expired_code(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]
    row = (
        db_session.query(HouseholdInviteCode)
        .filter(HouseholdInviteCode.code == code)
        .one()
    )
    row.expires_at = datetime.now(timezone.utc) - timedelta(seconds=60)
    db_session.commit()

    user_b = User(firebase_id="expired-code-user")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    _bind_client_user(app, db_session, user_b)
    try:
        with TestClient(app) as alt:
            r = alt.post("/api/v1/households/join", json={"code": code})
            assert r.status_code == 400
    finally:
        app.dependency_overrides.clear()


def test_join_rejects_reused_code(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]

    user_b = User(firebase_id="reuse-b")
    user_c = User(firebase_id="reuse-c")
    db_session.add_all([user_b, user_c])
    db_session.commit()
    for u in (user_b, user_c):
        db_session.refresh(u)

    _bind_client_user(app, db_session, user_b)
    try:
        with TestClient(app) as alt_b:
            first = alt_b.post("/api/v1/households/join", json={"code": code})
            assert first.status_code == 200
    finally:
        app.dependency_overrides.clear()

    _bind_client_user(app, db_session, user_c)
    try:
        with TestClient(app) as alt_c:
            r = alt_c.post("/api/v1/households/join", json={"code": code})
            assert r.status_code == 400
    finally:
        app.dependency_overrides.clear()


def test_join_when_already_in_household_returns_409(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]

    user_b = User(firebase_id="double-join-user")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    _bind_client_user(app, db_session, user_b)
    try:
        with TestClient(app) as alt:
            first = alt.post("/api/v1/households/join", json={"code": code})
            assert first.status_code == 200
            r = alt.post("/api/v1/households/join", json={"code": code})
            assert r.status_code == 409
            assert r.json()["detail"] == "Already a member of a household"
    finally:
        app.dependency_overrides.clear()


def test_join_when_household_already_two_members_returns_409(
    client, test_user, db_session
):
    """Valid code but room was filled without consuming this code (stale edge)."""
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]
    hid = client.get("/api/v1/households/me").json()["id"]

    user_b = User(firebase_id="two-member-edge-b")
    user_c = User(firebase_id="two-member-edge-c")
    db_session.add_all([user_b, user_c])
    db_session.commit()
    db_session.refresh(user_b)
    db_session.refresh(user_c)

    db_session.add(HouseholdMembership(household_id=hid, user_id=user_b.id))
    db_session.commit()

    _bind_client_user(app, db_session, user_c)
    try:
        with TestClient(app) as alt:
            r = alt.post("/api/v1/households/join", json={"code": code})
            assert r.status_code == 409
            assert r.json()["detail"] == "Household is full"
    finally:
        app.dependency_overrides.clear()
