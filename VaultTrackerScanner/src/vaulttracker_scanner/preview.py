"""Human-readable preview of normalized payloads and validation errors."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime
from typing import Any

from vaulttracker_scanner.models import ValidationErrorDetail


def _fmt_num(x: Any) -> str:
    if x is None:
        return ""
    try:
        value = float(x)
    except (TypeError, ValueError):
        return str(x)
    if value == int(value):
        return str(int(value))
    text = f"{value:.10f}".rstrip("0").rstrip(".")
    return text if text else "0"


def _fmt_date(payload: Mapping[str, Any]) -> str:
    value = payload.get("date")
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.date().isoformat()
    text = str(value)
    return text[:10] if len(text) >= 10 else text


def format_preview_table(
    normalized: list[Mapping[str, Any]],
    validation_errors: list[ValidationErrorDetail],
) -> str:
    """Build a markdown-style table of *all* normalized rows plus an error summary."""
    lines = [
        "| # | Asset | Symbol | Qty | Price | Account | Type | Date |",
        "|---|-------|--------|-----|-------|---------|------|------|",
    ]
    for i, payload in enumerate(normalized):
        sym = payload.get("symbol") or ""
        row_fmt = (
            "| {idx} | {asset} | {sym} | {qty} | {price} | {acct} | {typ} | {dt} |"
        )
        lines.append(
            row_fmt.format(
                idx=i + 1,
                asset=payload.get("asset_name", ""),
                sym=sym,
                qty=_fmt_num(payload.get("quantity")),
                price=_fmt_num(payload.get("price_per_unit")),
                acct=payload.get("account_name", ""),
                typ=payload.get("transaction_type", ""),
                dt=_fmt_date(payload),
            ),
        )

    if validation_errors:
        lines.append("")
        lines.append("Validation errors:")
        for err in validation_errors:
            lines.append(f"  [{err.index}] {err.field}: {err.reason}")

    return "\n".join(lines)
