import base64
import hashlib
import hmac
import json
import time
from typing import Any

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import ApiError, forbidden, unauthorized
from app.core.config import settings
from app.core.messages import Messages
from app.db.database import get_db_session
from app.models.user import User, UserRole
from app.services.user_service import ensure_user_not_suspended, get_user_by_id

bearer_scheme = HTTPBearer(auto_error=False)


def _base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")


def _base64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def create_access_token(
    user: User,
    expires_minutes: int | None = None,
    session_id: str | None = None,
) -> str:
    ttl_minutes = expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    active_session_id = session_id or _session_id_from_refresh_token(
        getattr(user, "refresh_token", None)
    )
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(user.id),
        "role": user.role.value,
        "exp": int(time.time()) + (ttl_minutes * 60),
    }
    if active_session_id is not None:
        payload["sid"] = active_session_id

    encoded_header = _base64url_encode(
        json.dumps(header, separators=(",", ":")).encode("utf-8")
    )
    encoded_payload = _base64url_encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    )
    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    signature = hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    encoded_signature = _base64url_encode(signature)
    return f"{encoded_header}.{encoded_payload}.{encoded_signature}"


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        encoded_header, encoded_payload, encoded_signature = token.split(".")
    except ValueError as exc:
        raise unauthorized(Messages.INVALID_TOKEN) from exc

    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    expected_signature = hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    received_signature = _base64url_decode(encoded_signature)

    if not hmac.compare_digest(received_signature, expected_signature):
        raise unauthorized(Messages.INVALID_TOKEN)

    try:
        payload = json.loads(_base64url_decode(encoded_payload))
    except (ValueError, json.JSONDecodeError) as exc:
        raise unauthorized(Messages.INVALID_TOKEN) from exc

    if int(payload.get("exp", 0)) < int(time.time()):
        raise unauthorized(Messages.TOKEN_EXPIRED)

    return payload


def _session_id_from_refresh_token(refresh_token_value: str | None) -> str | None:
    normalized = (refresh_token_value or "").strip()
    if not normalized:
        return None
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def _enforce_active_session(payload: dict[str, Any], user: User) -> None:
    expected_sid = _session_id_from_refresh_token(getattr(user, "refresh_token", None))
    provided_sid = payload.get("sid")

    if not expected_sid:
        raise unauthorized(Messages.SESSION_EXPIRED)
    if provided_sid is None or str(provided_sid) != expected_sid:
        raise unauthorized(Messages.SESSION_EXPIRED)


async def verify_token(token: str, session: AsyncSession) -> User | None:
    try:
        payload = decode_access_token(token)
        user_id = payload.get("sub")
        if user_id is None:
            return None
        user = await get_user_by_id(session, int(user_id))
        if (
            user is None
            or bool(getattr(user, "is_blocked", False))
            or getattr(user, "deleted_at", None) is not None
        ):
            return None
        await ensure_user_not_suspended(session, user)
        _enforce_active_session(payload, user)
        return user
    except (ApiError, TypeError, ValueError):
        return None


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_db_session),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise unauthorized(Messages.AUTHENTICATION_REQUIRED)

    payload = decode_access_token(credentials.credentials)
    user_id = payload.get("sub")
    if user_id is None:
        raise unauthorized(Messages.INVALID_TOKEN)

    user = await get_user_by_id(session, int(user_id))
    if user is None:
        raise unauthorized(Messages.USER_NOT_FOUND)
    if getattr(user, "deleted_at", None) is not None:
        raise forbidden(Messages.ACCOUNT_DELETED)
    if user.is_blocked:
        raise forbidden(Messages.ACCOUNT_BLOCKED)
    await ensure_user_not_suspended(session, user)
    _enforce_active_session(payload, user)

    return user


async def get_current_client(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.CLIENT:
        raise forbidden(Messages.PASSENGER_ACCESS_REQUIRED)
    return current_user


async def get_current_driver(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.DRIVER:
        raise forbidden(Messages.DRIVER_ACCESS_REQUIRED)
    return current_user
