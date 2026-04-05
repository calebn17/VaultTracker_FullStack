"""
Assets router (/api/v1/assets).

Manages the asset records (crypto, stocks, cash, realEstate, retirement) that
transactions are posted against. Assets are typically created ahead of the first
transaction via POST /assets; subsequent transactions update quantity and
current_value in place rather than creating new rows. Supports optional category
filtering via query parameter.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.asset import Asset
from app.models.user import User
from app.schemas.asset import AssetCreate, AssetResponse

router = APIRouter(prefix="/assets", tags=["Assets"])


@router.get("", response_model=list[AssetResponse])
async def get_assets(
    category: str | None = Query(
        None,
        description="Filter by category (crypto, stocks, cash, realEstate, retirement)",
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get all assets for the current user, optionally filtered by category."""
    query = db.query(Asset).filter(Asset.user_id == current_user.id)

    if category:
        query = query.filter(Asset.category == category)

    return query.all()


@router.post("", response_model=AssetResponse, status_code=status.HTTP_201_CREATED)
async def create_asset(
    asset: AssetCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new asset."""
    db_asset = Asset(
        user_id=current_user.id,
        name=asset.name,
        symbol=asset.symbol,
        category=asset.category,
        quantity=asset.quantity,
        current_value=asset.current_value,
    )
    db.add(db_asset)
    db.commit()
    db.refresh(db_asset)
    return db_asset


@router.get("/{asset_id}", response_model=AssetResponse)
async def get_asset(
    asset_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a specific asset by ID."""
    asset = (
        db.query(Asset)
        .filter(Asset.id == asset_id, Asset.user_id == current_user.id)
        .first()
    )

    if not asset:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Asset not found"
        )
    return asset
