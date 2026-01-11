from datetime import datetime
from pydantic import BaseModel


class NetWorthSnapshotResponse(BaseModel):
    date: datetime
    value: float

    class Config:
        from_attributes = True


class NetWorthHistoryResponse(BaseModel):
    snapshots: list[NetWorthSnapshotResponse]
