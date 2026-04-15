"""
Rate limiting (SlowAPI): tiered limits, key function, 429 shape, headers, exemptions.
"""

from __future__ import annotations

import base64
import json

import pytest
from starlette.requests import Request

from app.config import settings
from app.rate_limit import (
    _decode_jwt_subject,
    get_rate_limit_key,
    reset_rate_limit_storage,
)


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _jwt_for_sub(sub: str) -> str:
    payload = {"sub": sub, "aud": "vaulttracker-test"}
    return "h." + _b64url(json.dumps(payload).encode()) + ".s"


def test_decode_jwt_subject_extracts_sub() -> None:
    payload = {"sub": "firebase-uid-1", "aud": "x"}
    token = "aa." + _b64url(json.dumps(payload).encode()) + ".sig"
    assert _decode_jwt_subject(token) == "firebase-uid-1"


def test_decode_jwt_subject_malformed_returns_none() -> None:
    assert _decode_jwt_subject("not-a-jwt") is None
    assert _decode_jwt_subject("a.b") is None


def test_get_rate_limit_key_debug_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "debug_auth_enabled", True)
    scope = {
        "type": "http",
        "headers": [(b"authorization", b"Bearer vaulttracker-debug-user")],
        "client": ("127.0.0.1", 1234),
    }
    req = Request(scope)
    assert get_rate_limit_key(req) == "user:debug-user"


def test_get_rate_limit_key_jwt_sub(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "debug_auth_enabled", False)
    payload = {"sub": "uid-xyz"}
    tok = "h." + _b64url(json.dumps(payload).encode()) + ".s"
    scope = {
        "type": "http",
        "headers": [(b"authorization", f"Bearer {tok}".encode())],
        "client": ("127.0.0.1", 1234),
    }
    assert get_rate_limit_key(Request(scope)) == "user:uid-xyz"


def test_get_rate_limit_key_no_auth_uses_client_ip() -> None:
    scope = {"type": "http", "headers": [], "client": ("192.168.1.9", 0)}
    key = get_rate_limit_key(Request(scope))
    assert "192.168.1.9" in key or key == "192.168.1.9"


def test_read_endpoint_429_after_exceeding_limit(
    client, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setattr(settings, "rate_limit_read", "2/second")
    r1 = client.get("/api/v1/accounts")
    r2 = client.get("/api/v1/accounts")
    r3 = client.get("/api/v1/accounts")
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r3.status_code == 429
    assert r3.json() == {
        "detail": "Rate limit exceeded. Please slow down and try again later."
    }
    assert "Retry-After" in r3.headers


def test_write_not_blocked_when_read_exhausted(
    client, monkeypatch: pytest.MonkeyPatch, db_session
):
    monkeypatch.setattr(settings, "rate_limit_read", "1/second")
    monkeypatch.setattr(settings, "rate_limit_write", "30/second")
    assert client.get("/api/v1/accounts").status_code == 200
    assert client.get("/api/v1/accounts").status_code == 429
    r = client.post(
        "/api/v1/accounts",
        json={"name": "A", "account_type": "brokerage"},
    )
    assert r.status_code == 201


@pytest.fixture
def mock_price_apis(monkeypatch: pytest.MonkeyPatch):
    async def fake_crypto(self, symbol: str, *, use_cache: bool = True):
        return 1.0 if symbol.upper() == "BTC" else None

    async def fake_stock(self, symbol: str, *, use_cache: bool = True):
        return None

    monkeypatch.setattr(
        "app.services.price_service.PriceService.get_crypto_price",
        fake_crypto,
    )
    monkeypatch.setattr(
        "app.services.price_service.PriceService.get_stock_price",
        fake_stock,
    )


def test_external_tier_stricter_than_read(
    client, monkeypatch: pytest.MonkeyPatch, mock_price_apis
):
    monkeypatch.setattr(settings, "rate_limit_read", "100/second")
    monkeypatch.setattr(settings, "rate_limit_external", "2/second")
    assert client.get("/api/v1/accounts").status_code == 200
    assert client.get("/api/v1/prices/BTC").status_code == 200
    assert client.get("/api/v1/prices/BTC").status_code == 200
    assert client.get("/api/v1/prices/BTC").status_code == 429


def test_success_includes_rate_limit_headers(client, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(settings, "rate_limit_read", "10/second")
    r = client.get("/api/v1/accounts")
    assert r.status_code == 200
    assert r.headers.get("X-RateLimit-Limit")
    assert r.headers.get("X-RateLimit-Remaining") is not None
    assert r.headers.get("X-RateLimit-Reset")


def test_root_and_health_exempt_from_rate_limit(
    client, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setattr(settings, "rate_limit_read", "1/second")
    for _ in range(5):
        assert client.get("/").status_code == 200
        assert client.get("/health").status_code == 200


def test_rate_limit_storage_reset_allows_requests_again(
    client, monkeypatch: pytest.MonkeyPatch, db_session
):
    """In-memory counters clear between tests; reset also clears mid-test buckets."""
    monkeypatch.setattr(settings, "rate_limit_read", "1/second")
    assert client.get("/api/v1/accounts").status_code == 200
    assert client.get("/api/v1/accounts").status_code == 429
    reset_rate_limit_storage()
    assert client.get("/api/v1/accounts").status_code == 200


def test_per_user_isolation_with_distinct_jwt_subs(
    client, monkeypatch: pytest.MonkeyPatch
):
    monkeypatch.setattr(settings, "rate_limit_read", "1/second")

    user_a = {"Authorization": f"Bearer {_jwt_for_sub('user-a')}"}
    user_b = {"Authorization": f"Bearer {_jwt_for_sub('user-b')}"}

    assert client.get("/api/v1/accounts", headers=user_a).status_code == 200
    assert client.get("/api/v1/accounts", headers=user_a).status_code == 429
    assert client.get("/api/v1/accounts", headers=user_b).status_code == 200
