"""Data models for parsed rows, API payloads, import results, and archive manifests."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

# Mirrored from VaultTrackerAPI/app/schemas (must stay in sync for smart import).
TransactionSide = Literal["buy", "sell"]
AssetCategory = Literal["crypto", "stocks", "cash", "realEstate", "retirement"]
AccountType = Literal["cryptoExchange", "brokerage", "bank", "retirement", "other"]

_SYMBOL_CATEGORIES = frozenset({"crypto", "stocks", "retirement"})


class RawParsedRow(BaseModel):
    """Loose row shape from CSV or vision extraction before normalization."""

    model_config = ConfigDict(extra="ignore")

    asset_name: str | None = None
    symbol: str | None = None
    category: str | None = None
    quantity: float | None = None
    price_per_unit: float | None = None
    transaction_type: str | None = None
    account_name: str | None = None
    account_type: str | None = None
    date: str | datetime | None = None


class SmartTransactionPayload(BaseModel):
    """JSON body for ``POST /api/v1/transactions/smart`` (SmartTransactionCreate)."""

    transaction_type: TransactionSide
    category: AssetCategory
    asset_name: str = Field(max_length=200)
    symbol: str | None = Field(default=None, max_length=20)
    quantity: float = Field(gt=0)
    price_per_unit: float = Field(gt=0)
    account_name: str = Field(max_length=200)
    account_type: AccountType
    date: datetime | None = None

    @field_validator("transaction_type", mode="before")
    @classmethod
    def transaction_type_lower(cls, v: object) -> object:
        if isinstance(v, str):
            return v.lower()
        return v

    @model_validator(mode="after")
    def symbol_when_needed(self) -> SmartTransactionPayload:
        if self.category in _SYMBOL_CATEGORIES:
            if not (self.symbol and self.symbol.strip()):
                raise ValueError(f"symbol is required for category {self.category!r}")
        return self


class ValidationErrorDetail(BaseModel):
    """One validation failure for a payload at a given index in a batch."""

    index: int
    field: str
    reason: str


class ImportInserted(BaseModel):
    """One successful smart transaction insert (see scanner design manifest)."""

    payload_index: int
    id: str
    asset: str
    account: str


class ImportFailed(BaseModel):
    """One failed import attempt."""

    payload_index: int
    error: str


class ImportBatchResult(BaseModel):
    """Aggregated result of posting a batch of smart payloads."""

    inserted: list[ImportInserted] = Field(default_factory=list)
    failed: list[ImportFailed] = Field(default_factory=list)


class ArchiveManifestEntry(BaseModel):
    """Single source file row inside archive manifest.json."""

    source: str
    payload: str
    format: str
    transactions_inserted: int
    record_ids: list[str]


class ArchiveManifest(BaseModel):
    """Top-level manifest written under processed/<timestamp>/."""

    timestamp: datetime
    files: list[ArchiveManifestEntry]
