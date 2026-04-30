import base64
import hashlib
import hmac
import json
import time
from typing import Any

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.config import settings
from app.db.database import get_db_session
from app.models.admin import Admin
from app.models.ride_report import RideReport, RideReportStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import DriverStatus, User

admin_bearer_scheme = HTTPBearer(auto_error=False)


class AdminAlreadyExistsError(Exception):
    pass


class AdminUserDeleteBlockedError(Exception):
    pass


class AdminUserNotFoundError(Exception):
    pass


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
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid admin token") from exc

    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    expected_signature = hmac.new(
        settings.ADMIN_SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()
    if not hmac.compare_digest(expected_signature, _base64url_decode(encoded_signature)):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid admin token")

    payload = json.loads(_base64url_decode(encoded_payload))
    if payload.get("role") != "admin" or int(payload.get("exp", 0)) < int(time.time()):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid admin token")
    return payload


async def require_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(admin_bearer_scheme),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Admin token required")
    return decode_admin_token(credentials.credentials)


async def create_admin(session: AsyncSession, username: str, password: str) -> Admin:
    count_result = await session.execute(select(func.count(Admin.id)))
    if count_result.scalar_one() > 0:
        raise AdminAlreadyExistsError("Admin already initialized")

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
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid admin credentials")
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
            "created_at": user.created_at,
        }
        for user in result.scalars().all()
    ]


async def block_user(session: AsyncSession, user_id: int) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError("User not found")

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
        raise AdminUserNotFoundError("User not found")

    user.is_blocked = False
    await session.commit()
    await session.refresh(user)
    return user


async def delete_user(session: AsyncSession, user_id: int) -> None:
    user = await session.get(User, user_id)
    if user is None:
        raise AdminUserNotFoundError("User not found")

    await session.delete(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise AdminUserDeleteBlockedError(
            "User has related data. Block this account instead."
        ) from exc


async def get_all_rides(session: AsyncSession) -> list[dict[str, Any]]:
    client = aliased(User)
    driver = aliased(User)
    report_counts_result = await session.execute(
        select(RideReport.ride_request_id, func.count(RideReport.id))
        .group_by(RideReport.ride_request_id)
    )
    report_counts = {
        ride_id: count for ride_id, count in report_counts_result.all()
    }
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
        .where(RideReport.status == RideReportStatus.OUVERT)
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
            "created_at": report.created_at,
            "pickup_location": ride.pickup_location,
            "dropoff_location": ride.dropoff_location,
            "ride_status": ride.status.value,
        }
        for report, ride, reporter_phone, reporter_role in result.all()
    ]


async def get_dashboard_stats(session: AsyncSession) -> dict[str, Any]:
    grouped_result = await session.execute(
        select(RideRequest.status, func.count(RideRequest.id)).group_by(RideRequest.status)
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
        ).where(
            RideRequest.status == RideRequestStatus.COMPLETED
        )
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
        "estimated_price": ride.estimated_price,
        "agreed_price": ride.agreed_price,
        "final_price": ride.final_price,
        "status": ride.status.value,
        "created_at": ride.created_at,
        "report_count": report_count,
    }
