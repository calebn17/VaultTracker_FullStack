"""Validate normalized dicts against the smart transaction API contract."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from pydantic import ValidationError

from vaulttracker_scanner.models import SmartTransactionPayload, ValidationErrorDetail


def validate_smart_payloads_indexed(
    payloads: list[Mapping[str, Any]],
) -> tuple[list[tuple[int, dict[str, Any]]], list[ValidationErrorDetail]]:
    """Like :func:`validate_smart_payloads` but keeps global indices on valid rows."""
    valid: list[tuple[int, dict[str, Any]]] = []
    errors: list[ValidationErrorDetail] = []

    for index, raw in enumerate(payloads):
        try:
            model = SmartTransactionPayload.model_validate(raw)
            valid.append((index, model.model_dump(mode="json")))
        except ValidationError as exc:
            for err in exc.errors():
                loc = err.get("loc", ())
                field = ".".join(str(part) for part in loc) if loc else "payload"
                msg = str(err.get("msg", "validation error"))
                errors.append(
                    ValidationErrorDetail(index=index, field=field, reason=msg),
                )

    return valid, errors


def validate_smart_payloads(
    payloads: list[Mapping[str, Any]],
) -> tuple[list[dict[str, Any]], list[ValidationErrorDetail]]:
    """Validate API-ready dicts.

    Returns JSON-serializable valid rows and per-field errors.

    Each input entry corresponds to an index in the batch. One Pydantic error may yield
    multiple ``ValidationErrorDetail`` rows (e.g. missing symbol + invalid enum).
    """
    indexed, errors = validate_smart_payloads_indexed(payloads)
    return [p for _, p in indexed], errors


def validation_result_as_dict(
    valid: list[dict[str, Any]],
    errors: list[ValidationErrorDetail],
) -> dict[str, Any]:
    """Shape matching Documentation/Plans/2026-05-02-scanner-design.md validate step."""
    return {
        "valid": valid,
        "errors": [e.model_dump() for e in errors],
    }
