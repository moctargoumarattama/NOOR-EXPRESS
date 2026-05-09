from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.user import User

_firebase_ready: bool | None = None
_firebase_readiness_error: str | None = None

FIREBASE_NOT_CONFIGURED_REASON = "Firebase non configure"
FCM_NO_RECIPIENT_REASON = "Aucun destinataire FCM disponible"


def _credentials_path() -> Path:
    path = Path(settings.FIREBASE_CREDENTIALS_PATH)
    if path.is_absolute():
        return path
    return Path(__file__).resolve().parents[2] / path


def _ensure_firebase() -> bool:
    global _firebase_ready, _firebase_readiness_error
    if _firebase_ready is not None:
        return _firebase_ready

    path = _credentials_path()
    if not path.exists():
        print(f"[FCM] Credentials absents: {path}. Notifications ignorees.")
        _firebase_ready = False
        _firebase_readiness_error = FIREBASE_NOT_CONFIGURED_REASON
        return False

    try:
        firebase_admin.get_app()
    except ValueError:
        try:
            firebase_admin.initialize_app(credentials.Certificate(str(path)))
        except Exception as exc:
            print(f"[FCM] Initialisation impossible: {exc}")
            _firebase_ready = False
            _firebase_readiness_error = FIREBASE_NOT_CONFIGURED_REASON
            return False
    _firebase_ready = True
    _firebase_readiness_error = None
    return True


def is_firebase_ready() -> bool:
    return _ensure_firebase()


def firebase_readiness_error() -> str | None:
    _ensure_firebase()
    return _firebase_readiness_error


def send_to_multiple(
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    result, _ = _send_to_tokens(tokens, title=title, body=body, data=data)
    return result


def _send_to_tokens(
    tokens: list[str],
    *,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> tuple[dict[str, Any], set[str]]:
    recipient_count = len(tokens)
    if recipient_count == 0:
        return (
            _fcm_result(
                success=False,
                sent_count=0,
                failed_count=0,
                error_reason=FCM_NO_RECIPIENT_REASON,
            ),
            set(),
        )

    if not _ensure_firebase():
        return (
            _fcm_result(
                success=False,
                sent_count=0,
                failed_count=recipient_count,
                error_reason=FIREBASE_NOT_CONFIGURED_REASON,
            ),
            set(),
        )

    sent_count = 0
    failed_count = 0
    invalid_tokens: set[str] = set()
    first_error_reason: str | None = None
    payload = _stringify_data(data or {})

    for token in tokens:
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(title=title, body=body),
                    data=payload,
                )
            )
            sent_count += 1
        except Exception as exc:
            failed_count += 1
            if _is_invalid_token_error(exc):
                invalid_tokens.add(token)
                if first_error_reason is None:
                    first_error_reason = "Tokens FCM invalides ou expires"
                continue
            if first_error_reason is None:
                first_error_reason = str(exc)
            print(f"[FCM] Envoi impossible: {exc}")

    error_reason = None
    if failed_count > 0:
        error_reason = first_error_reason or "Echec FCM"
    return (
        _fcm_result(
            success=sent_count > 0 and failed_count == 0,
            sent_count=sent_count,
            failed_count=failed_count,
            error_reason=error_reason,
        ),
        invalid_tokens,
    )


def _fcm_result(
    *,
    success: bool,
    sent_count: int,
    failed_count: int,
    error_reason: str | None,
) -> dict[str, Any]:
    return {
        "success": success,
        "sent_count": sent_count,
        "failed_count": failed_count,
        "error_reason": error_reason,
    }


async def notify_user(
    session: AsyncSession,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    user = await session.get(User, user_id)
    if user is None or not user.fcm_token:
        return _fcm_result(
            success=False,
            sent_count=0,
            failed_count=0,
            error_reason=FCM_NO_RECIPIENT_REASON,
        )

    result, invalid_tokens = _send_to_tokens(
        [user.fcm_token],
        title=title,
        body=body,
        data=data,
    )
    if user.fcm_token in invalid_tokens:
        user.fcm_token = None
        await session.commit()
    return result


async def notify_users(
    session: AsyncSession,
    user_ids: list[int],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return await notify_users_with_result(
        session,
        user_ids,
        title=title,
        body=body,
        data=data,
        commit_invalid_tokens=True,
    )


async def notify_users_with_result(
    session: AsyncSession,
    user_ids: list[int],
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    *,
    commit_invalid_tokens: bool = False,
) -> dict[str, Any]:
    if not user_ids:
        return _fcm_result(
            success=False,
            sent_count=0,
            failed_count=0,
            error_reason=FCM_NO_RECIPIENT_REASON,
        )
    result = await session.execute(select(User).where(User.id.in_(user_ids)))
    users = list(result.scalars().all())
    tokens = [user.fcm_token for user in users if user.fcm_token]
    fcm_result, invalid_tokens = _send_to_tokens(
        tokens,
        title=title,
        body=body,
        data=data,
    )
    if invalid_tokens:
        for user in users:
            if user.fcm_token in invalid_tokens:
                user.fcm_token = None
        if commit_invalid_tokens:
            await session.commit()
    return fcm_result


def _stringify_data(data: dict[str, Any]) -> dict[str, str]:
    return {key: str(value) for key, value in data.items() if value is not None}


def _is_invalid_token_error(error: Exception) -> bool:
    return error.__class__.__name__ in {
        "UnregisteredError",
        "SenderIdMismatchError",
    }
