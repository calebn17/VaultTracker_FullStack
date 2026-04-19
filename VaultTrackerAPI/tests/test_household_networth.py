"""Household net worth snapshots and GET /networth/history/household."""

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.main import app
from app.models.asset import Asset
from app.models.household import Household
from app.models.household_membership import HouseholdMembership
from app.models.household_networth_snapshot import HouseholdNetWorthSnapshot
from app.models.user import User
from app.services.asset_sync import record_networth_snapshot
from tests.household_auth import auth_as_user


def test_record_networth_snapshot_writes_household_snapshot(db_session):
    u1 = User(firebase_id="hnw-u1")
    u2 = User(firebase_id="hnw-u2")
    db_session.add_all([u1, u2])
    db_session.commit()
    db_session.refresh(u1)
    db_session.refresh(u2)

    h = Household()
    db_session.add(h)
    db_session.flush()
    db_session.add_all(
        [
            HouseholdMembership(household_id=h.id, user_id=u1.id),
            HouseholdMembership(household_id=h.id, user_id=u2.id),
        ]
    )
    db_session.add_all(
        [
            Asset(
                user_id=u1.id,
                name="A",
                symbol="A",
                category="stocks",
                quantity=1.0,
                current_value=100.0,
            ),
            Asset(
                user_id=u2.id,
                name="B",
                symbol=None,
                category="cash",
                quantity=1.0,
                current_value=40.0,
            ),
        ]
    )
    db_session.commit()

    when = datetime(2025, 6, 1, 12, 0, tzinfo=timezone.utc)
    record_networth_snapshot(db_session, u1.id, snapshot_at=when)
    db_session.commit()

    rows = (
        db_session.query(HouseholdNetWorthSnapshot)
        .filter(HouseholdNetWorthSnapshot.household_id == h.id)
        .all()
    )
    assert len(rows) == 1
    assert rows[0].value == 140.0
    d = rows[0].date
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    assert d == when


def test_record_networth_snapshot_upserts_same_timestamp(db_session):
    u1 = User(firebase_id="hnw-upsert")
    db_session.add(u1)
    db_session.commit()
    db_session.refresh(u1)
    h = Household()
    db_session.add(h)
    db_session.flush()
    db_session.add(HouseholdMembership(household_id=h.id, user_id=u1.id))
    db_session.add(
        Asset(
            user_id=u1.id,
            name="A",
            symbol="A",
            category="stocks",
            quantity=1.0,
            current_value=10.0,
        )
    )
    db_session.commit()

    when = datetime(2025, 6, 2, 15, 0, tzinfo=timezone.utc)
    record_networth_snapshot(db_session, u1.id, snapshot_at=when)
    db_session.commit()
    record_networth_snapshot(db_session, u1.id, snapshot_at=when)
    db_session.commit()

    rows = (
        db_session.query(HouseholdNetWorthSnapshot)
        .filter(HouseholdNetWorthSnapshot.household_id == h.id)
        .all()
    )
    assert len(rows) == 1


def test_record_networth_snapshot_no_household_skips_household_row(db_session):
    u = User(firebase_id="hnw-solo")
    db_session.add(u)
    db_session.commit()
    db_session.refresh(u)
    db_session.add(
        Asset(
            user_id=u.id,
            name="A",
            symbol="A",
            category="stocks",
            quantity=1.0,
            current_value=5.0,
        )
    )
    db_session.commit()
    record_networth_snapshot(db_session, u.id)
    db_session.commit()
    assert db_session.query(HouseholdNetWorthSnapshot).count() == 0


def test_networth_history_household_404_when_not_in_household(client, test_user):
    r = client.get("/api/v1/networth/history/household")
    assert r.status_code == 404


def test_networth_history_household_returns_combined_series(
    client, test_user, db_session
):
    assert client.post("/api/v1/households").status_code == 201
    inv = client.post("/api/v1/households/invite-codes")
    code = inv.json()["code"]

    user_b = User(firebase_id="hnw-api-b")
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
            "price_per_unit": 50.0,
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
                    "asset_name": "C",
                    "symbol": None,
                    "quantity": 1.0,
                    "price_per_unit": 25.0,
                    "account_name": "Bank",
                    "account_type": "bank",
                },
            )

    r = client.get("/api/v1/networth/history/household", params={"period": "all"})
    assert r.status_code == 200
    snaps = r.json()["snapshots"]
    assert len(snaps) >= 1
    assert snaps[-1]["value"] == 75.0
