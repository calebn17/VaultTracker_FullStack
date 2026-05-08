"""POST validated smart transaction payloads to the VaultTracker API (batch)."""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from vaulttracker_scanner.models import ImportBatchResult, ImportFailed, ImportInserted

DEFAULT_BASE_URL = "http://localhost:8000"
DEFAULT_BEARER_TOKEN = "vaulttracker-debug-user"
SMART_PATH = "/api/v1/transactions/smart"

# (url, body_bytes, headers, timeout_sec) -> (status_code, response_bytes)
PostFn = Callable[[str, bytes, dict[str, str], float], tuple[int, bytes]]


def smart_transactions_url(base_url: str) -> str:
    return f"{base_url.rstrip('/')}{SMART_PATH}"


def _serialize_payload(payload: Mapping[str, Any]) -> bytes:
    return json.dumps(dict(payload), default=str, ensure_ascii=False).encode("utf-8")


def _format_error(status: int, raw: bytes) -> str:
    text = raw.decode(errors="replace") if raw else ""
    try:
        data: object = json.loads(text) if text else {}
    except json.JSONDecodeError:
        return f"HTTP {status}: {text[:800]}"
    if isinstance(data, dict) and "detail" in data:
        return f"HTTP {status}: {data['detail']}"
    return f"HTTP {status}: {data}"


def _http_post(
    url: str, body: bytes, headers: dict[str, str], timeout: float
) -> tuple[int, bytes]:
    req = Request(url, data=body, method="POST", headers=headers)
    try:
        with urlopen(req, timeout=timeout) as resp:
            code = resp.getcode()
            return (code if code is not None else 200), resp.read()
    except HTTPError as e:
        return e.code, e.read()


def import_smart_payloads(
    payloads: list[Mapping[str, Any]],
    *,
    base_url: str = DEFAULT_BASE_URL,
    bearer_token: str = DEFAULT_BEARER_TOKEN,
    dry_run: bool = False,
    timeout_sec: float = 60.0,
    post_fn: PostFn | None = None,
) -> ImportBatchResult:
    """POST each payload to ``POST /api/v1/transactions/smart``.

    Continues after failures. ``asset`` / ``account`` on successes are taken from
    the request payload names (the API response does not echo them).

    Args:
        payloads: JSON-ready dicts (e.g. from ``validate_smart_payloads``).
        base_url: API origin (no trailing slash required).
        bearer_token: ``Authorization: Bearer …`` value.
        dry_run: If True, no HTTP calls; returns synthetic ``dry-run:{i}`` ids.
        timeout_sec: Per-request socket timeout.
        post_fn: Inject for tests (defaults to :func:`_http_post`).
    """
    poster = post_fn or _http_post
    url = smart_transactions_url(base_url)
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": f"Bearer {bearer_token}",
    }

    inserted: list[ImportInserted] = []
    failed: list[ImportFailed] = []

    for index, payload in enumerate(payloads):
        if dry_run:
            inserted.append(
                ImportInserted(
                    payload_index=index,
                    id=f"dry-run:{index}",
                    asset=str(payload.get("asset_name", "")),
                    account=str(payload.get("account_name", "")),
                ),
            )
            continue

        body = _serialize_payload(payload)
        try:
            status, raw = poster(url, body, headers, timeout_sec)
        except (URLError, TimeoutError, OSError, RuntimeError) as exc:
            failed.append(
                ImportFailed(payload_index=index, error=f"network error: {exc}"),
            )
            continue

        if status == 201:
            try:
                data = json.loads(raw.decode()) if raw else {}
            except json.JSONDecodeError:
                failed.append(
                    ImportFailed(
                        payload_index=index,
                        error=f"HTTP {status}: invalid JSON in response",
                    ),
                )
                continue
            tid = data.get("id") if isinstance(data, dict) else None
            if not tid:
                failed.append(
                    ImportFailed(
                        payload_index=index,
                        error=f"HTTP {status}: missing id in response",
                    ),
                )
                continue
            inserted.append(
                ImportInserted(
                    payload_index=index,
                    id=str(tid),
                    asset=str(payload.get("asset_name", "")),
                    account=str(payload.get("account_name", "")),
                ),
            )
        else:
            failed.append(
                ImportFailed(
                    payload_index=index,
                    error=_format_error(status, raw),
                ),
            )

    return ImportBatchResult(inserted=inserted, failed=failed)
