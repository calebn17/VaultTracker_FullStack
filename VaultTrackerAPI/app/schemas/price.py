from pydantic import BaseModel


class PriceLookupResponse(BaseModel):
    symbol: str
    price: float
    source: str
