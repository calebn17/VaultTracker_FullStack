"""GET /api/v1/dashboard/household integration tests."""

from fastapi.testclient import TestClient

from app.main import app
from app.models.user import User
from app.services.cache_service import cache
from tests.household_auth import auth_as_user


def test_dashboard_household_404_when_not_in_household(client, test_user, db_session):
    r = client.get("/api/v1/dashboard/household")
    assert r.status_code == 404
    assert r.json()["detail"] == "Not a member of a household"


def test_dashboard_household_merges_two_members(client, test_user, db_session):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]

    user_b = User(firebase_id="dash-hh-user-b")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    with auth_as_user(app, db_session, user_b, test_user):
        with TestClient(app) as alt:
            assert (
                alt.post("/api/v1/households/join", json={"code": code}).status_code
                == 200
            )

    client.post(
        "/api/v1/transactions/smart",
        json={
            "transaction_type": "buy",
            "category": "crypto",
            "asset_name": "Bitcoin",
            "symbol": "BTC",
            "quantity": 1.0,
            "price_per_unit": 100.0,
            "account_name": "Ex",
            "account_type": "cryptoExchange",
        },
    )

    with auth_as_user(app, db_session, user_b, test_user):
        with TestClient(app) as alt:
            alt.post(
                "/api/v1/transactions/smart",
                json={
                    "transaction_type": "buy",
                    "category": "cash",
                    "asset_name": "Savings",
                    "symbol": None,
                    "quantity": 1.0,
                    "price_per_unit": 40.0,
                    "account_name": "Bank",
                    "account_type": "bank",
                },
            )

    r = client.get("/api/v1/dashboard/household")
    assert r.status_code == 200
    body = r.json()
    assert body["totalNetWorth"] == 140.0
    assert body["categoryTotals"]["crypto"] == 100.0
    assert body["categoryTotals"]["cash"] == 40.0
    assert len(body["members"]) == 2
    by_uid = {m["userId"]: m for m in body["members"]}
    assert by_uid[test_user.id]["totalNetWorth"] == 100.0
    assert by_uid[user_b.id]["totalNetWorth"] == 40.0


def test_household_dashboard_cache_invalidates_on_member_write(
    client, test_user, db_session
):
    assert client.post("/api/v1/households").status_code == 201
    hid = client.get("/api/v1/households/me").json()["id"]
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]

    user_b = User(firebase_id="dash-cache-user-b")
    db_session.add(user_b)
    db_session.commit()
    db_session.refresh(user_b)

    with auth_as_user(app, db_session, user_b, test_user):
        with TestClient(app) as alt:
            assert (
                alt.post("/api/v1/households/join", json={"code": code}).status_code
                == 200
            )

    hk = f"dashboard:household:{hid}"
    assert cache.get(hk) is None
    assert client.get("/api/v1/dashboard/household").status_code == 200
    assert cache.get(hk) is not None

    client.post(
        "/api/v1/transactions/smart",
        json={
            "transaction_type": "buy",
            "category": "stocks",
            "asset_name": "Apple",
            "symbol": "AAPL",
            "quantity": 1.0,
            "price_per_unit": 5.0,
            "account_name": "Broker",
            "account_type": "brokerage",
        },
    )
    assert cache.get(hk) is None
