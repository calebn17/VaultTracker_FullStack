"""Tests for import_smart_payloads (mocked HTTP)."""

from __future__ import annotations

import json
from urllib.error import URLError

from vaulttracker_scanner.import_payloads import (
    import_smart_payloads,
    smart_transactions_url,
)


def _minimal_crypto_payload() -> dict:
    return {
        "transaction_type": "buy",
        "category": "crypto",
        "asset_name": "Bitcoin",
        "symbol": "BTC",
        "quantity": 0.5,
        "price_per_unit": 50_000.0,
        "account_name": "Coinbase",
        "account_type": "cryptoExchange",
        "date": "2024-01-15T10:30:00Z",
    }


def test_dry_run_does_not_call_post() -> None:
    called: list[int] = []

    def post_fn(*args, **kwargs):
        called.append(1)
        return 201, b"{}"

    payloads = [_minimal_crypto_payload()]
    result = import_smart_payloads(payloads, dry_run=True, post_fn=post_fn)
    assert called == []
    assert len(result.inserted) == 1
    assert result.inserted[0].id == "dry-run:0"
    assert result.inserted[0].asset == "Bitcoin"
    assert result.failed == []


def test_success_uses_bearer_and_base_url() -> None:
    calls: list[tuple[str, bytes, dict[str, str], float]] = []

    def post_fn(url, body, headers, timeout_sec):
        calls.append((url, body, headers, timeout_sec))
        return 201, json.dumps({"id": "txn-abc"}).encode()

    result = import_smart_payloads(
        [_minimal_crypto_payload()],
        base_url="https://example.test:9999/",
        bearer_token="my-secret-token",
        post_fn=post_fn,
    )
    assert len(result.inserted) == 1
    assert result.inserted[0].id == "txn-abc"
    assert result.failed == []

    url, body, headers, timeout_sec = calls[0]
    assert url == smart_transactions_url("https://example.test:9999/")
    assert headers["Authorization"] == "Bearer my-secret-token"
    assert headers["Content-Type"] == "application/json"
    assert json.loads(body.decode())["symbol"] == "BTC"
    assert timeout_sec == 60.0


def test_422_failure_continues_batch() -> None:
    n = 0

    def post_fn(url, body, headers, timeout_sec):
        nonlocal n
        n += 1
        if n == 1:
            return 201, json.dumps({"id": "ok-1"}).encode()
        return 422, json.dumps(
            {"detail": [{"loc": ["body", "quantity"], "msg": "positive"}]},
        ).encode()

    result = import_smart_payloads(
        [_minimal_crypto_payload(), _minimal_crypto_payload()],
        post_fn=post_fn,
    )
    assert len(result.inserted) == 1
    assert result.inserted[0].payload_index == 0
    assert len(result.failed) == 1
    assert result.failed[0].payload_index == 1
    assert "422" in result.failed[0].error
    assert "quantity" in result.failed[0].error


def test_500_failure() -> None:
    def post_fn(url, body, headers, timeout_sec):
        return 500, b"Internal Server Error"

    result = import_smart_payloads([_minimal_crypto_payload()], post_fn=post_fn)
    assert result.inserted == []
    assert len(result.failed) == 1
    assert "500" in result.failed[0].error


def test_network_urlerror() -> None:
    def post_fn(url, body, headers, timeout_sec):
        raise URLError("connection refused")

    result = import_smart_payloads([_minimal_crypto_payload()], post_fn=post_fn)
    assert result.inserted == []
    assert len(result.failed) == 1
    assert "network error" in result.failed[0].error.lower()


def test_201_invalid_json_fails() -> None:
    def post_fn(url, body, headers, timeout_sec):
        return 201, b"not-json"

    result = import_smart_payloads([_minimal_crypto_payload()], post_fn=post_fn)
    assert result.inserted == []
    assert "invalid JSON" in result.failed[0].error


def test_201_missing_id_fails() -> None:
    def post_fn(url, body, headers, timeout_sec):
        return 201, json.dumps({"transaction_type": "buy"}).encode()

    result = import_smart_payloads([_minimal_crypto_payload()], post_fn=post_fn)
    assert result.inserted == []
    assert "missing id" in result.failed[0].error
