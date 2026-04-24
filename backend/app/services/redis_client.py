from __future__ import annotations

from typing import Any

from app.core.config import settings


_redis_client: Any | None = None
_redis_client_initialized = False


def _load_async_redis_class():
    try:
        from upstash_redis.asyncio import Redis
    except ImportError:
        return None
    return Redis


def build_redis_client(
    *,
    backend: str | None = None,
    url: str | None = None,
    token: str | None = None,
    redis_cls: type[Any] | None = None,
) -> Any | None:
    selected_backend = (backend or settings.REALTIME_STORE_BACKEND).strip().lower()
    if selected_backend != "redis":
        return None

    redis_url = url if url is not None else settings.UPSTASH_REDIS_REST_URL
    redis_token = token if token is not None else settings.UPSTASH_REDIS_REST_TOKEN
    if not redis_url or not redis_token:
        return None

    client_class = redis_cls or _load_async_redis_class()
    if client_class is None:
        return None

    return client_class(url=redis_url, token=redis_token)


def get_redis_client() -> Any | None:
    global _redis_client
    global _redis_client_initialized

    if not _redis_client_initialized:
        _redis_client = build_redis_client()
        _redis_client_initialized = True

    return _redis_client
