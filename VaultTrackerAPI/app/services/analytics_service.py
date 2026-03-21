"""
Portfolio analytics: allocation by category and simple performance from transaction history.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.asset import Asset
from app.models.transaction import Transaction
from app.models.user import User


class AnalyticsService:
    def get_analytics(self, user: User, db: Session) -> dict:
        assets = db.query(Asset).filter(Asset.user_id == user.id).all()
        total = sum(a.current_value or 0.0 for a in assets)

        allocation: dict = {}
        for category in ("crypto", "stocks", "cash", "realEstate", "retirement"):
            cat_assets = [a for a in assets if a.category == category]
            value = sum(a.current_value or 0.0 for a in cat_assets)
            allocation[category] = {
                "value": round(value, 2),
                "percentage": round((value / total * 100) if total > 0 else 0, 1),
            }

        transactions = db.query(Transaction).filter(Transaction.user_id == user.id).all()
        total_invested = sum(
            t.quantity * t.price_per_unit for t in transactions if t.transaction_type == "buy"
        )
        total_sold = sum(
            t.quantity * t.price_per_unit for t in transactions if t.transaction_type == "sell"
        )
        cost_basis = total_invested - total_sold
        gain_loss = total - cost_basis

        return {
            "allocation": allocation,
            "performance": {
                "totalGainLoss": round(gain_loss, 2),
                "totalGainLossPercent": round(
                    (gain_loss / cost_basis * 100) if cost_basis > 0 else 0, 1
                ),
                "costBasis": round(cost_basis, 2),
                "currentValue": round(total, 2),
            },
        }
