from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.user import User

# Well-known token sent by iOS debug builds.  Must match AuthTokenProvider.debugToken.
_DEBUG_AUTH_TOKEN = "vaulttracker-debug-user"
# Stable firebase_id used for the debug user row in the database.
_DEBUG_FIREBASE_ID = "debug-user"


async def get_current_user(
    authorization: str = Header(..., description="Bearer token (Firebase JWT)"),
    db: Session = Depends(get_db)
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
            detail="Invalid authorization header format. Expected 'Bearer <token>'"
        )

    token = authorization[7:]  # strip "Bearer "

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No token provided"
        )

    # --- Debug bypass (local development only) ---
    if settings.debug_auth_enabled and token == _DEBUG_AUTH_TOKEN:
        firebase_id = _DEBUG_FIREBASE_ID
    else:
        # TODO: verify Firebase JWT and extract uid
        # For now the raw token string is used as the firebase_id.
        firebase_id = token

    # Look up or auto-create user
    user = db.query(User).filter(User.firebase_id == firebase_id).first()
    if not user:
        user = User(firebase_id=firebase_id)
        db.add(user)
        db.commit()
        db.refresh(user)

    return user
