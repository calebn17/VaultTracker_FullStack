"""
Test harness: in-memory SQLite (shared via StaticPool), dependency overrides for auth/DB.

Patches `app.database` engine before `app.main` is imported so lifespan `create_all` hits
the same database sessions use.
"""

from __future__ import annotations

import os

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.database as db
from app.database import Base, get_db

_test_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_test_session_local = sessionmaker(autocommit=False, autoflush=False, bind=_test_engine)
db.engine = _test_engine
db.SessionLocal = _test_session_local

from app.dependencies import get_current_user  # noqa: E402
from app.main import app  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.cache_service import cache  # noqa: E402


def _clear_caches() -> None:
    cache._data.clear()
    cache._crypto_prices.clear()
    cache._stock_prices.clear()


@pytest.fixture(autouse=True)
def _reset_database_and_cache() -> None:
    Base.metadata.drop_all(bind=_test_engine)
    Base.metadata.create_all(bind=_test_engine)
    _clear_caches()
    yield


def _vt_break_tests_enabled() -> bool:
    return os.environ.get("VT_BREAK_TESTS", "").strip().lower() in ("1", "true", "yes")


@pytest.fixture(autouse=True)
def _vt_inject_broken_behavior_for_falsification_checks(monkeypatch: pytest.MonkeyPatch) -> None:
    """
    Opt-in regression alarm: prove tests actually assert real behavior.

    Run:
        VT_BREAK_TESTS=1 pytest tests/ -q
    Expect many failures. If the suite still passes, tests are not exercising
    those code paths (or the break targets moved — update this fixture).

    Normal CI / local runs omit the env var so behavior stays unchanged.
    """
    if not _vt_break_tests_enabled():
        yield
        return

    def empty_aggregate(snapshots, period):  # noqa: ARG001 — deliberate wrong impl
        return []

    monkeypatch.setattr(
        "app.routers.networth._aggregate_snapshots",
        empty_aggregate,
    )

    def broken_smart_create(self, data, user, db):  # noqa: ARG002
        raise RuntimeError("VT_BREAK_TESTS: intentional regression injection")

    monkeypatch.setattr(
        "app.services.transaction_service.TransactionService.smart_create",
        broken_smart_create,
    )

    def broken_smart_update(self, transaction_id, data, user, db):  # noqa: ARG002
        raise RuntimeError("VT_BREAK_TESTS: intentional regression injection")

    monkeypatch.setattr(
        "app.services.transaction_service.TransactionService.smart_update",
        broken_smart_update,
    )
    yield


@pytest.fixture
def db_session():
    session = _test_session_local()
    yield session
    session.close()


@pytest.fixture
def test_user(db_session):
    user = User(firebase_id="test-firebase")
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def client(db_session, test_user):
    def override_get_db():
        yield db_session

    def override_get_current_user():
        return test_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    from fastapi.testclient import TestClient

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()
