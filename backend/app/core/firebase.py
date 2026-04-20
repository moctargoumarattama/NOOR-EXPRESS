from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User

_firebase_ready: bool | None = None


def _credentials_path() -> Path:
    path = Path(settings.FIREBASE_CREDENTIALS_PATH)
    if path.is_absolute():
        return path
    return Path(__file__).resolve().parents[2] / path


def _ensure_firebase() -> bool:
    global _firebase_ready
    if _firebase_ready is not None:
        return _firebase_ready

    path = _credentials_path()
    if not path.exists():
        print(f"[FCM] Credentials absents: {path}. Notifications ignorees.")
        _firebase_ready = False
        return False

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.Certificate(str(path)))
    _firebase_ready = True
    return True


def send_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> str | None:
    if not _ensure_firebase():
        return None

    try:
        messaging.send(
            messaging.Message(
                token=fcm_token,
                notification=messaging.Notification(title=title, body=body),
                data=_stringify_data(data or {}),
            )
        )
        return None
    except Exception as exc:
        if _is_invalid_token_error(exc):
            return fcm_token
        print(f"[FCM] Envoi impossible: {exc}")
        return None


def send_to_multiple(
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> list[str]:
    invalid_tokens: list[str] = []
    for token in tokens:
        invalid_token = send_notification(token, title, body, data)
        if invalid_token is not None:
            invalid_tokens.append(invalid_token)
    return invalid_tokens


async def notify_user(
    session: AsyncSession,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> None:
    user = await session.get(User, user_id)
    if user is None or not user.fcm_token:
        return

    invalid_token = send_notification(user.fcm_token, title, body, data)
    if invalid_token is not None:
        user.fcm_token = None
        await session.commit()


async def notify_users(
    session: AsyncSession,
    user_ids: list[int],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> None:
    if not user_ids:
        return
    result = await session.execute(select(User).where(User.id.in_(user_ids)))
    users = list(result.scalars().all())
    tokens = [user.fcm_token for user in users if user.fcm_token]
    invalid_tokens = send_to_multiple(tokens, title, body, data)
    if invalid_tokens:
        for user in users:
            if user.fcm_token in invalid_tokens:
                user.fcm_token = None
        await session.commit()


def _stringify_data(data: dict[str, Any]) -> dict[str, str]:
    return {key: str(value) for key, value in data.items() if value is not None}


def _is_invalid_token_error(error: Exception) -> bool:
    return error.__class__.__name__ in {
        "UnregisteredError",
        "SenderIdMismatchError",
    }
