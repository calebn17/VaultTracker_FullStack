from pydantic import BaseModel


class AllocationEntry(BaseModel):
    value: float
    percentage: float


class PerformanceBlock(BaseModel):
    totalGainLoss: float
    totalGainLossPercent: float
    costBasis: float
    currentValue: float


class AnalyticsResponse(BaseModel):
    allocation: dict[str, AllocationEntry]
    performance: PerformanceBlock
