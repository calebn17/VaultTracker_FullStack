from pydantic import BaseModel


class GroupedHolding(BaseModel):
    id: str
    name: str
    symbol: str | None = None
    quantity: float
    current_value: float


class CategoryTotals(BaseModel):
    crypto: float = 0.0
    stocks: float = 0.0
    cash: float = 0.0
    realEstate: float = 0.0
    retirement: float = 0.0


class DashboardResponse(BaseModel):
    totalNetWorth: float
    categoryTotals: CategoryTotals
    groupedHoldings: dict[str, list[GroupedHolding]]
