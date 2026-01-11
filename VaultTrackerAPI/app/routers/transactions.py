from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.asset import Asset
from app.models.account import Account
from app.models.transaction import Transaction
from app.schemas.transaction import TransactionCreate, TransactionUpdate, TransactionResponse

router = APIRouter(prefix="/transactions", tags=["Transactions"])


def update_asset_from_transaction(
    db: Session,
    asset: Asset,
    transaction_type: str,
    quantity: float,
    price_per_unit: float,
    is_reversal: bool = False
):
    """Update asset quantity and value based on a transaction."""
    if is_reversal:
        # Reverse the effect of the transaction
        if transaction_type == "buy":
            asset.quantity -= quantity
        else:  # sell
            asset.quantity += quantity
    else:
        # Apply the transaction
        if transaction_type == "buy":
            asset.quantity += quantity
        else:  # sell
            asset.quantity -= quantity

    # Update current value (quantity * latest price per unit)
    asset.current_value = asset.quantity * price_per_unit
    asset.last_updated = datetime.utcnow()


@router.get("", response_model=list[TransactionResponse])
async def get_transactions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all transactions for the current user."""
    return db.query(Transaction).filter(Transaction.user_id == current_user.id).all()


@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    transaction: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new transaction.
    This will automatically update the related asset's quantity and value.
    """
    # Verify asset exists and belongs to user
    asset = db.query(Asset).filter(
        Asset.id == transaction.asset_id,
        Asset.user_id == current_user.id
    ).first()

    if not asset:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Asset not found"
        )

    # Verify account exists and belongs to user
    account = db.query(Account).filter(
        Account.id == transaction.account_id,
        Account.user_id == current_user.id
    ).first()

    if not account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found"
        )

    # Create transaction
    db_transaction = Transaction(
        user_id=current_user.id,
        asset_id=transaction.asset_id,
        account_id=transaction.account_id,
        transaction_type=transaction.transaction_type,
        quantity=transaction.quantity,
        price_per_unit=transaction.price_per_unit,
        date=transaction.date or datetime.utcnow(),
    )
    db.add(db_transaction)

    # Update the asset
    update_asset_from_transaction(
        db, asset,
        transaction.transaction_type,
        transaction.quantity,
        transaction.price_per_unit
    )

    db.commit()
    db.refresh(db_transaction)
    return db_transaction


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific transaction by ID."""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found"
        )
    return transaction


@router.put("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: str,
    transaction_update: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update an existing transaction."""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found"
        )

    # Get the associated asset
    asset = db.query(Asset).filter(Asset.id == transaction.asset_id).first()

    # Reverse the old transaction effect
    update_asset_from_transaction(
        db, asset,
        transaction.transaction_type,
        transaction.quantity,
        transaction.price_per_unit,
        is_reversal=True
    )

    # Apply updates
    update_data = transaction_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(transaction, field, value)

    # Apply the new transaction effect
    update_asset_from_transaction(
        db, asset,
        transaction.transaction_type,
        transaction.quantity,
        transaction.price_per_unit
    )

    db.commit()
    db.refresh(transaction)
    return transaction


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a transaction and reverse its effect on the asset."""
    transaction = db.query(Transaction).filter(
        Transaction.id == transaction_id,
        Transaction.user_id == current_user.id
    ).first()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found"
        )

    # Get the associated asset and reverse the transaction effect
    asset = db.query(Asset).filter(Asset.id == transaction.asset_id).first()
    if asset:
        update_asset_from_transaction(
            db, asset,
            transaction.transaction_type,
            transaction.quantity,
            transaction.price_per_unit,
            is_reversal=True
        )

    db.delete(transaction)
    db.commit()
