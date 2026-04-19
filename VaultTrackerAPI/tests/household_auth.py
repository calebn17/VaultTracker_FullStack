"""TestClient auth override: act as another User, then restore (e.g. test_user)."""

from __future__ import annotations

from contextlib import contextmanager

from fastapi import FastAPI
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User


@contextmanager
def auth_as_user(
    app: FastAPI, db_session: Session, acting_user: User, restore_user: User
):
    """
    Temporarily set dependency overrides to `acting_user`, then restore `restore_user`.

    Avoid ``dependency_overrides.clear()``; it removes the client fixture overrides.
    """

    def override_get_db():
        yield db_session

    def override_acting():
        return acting_user

    def override_restore():
        return restore_user

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_acting
    try:
        yield
    finally:
        app.dependency_overrides[get_db] = override_get_db
        app.dependency_overrides[get_current_user] = override_restore
