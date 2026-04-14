"""
SlowAPI rate limiting: per-user keys from Authorization (no token verification),
with IP fallback. See VaultTrackerAPI/Documentation/2026-04-13-rate-limiting-design.md.
"""

from __future__ import annotations

import base64
import functools
import inspect
import json
import logging
import time
from typing import Any, Callable

from fastapi.encoders import jsonable_encoder
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.config import settings

logger = logging.getLogger(__name__)

# Must match app.dependencies debug bypass token (iOS AuthTokenProvider.debugToken).
_DEBUG_AUTH_TOKEN = "vaulttracker-debug-user"
_DEBUG_RATE_LIMIT_KEY = "user:debug-user"


def _decode_jwt_subject(token: str) -> str | None:
    """Base64url-decode JWT payload segment and return ``sub`` (no verification)."""
    parts = token.split(".")
    if len(parts) != 3:
        return None
    payload_b64 = parts[1]
    pad = (-len(payload_b64)) % 4
    if pad:
        payload_b64 += "=" * pad
    try:
        raw = base64.urlsafe_b64decode(payload_b64.encode("ascii"))
        data = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    sub = data.get("sub")
    if isinstance(sub, str) and sub:
        return sub
    return None


def get_rate_limit_key(request: Request) -> str:
    auth = request.headers.get("Authorization") or ""
    if not auth.startswith("Bearer "):
        return get_remote_address(request)
    token = auth[7:].strip()
    if not token:
        return get_remote_address(request)
    if settings.debug_auth_enabled and token == _DEBUG_AUTH_TOKEN:
        return _DEBUG_RATE_LIMIT_KEY
    sub = _decode_jwt_subject(token)
    if sub:
        return f"user:{sub}"
    return get_remote_address(request)


limiter = Limiter(
    key_func=get_rate_limit_key,
    storage_uri="memory://",
    headers_enabled=True,
)


def rate_limit_read() -> str:
    return settings.rate_limit_read


def rate_limit_write() -> str:
    return settings.rate_limit_write


def rate_limit_external() -> str:
    return settings.rate_limit_external


def coerce_json_response(
    func: Callable[..., Any] | None = None,
    *,
    json_status_code: int | None = None,
) -> Callable[..., Any]:
    """
    SlowAPI injects headers only when the handler returns a Response. FastAPI
    normally accepts dict/list/ORM and serializes later — wrap so SlowAPI sees
    JSONResponse first (see slowapi extension async_wrapper).

    For routes that declare ``status_code=201`` on the router, pass
    ``json_status_code=201`` so the JSON body keeps the correct status (the
    router default is not applied when returning JSONResponse directly).
    """

    def decorator(fn: Callable[..., Any]) -> Callable[..., Any]:
        if inspect.iscoroutinefunction(fn):

            @functools.wraps(fn)
            async def async_inner(*args: Any, **kwargs: Any) -> Response:
                result = await fn(*args, **kwargs)
                return _coerce_to_response(result, json_status_code)

            return async_inner

        @functools.wraps(fn)
        def sync_inner(*args: Any, **kwargs: Any) -> Response:
            result = fn(*args, **kwargs)
            return _coerce_to_response(result, json_status_code)

        return sync_inner

    if func is not None:
        return decorator(func)
    return decorator


def _coerce_to_response(result: Any, json_status_code: int | None) -> Response:
    if result is None:
        return Response(status_code=204)
    if isinstance(result, Response):
        return result
    status = 200 if json_status_code is None else json_status_code
    return JSONResponse(content=jsonable_encoder(result), status_code=status)


def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> Response:
    logger.warning("Rate limit exceeded: %s", exc.detail)
    response = JSONResponse(
        status_code=429,
        content={
            "detail": "Rate limit exceeded. Please slow down and try again later.",
        },
    )
    current_limit = getattr(request.state, "view_rate_limit", None)
    if current_limit is not None:
        try:
            reset_at, _remaining = request.app.state.limiter.limiter.get_window_stats(
                current_limit[0], *current_limit[1]
            )
            retry_after = max(0, int((1 + reset_at) - time.time()))
            response.headers["Retry-After"] = str(retry_after)
        except Exception:
            # Keep the 429 body even if rate-limit metadata cannot be computed.
            pass
    return response


def reset_rate_limit_storage() -> None:
    """Clear in-memory counters between tests."""
    limiter.reset()
