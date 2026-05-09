import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta
from typing import Any

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.config import settings
from app.core.firebase import (
    FIREBASE_NOT_CONFIGURED_REASON,
    firebase_readiness_error,
    is_firebase_ready,
    notify_user,
    notify_users_with_result,
)
from app.core.messages import Messages
from app.db.database import get_db_session
from app.models.admin import Admin
from app.models.broadcast_history import BroadcastFCMStatus, BroadcastHistory
from app.models.ride_report import RideReport, RideReportStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import DriverStatus, User, UserRole, UserSuspension

admin_bearer_scheme = HTTPBearer(auto_error=False)
BROADCAST_LIMIT_PER_HOUR = 5
BROADCAST_LIMIT_WINDOW = timedelta(hours=1)


class AdminAlreadyExistsError(Exception):
    pass


class AdminUserDeleteBlockedError(Exception):
    pass


class AdminUserNotFoundError(Exception):
    pass


class AdminReportNotFoundError(Exception):
    pass


class AdminSuspensionInvalidError(Exception):
    pass


class AdminNotificationRateLimitError(Exception):
    def __init__(self, retry_after_seconds: int) -> None:
        self.retry_after_seconds = retry_after_seconds
        super().__init__(Messages.BROADCAST_LIMIT_REACHED)


def _base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")


def _base64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def create_admin_token(admin: Admin) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": str(admin.id),
        "username": admin.username,
        "role": "admin",
        "exp": int(time.time()) + 8 * 60 * 60,
    }
    encoded_header = _base64url_encode(json.dumps(header).encode("utf-8"))
    encoded_payload = _base64url_encode(json.dumps(payload).encode("utf-8"))
    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    signature = hmac.new(
        settings.ADMIN_SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    return f"{encoded_header}.{encoded_payload}.{_base64url_encode(signature)}"


def decode_admin_token(token: str) -> dict[str, Any]:
    try:
        encoded_header, encoded_payload, encoded_signature = token.split(".")
    except ValueError as exc:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, Messages.INVALID_ADMIN_TOKEN
        ) from exc

    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    expected_signature = hmac.new(
        settings.ADMIN_SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    if not hmac.compare_digest(
        expected_signature, _base64url_decode(encoded_signature)
    ):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, Messages.INVALID_ADMIN_TOKEN)

    payload = json.loads(_base64url_decode(encoded_payload))
    if payload.get("role") != "admin" or int(payload.get("exp", 0)) < int(time.time()):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, Messages.INVALID_ADMIN_TOKEN)
    return payload


async def require_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(admin_bearer_scheme),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, Messages.ADMIN_TOKEN_REQUIRED)
    return decode_admin_token(credentials.credentials)


async def create_admin(session: AsyncSession, username: str, password: str) -> Admin:
    count_result = await session.execute(select(func.count(Admin.id)))
    if count_result.scalar_one() > 0:
        raise AdminAlreadyExistsError(Messages.ADMIN_ALREADY_INITIALIZED)

    password_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode()
    admin = Admin(username=username, password_hash=password_hash)
    session.add(admin)
    await session.commit()
    await session.refresh(admin)
    return admin


async def login_admin(session: AsyncSession, username: str, password: str) -> str:
    result = await session.execute(select(Admin).where(Admin.username == username))
    admin = result.scalar_one_or_none()
    if admin is None or not bcrypt.checkpw(
        password.encode("utf-8"),
        admin.password_hash.encode("utf-8"),
    ):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            Messages.INVALID_ADMIN_CREDENTIALS,
        )
    return create_admin_token(admin)


async def get_all_users(session: AsyncSession) -> list[dict[str, Any]]:
    result = await session.execute(select(User).order_by(User.created_at.desc()))
    return [
        {
            "id": user.id,
            "phone_number": user.phone_number,
            "name": user.name,
            "role": user.role.value,
            "is_blocked": bool(user.is_blocked),
            "is_suspended": bool(user.is_suspended),
            "suspended_until": user.suspended_until,
            "suspension_reason": user.suspension_reason,
            "deleted_at": user.deleted_at,
            "deletion_reason": user.deletion_reason,
            "created_at": user.created_at,
        }
        for user in result.scalars().all()
    ]


async def get_deleted_users(session: AsyncSession) -> list[dict[str, Any]]:
    result = await session.execute(
        select(User)
        .where(User.deleted_at.is_not(None))
        .order_by(User.deleted_at.desc(), User.id.desc())
    )
    return [
        {
            "id": user.id,
            "role": user.role.value,
            "phone_hash": user.phone_number,
            "deleted_at": user.deleted_at,
            "deletion_reason": user.deletion_reason,
        }
        for user in result.scalars().all()
    ]


async def block_user(session: AsyncSession, user_id: int) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)

    user.is_blocked = True
    user.refresh_token = None
    user.fcm_token = None
    if user.role.value == "driver":
        user.is_available = False
        user.driver_status = DriverStatus.OFFLINE
    await session.commit()
    await session.refresh(user)
    return user


async def unblock_user(session: AsyncSession, user_id: int) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)

    user.is_blocked = False
    await session.commit()
    await session.refresh(user)
    return user


async def delete_user(session: AsyncSession, user_id: int) -> None:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)

    await session.delete(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise AdminUserDeleteBlockedError(
            "Utilisateur lie a des donnees actives. Bloquez ce compte a la place."
        ) from exc


async def get_all_rides(session: AsyncSession) -> list[dict[str, Any]]:
    client = aliased(User)
    driver = aliased(User)
    report_counts_result = await session.execute(
        select(RideReport.ride_request_id, func.count(RideReport.id)).group_by(
            RideReport.ride_request_id
        )
    )
    report_counts = {ride_id: count for ride_id, count in report_counts_result.all()}
    result = await session.execute(
        select(RideRequest, client.phone_number, driver.phone_number)
        .join(client, RideRequest.client_id == client.id)
        .outerjoin(driver, RideRequest.driver_id == driver.id)
        .order_by(RideRequest.created_at.desc())
        .limit(500)
    )
    return [
        _ride_row(
            ride,
            client_phone,
            driver_phone,
            report_count=report_counts.get(ride.id, 0),
        )
        for ride, client_phone, driver_phone in result.all()
    ]


async def get_all_reports(session: AsyncSession) -> list[dict[str, Any]]:
    reporter = aliased(User)
    result = await session.execute(
        select(RideReport, RideRequest, reporter.phone_number, reporter.role)
        .join(RideRequest, RideReport.ride_request_id == RideRequest.id)
        .join(reporter, RideReport.reported_by_id == reporter.id)
        .order_by(RideReport.created_at.desc())
        .limit(500)
    )
    return [
        {
            "id": report.id,
            "ride_request_id": report.ride_request_id,
            "reported_by": reporter_phone,
            "reported_by_role": reporter_role.value,
            "reason": report.reason.value,
            "description": report.description,
            "status": report.status.value,
            "note_admin": report.note_admin,
            "created_at": report.created_at,
            "pickup_location": ride.pickup_location,
            "dropoff_location": ride.dropoff_location,
            "ride_status": ride.status.value,
            "reported_user_id": _resolve_reported_user_id(
                report=report,
                ride_request=ride,
            ),
            "client_id": ride.client_id,
            "driver_id": ride.driver_id,
        }
        for report, ride, reporter_phone, reporter_role in result.all()
    ]


async def update_report(
    session: AsyncSession,
    report_id: int,
    *,
    status: RideReportStatus,
    note_admin: str | None,
) -> RideReport:
    report = await session.get(RideReport, report_id)
    if report is None:
        raise AdminReportNotFoundError(Messages.NOT_FOUND)

    previous_status = report.status
    report.status = status
    report.note_admin = note_admin
    await session.commit()
    await session.refresh(report)

    if previous_status != report.status:
        await _notify_report_status_change(session, report)
    return report


async def suspend_user(
    session: AsyncSession,
    user_id: int,
    *,
    reason: str,
    duration_days: int | None,
) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)

    suspension_reason = reason.strip()
    if not suspension_reason:
        raise AdminSuspensionInvalidError(Messages.SUSPENSION_REASON_REQUIRED)
    if duration_days is not None and duration_days <= 0:
        raise AdminSuspensionInvalidError(Messages.SUSPENSION_DURATION_POSITIVE)

    suspended_until = (
        datetime.utcnow() + timedelta(days=duration_days)
        if duration_days is not None
        else None
    )
    user.is_suspended = True
    user.suspended_until = suspended_until
    user.suspension_reason = suspension_reason
    user.refresh_token = None
    if user.role == UserRole.DRIVER:
        user.is_available = False
        user.driver_status = DriverStatus.OFFLINE

    session.add(
        UserSuspension(
            user_id=user.id,
            reason=suspension_reason,
            suspended_until=suspended_until,
        )
    )
    await session.commit()
    await session.refresh(user)
    return user


async def unsuspend_user(session: AsyncSession, user_id: int) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)

    user.is_suspended = False
    user.suspended_until = None
    user.suspension_reason = None
    latest_suspension = await _get_latest_open_suspension(session, user_id)
    if latest_suspension is not None:
        latest_suspension.lifted_at = datetime.utcnow()
    await session.commit()
    await session.refresh(user)
    return user


async def get_user_suspension_history(
    session: AsyncSession,
    user_id: int,
) -> list[dict[str, Any]]:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)

    result = await session.execute(
        select(UserSuspension)
        .where(UserSuspension.user_id == user_id)
        .order_by(UserSuspension.suspended_at.desc(), UserSuspension.id.desc())
        .limit(100)
    )
    return [
        {
            "id": suspension.id,
            "user_id": suspension.user_id,
            "reason": suspension.reason,
            "suspended_at": suspension.suspended_at,
            "suspended_until": suspension.suspended_until,
            "lifted_at": suspension.lifted_at,
            "is_permanent": suspension.suspended_until is None,
        }
        for suspension in result.scalars().all()
    ]


async def get_dashboard_stats(session: AsyncSession) -> dict[str, Any]:
    grouped_result = await session.execute(
        select(RideRequest.status, func.count(RideRequest.id)).group_by(
            RideRequest.status
        )
    )
    counts = {status.value: count for status, count in grouped_result.all()}
    revenue_result = await session.execute(
        select(
            func.coalesce(
                func.sum(
                    func.coalesce(
                        RideRequest.final_price,
                        RideRequest.agreed_price,
                        RideRequest.estimated_price,
                    )
                ),
                0.0,
            )
        ).where(RideRequest.status == RideRequestStatus.COMPLETED)
    )
    users_count = await session.execute(select(func.count(User.id)))
    return {
        "total_rides": sum(counts.values()),
        "pending": counts.get("pending", 0),
        "offered": counts.get("offered", 0),
        "accepted": counts.get("accepted", 0),
        "started": counts.get("started", 0),
        "completed": counts.get("completed", 0),
        "cancelled": counts.get("cancelled", 0),
        "revenue": round(float(revenue_result.scalar_one() or 0), 2),
        "total_users": users_count.scalar_one(),
    }


async def estimate_broadcast_recipients(
    session: AsyncSession,
    *,
    target: str,
    user_id: int | None = None,
) -> int:
    recipient_ids, _ = await _resolve_broadcast_recipient_ids(
        session,
        target=target,
        user_id=user_id,
        strict_user_target=False,
    )
    return len(recipient_ids)


async def send_notification_broadcast(
    session: AsyncSession,
    *,
    target: str,
    user_id: int | None,
    title: str,
    message: str,
    notification_type: str,
) -> dict[str, Any]:
    recipient_ids, history_target = await _resolve_broadcast_recipient_ids(
        session,
        target=target,
        user_id=user_id,
        strict_user_target=True,
    )
    await _enforce_broadcast_rate_limit(session)

    send_result = await notify_users_with_result(
        session,
        recipient_ids,
        title=title,
        body=message,
        data={
            "type": notification_type,
            "target": history_target,
            "scope": "admin_broadcast",
        },
    )
    fcm_status = _resolve_broadcast_fcm_status(send_result)
    history = BroadcastHistory(
        target=history_target,
        title=title,
        message=message,
        notification_type=notification_type,
        estimated_recipients=len(recipient_ids),
        fcm_sent_count=int(send_result.get("sent_count", 0)),
        fcm_failed_count=int(send_result.get("failed_count", 0)),
        fcm_status=fcm_status.value,
        fcm_error_reason=send_result.get("error_reason"),
    )
    session.add(history)
    await session.commit()
    await session.refresh(history)
    return _broadcast_history_row(history)


async def get_notification_broadcast_history(
    session: AsyncSession,
    *,
    limit: int,
    offset: int,
) -> dict[str, Any]:
    total_result = await session.execute(select(func.count(BroadcastHistory.id)))
    total = int(total_result.scalar_one() or 0)
    result = await session.execute(
        select(BroadcastHistory)
        .order_by(BroadcastHistory.sent_at.desc(), BroadcastHistory.id.desc())
        .limit(limit)
        .offset(offset)
    )
    items = [_broadcast_history_row(row) for row in result.scalars().all()]
    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
        "firebase_ready": is_firebase_ready(),
        "firebase_error_reason": firebase_readiness_error(),
    }


def _resolve_reported_user_id(
    *,
    report: RideReport,
    ride_request: RideRequest,
) -> int | None:
    if report.reported_by_id == ride_request.client_id:
        return ride_request.driver_id
    if report.reported_by_id == ride_request.driver_id:
        return ride_request.client_id
    return None


async def _notify_report_status_change(
    session: AsyncSession,
    report: RideReport,
) -> None:
    ride_request = await session.get(RideRequest, report.ride_request_id)
    if ride_request is None:
        return
    reported_user_id = _resolve_reported_user_id(
        report=report,
        ride_request=ride_request,
    )
    if reported_user_id is None:
        return
    await notify_user(
        session,
        reported_user_id,
        title="Mise a jour signalement",
        body=f"Un signalement vous concernant est passe au statut {report.status.value}.",
        data={
            "type": "report_status_updated",
            "report_id": report.id,
            "ride_id": report.ride_request_id,
            "status": report.status.value,
        },
    )


async def _get_latest_open_suspension(
    session: AsyncSession,
    user_id: int,
) -> UserSuspension | None:
    result = await session.execute(
        select(UserSuspension)
        .where(
            UserSuspension.user_id == user_id,
            UserSuspension.lifted_at.is_(None),
        )
        .order_by(UserSuspension.suspended_at.desc(), UserSuspension.id.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


def _ride_row(
    ride: RideRequest,
    client_phone: str,
    driver_phone: str | None,
    *,
    report_count: int,
) -> dict[str, Any]:
    return {
        "id": ride.id,
        "client": client_phone,
        "driver": driver_phone,
        "pickup_location": ride.pickup_location,
        "dropoff_location": ride.dropoff_location,
        "distance_km": ride.distance_km,
        "duration_minutes": ride.duration_minutes,
        "estimated_price": ride.estimated_price,
        "agreed_price": ride.agreed_price,
        "final_price": ride.final_price,
        "platform_commission": ride.platform_commission,
        "driver_net_earnings": ride.driver_net_earnings,
        "status": ride.status.value,
        "created_at": ride.created_at,
        "completed_at": ride.completed_at,
        "report_count": report_count,
    }


async def _enforce_broadcast_rate_limit(session: AsyncSession) -> None:
    window_start = datetime.utcnow() - BROADCAST_LIMIT_WINDOW
    count_result = await session.execute(
        select(func.count(BroadcastHistory.id)).where(
            BroadcastHistory.sent_at >= window_start
        )
    )
    sent_in_window = int(count_result.scalar_one() or 0)
    if sent_in_window < BROADCAST_LIMIT_PER_HOUR:
        return

    oldest_result = await session.execute(
        select(BroadcastHistory.sent_at)
        .where(BroadcastHistory.sent_at >= window_start)
        .order_by(BroadcastHistory.sent_at.asc(), BroadcastHistory.id.asc())
        .limit(1)
    )
    oldest_sent_at = oldest_result.scalar_one_or_none()
    retry_after_seconds = int(BROADCAST_LIMIT_WINDOW.total_seconds())
    if oldest_sent_at is not None:
        retry_at = oldest_sent_at + BROADCAST_LIMIT_WINDOW
        retry_after_seconds = max(
            1,
            int((retry_at - datetime.utcnow()).total_seconds()),
        )
    raise AdminNotificationRateLimitError(retry_after_seconds)


async def _resolve_broadcast_recipient_ids(
    session: AsyncSession,
    *,
    target: str,
    user_id: int | None,
    strict_user_target: bool,
) -> tuple[list[int], str]:
    if target == "all":
        result = await session.execute(
            select(User.id).where(User.fcm_token.is_not(None), User.fcm_token != "")
        )
        return [row[0] for row in result.all()], "all"

    if target == "drivers":
        result = await session.execute(
            select(User.id).where(
                User.role == UserRole.DRIVER,
                User.fcm_token.is_not(None),
                User.fcm_token != "",
            )
        )
        return [row[0] for row in result.all()], "drivers"

    if target == "passengers":
        result = await session.execute(
            select(User.id).where(
                User.role == UserRole.CLIENT,
                User.fcm_token.is_not(None),
                User.fcm_token != "",
            )
        )
        return [row[0] for row in result.all()], "passengers"

    if target == "user_id":
        if user_id is None:
            raise ValueError(Messages.USER_ID_REQUIRED_FOR_TARGET)
        user = await session.get(User, user_id)
        if user is None:
            if strict_user_target:
                raise AdminUserNotFoundError(Messages.USER_NOT_FOUND)
            return [], f"user_id:{user_id}"
        if not user.fcm_token:
            return [], f"user_id:{user.id}"
        return [user.id], f"user_id:{user.id}"

    raise ValueError(Messages.BROADCAST_TARGET_UNKNOWN)


def _broadcast_history_row(history: BroadcastHistory) -> dict[str, Any]:
    return {
        "id": history.id,
        "target": history.target,
        "title": history.title,
        "message": history.message,
        "type": history.notification_type,
        "sent_at": history.sent_at,
        "estimated_recipients": history.estimated_recipients,
        "fcm_sent_count": history.fcm_sent_count,
        "fcm_failed_count": history.fcm_failed_count,
        "fcm_status": history.fcm_status,
        "fcm_error_reason": history.fcm_error_reason,
    }


def _resolve_broadcast_fcm_status(send_result: dict[str, Any]) -> BroadcastFCMStatus:
    error_reason = str(send_result.get("error_reason") or "")
    sent_count = int(send_result.get("sent_count", 0))
    failed_count = int(send_result.get("failed_count", 0))

    if error_reason == FIREBASE_NOT_CONFIGURED_REASON:
        return BroadcastFCMStatus.FIREBASE_NOT_CONFIGURED
    if sent_count > 0 and failed_count == 0:
        return BroadcastFCMStatus.SENT
    if sent_count > 0 and failed_count > 0:
        return BroadcastFCMStatus.PARTIAL
    return BroadcastFCMStatus.FAILED
