"""
FastAPI dependency for extracting the authenticated user from a Bearer token.

Every protected route injects `get_current_user` via `Depends(get_current_user)`.
It strips the Bearer prefix, resolves a firebase_id, then looks up or auto-creates
the corresponding User row so new Firebase users are provisioned transparently.

Debug bypass: when `DEBUG_AUTH_ENABLED=true` in `.env` and the token equals the
well-known value `"vaulttracker-debug-user"`, `firebase_id` is set to `"debug-user"`
(the `_DEBUG_FIREBASE_ID` constant) without any real Firebase verification. This
matches the `AuthTokenProvider.debugToken` constant in the iOS client and allows
local development without a Firebase account.

Production: set `FIREBASE_CREDENTIALS_PATH` to a service account JSON file.
Non-debug Bearer tokens are verified with Firebase Admin and the uid becomes
firebase_id.
"""

from __future__ import annotations

import os
import threading

import firebase_admin
from fastapi import Depends, Header, HTTPException, status
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.household import Household
from app.models.household_membership import HouseholdMembership
from app.models.user import User

# Well-known token sent by iOS debug builds.  Must match AuthTokenProvider.debugToken.
_DEBUG_AUTH_TOKEN = "vaulttracker-debug-user"
# Stable firebase_id used for the debug user row in the database.
_DEBUG_FIREBASE_ID = "debug-user"

_firebase_lock = threading.Lock()
_firebase_initialized = False


def _ensure_firebase_app() -> None:
    """Initialize the default Firebase app once (thread-safe)."""
    global _firebase_initialized
    if _firebase_initialized:
        return
    path = (settings.firebase_credentials_path or "").strip()
    if not path:
        raise RuntimeError("FIREBASE_CREDENTIALS_PATH is not set")
    if not os.path.isfile(path):
        raise RuntimeError(f"Firebase credentials file not found: {path}")
    with _firebase_lock:
        if _firebase_initialized:
            return
        cred = credentials.Certificate(path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True


async def get_current_user(
    authorization: str = Header(..., description="Bearer token (Firebase JWT)"),
    db: Session = Depends(get_db),
) -> User:
    """
    Authentication dependency.

    Extracts the firebase_id from the Bearer token, then looks up (or auto-creates)
    the corresponding User row.

    Debug bypass: when DEBUG_AUTH_ENABLED=true in .env and the token equals the
    well-known debug token, a fixed firebase_id is used so the debug user is always
    the same database row regardless of restarts.
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Expected 'Bearer <token>'",
        )

    token = authorization[7:]  # strip "Bearer "

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No token provided",
        )

    if settings.debug_auth_enabled and token == _DEBUG_AUTH_TOKEN:
        firebase_id = _DEBUG_FIREBASE_ID
    else:
        try:
            _ensure_firebase_app()
        except RuntimeError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication service unavailable",
            ) from e
        try:
            decoded = firebase_auth.verify_id_token(token)
            firebase_id = decoded["uid"]
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
            ) from None

    user = db.query(User).filter(User.firebase_id == firebase_id).first()
    if not user:
        user = User(firebase_id=firebase_id)
        db.add(user)
        db.commit()
        db.refresh(user)

    return user


async def get_current_household(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> Household | None:
    """
    Resolve the household the current user belongs to, if any.

    Each user has at most one membership row (``user_id`` is unique).
    """
    membership = (
        db.query(HouseholdMembership)
        .filter(HouseholdMembership.user_id == current_user.id)
        .first()
    )
    if membership is None:
        return None
    household = (
        db.query(Household).filter(Household.id == membership.household_id).first()
    )
    return household


async def require_current_household(
    household: Household | None = Depends(get_current_household),
) -> Household:
    """Same as get_current_household but returns 404 when the user has no household."""
    if household is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Not a member of a household",
        )
    return household
