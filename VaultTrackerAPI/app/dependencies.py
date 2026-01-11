from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User


async def get_current_user(
    authorization: str = Header(..., description="Bearer token (Firebase JWT or mock user ID)"),
    db: Session = Depends(get_db)
) -> User:
    """
    Mock authentication dependency.

    For now, expects header format: "Bearer <firebase_id>"
    In production, this would verify a Firebase JWT and extract the user ID.

    Creates a new user if one doesn't exist for the given firebase_id.
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Expected 'Bearer <token>'"
        )

    firebase_id = authorization[7:]  # Remove "Bearer " prefix

    if not firebase_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No token provided"
        )

    # Look up or create user
    user = db.query(User).filter(User.firebase_id == firebase_id).first()

    if not user:
        # Auto-create user on first access (as per PRD)
        user = User(firebase_id=firebase_id)
        db.add(user)
        db.commit()
        db.refresh(user)

    return user
