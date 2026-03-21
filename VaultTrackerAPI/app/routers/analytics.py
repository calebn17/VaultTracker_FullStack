from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.analytics import AnalyticsResponse
from app.services.analytics_service import AnalyticsService
from app.services.cache_service import cache

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("", response_model=AnalyticsResponse)
def get_analytics(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cache_key = f"analytics:{user.id}"
    cached = cache.get(cache_key)
    if cached is not None:
        return AnalyticsResponse.model_validate(cached)
    service = AnalyticsService()
    payload = service.get_analytics(user, db)
    body = AnalyticsResponse.model_validate(payload)
    cache.set(cache_key, body.model_dump(mode="python"))
    return body
