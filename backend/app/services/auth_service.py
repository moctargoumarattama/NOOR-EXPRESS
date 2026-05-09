from datetime import datetime, timedelta
import logging
import secrets

from fastapi import HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.messages import Messages
from app.core.security import create_access_token
from app.models.otp import OtpCode
from app.models.user import DriverStatus, User, UserRole
from app.schemas.user import TokenResponse
from app.services.user_service import (
    ensure_user_not_suspended,
    get_user_by_phone_number,
)

OTP_TTL_MINUTES = 10
logger = logging.getLogger(__name__)
ROLE_LABELS = {
    UserRole.CLIENT: "passager",
    UserRole.DRIVER: "chauffeur",
}
REGISTER_POLICY_CASE_NEW_NUMBER = "new_number"
REGISTER_POLICY_CASE_EXISTING_SAME_ROLE = "existing_same_role"
REGISTER_POLICY_CASE_EXISTING_DIFFERENT_ROLE = "existing_different_role"
REGISTER_POLICY_CASE_SUSPENDED_ACCOUNT = "suspended_account"
REGISTER_SUSPENDED_ACCOUNT_MESSAGE = Messages.ACCOUNT_SUSPENDED


def _create_refresh_token() -> str:
    expires_at = datetime.utcnow() + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS,
    )
    return f"{secrets.token_urlsafe(48)}.{int(expires_at.timestamp())}"


def _is_refresh_token_expired(refresh_token_value: str) -> bool:
    try:
        expires_at = int(refresh_token_value.rsplit(".", maxsplit=1)[1])
    except (IndexError, ValueError):
        return True
    return expires_at < int(datetime.utcnow().timestamp())


async def register(
    session: AsyncSession,
    phone_number: str,
    name: str,
    role: UserRole,
) -> User:
    user = await get_user_by_phone_number(session, phone_number)
    register_case = _resolve_register_policy_case(user, requested_role=role)
    if register_case == REGISTER_POLICY_CASE_NEW_NUMBER:
        user = User(
            phone_number=phone_number,
            name=name,
            role=role,
            is_available=True if role == UserRole.DRIVER else None,
            driver_status=DriverStatus.OFFLINE if role == UserRole.DRIVER else None,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        return user

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=Messages.SERVER_ERROR,
        )

    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=Messages.ACCOUNT_BLOCKED,
        )

    if register_case == REGISTER_POLICY_CASE_SUSPENDED_ACCOUNT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=REGISTER_SUSPENDED_ACCOUNT_MESSAGE,
        )

    if register_case == REGISTER_POLICY_CASE_EXISTING_DIFFERENT_ROLE:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=Messages.REGISTER_ROLE_CONFLICT.format(
                role_label=ROLE_LABELS.get(user.role, "passager"),
            ),
        )

    if register_case == REGISTER_POLICY_CASE_EXISTING_SAME_ROLE:
        await ensure_user_not_suspended(session, user)
        return user

    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=Messages.SERVER_ERROR,
    )


def _resolve_register_policy_case(
    user: User | None,
    *,
    requested_role: UserRole,
) -> str:
    if user is None:
        return REGISTER_POLICY_CASE_NEW_NUMBER
    if user.is_suspended:
        return REGISTER_POLICY_CASE_SUSPENDED_ACCOUNT
    if user.role != requested_role:
        return REGISTER_POLICY_CASE_EXISTING_DIFFERENT_ROLE
    return REGISTER_POLICY_CASE_EXISTING_SAME_ROLE


async def send_otp(session: AsyncSession, phone_number: str) -> None:
    user = await get_user_by_phone_number(session, phone_number)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=Messages.REGISTER_FIRST,
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=Messages.ACCOUNT_BLOCKED,
        )
    await ensure_user_not_suspended(session, user)

    otp_code = settings.OTP_CODE_DEV
    otp = OtpCode(
        user_id=user.id,
        code=otp_code,
        expires_at=datetime.utcnow() + timedelta(minutes=OTP_TTL_MINUTES),
    )
    session.add(otp)
    await session.commit()

    logger.info("OTP generated for %s", phone_number)


async def verify_otp(
    session: AsyncSession,
    phone_number: str,
    code: str,
) -> TokenResponse:
    user = await get_user_by_phone_number(session, phone_number)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=Messages.USER_NOT_FOUND,
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=Messages.ACCOUNT_BLOCKED,
        )
    await ensure_user_not_suspended(session, user)

    result = await session.execute(
        select(OtpCode)
        .where(
            OtpCode.user_id == user.id,
            OtpCode.code == code,
            OtpCode.is_used.is_(False),
            OtpCode.expires_at >= datetime.utcnow(),
        )
        .order_by(desc(OtpCode.created_at))
        .limit(1)
    )
    otp = result.scalar_one_or_none()
    if otp is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=Messages.INVALID_OR_EXPIRED_OTP,
        )

    otp.is_used = True
    return await start_user_session(session, user)


async def start_user_session(
    session: AsyncSession,
    user: User,
) -> TokenResponse:
    user.refresh_token = _create_refresh_token()
    await session.commit()
    await session.refresh(user)
    return TokenResponse(
        access_token=create_access_token(
            user,
            expires_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
        ),
        refresh_token=user.refresh_token,
    )


async def refresh_token(
    session: AsyncSession,
    current_refresh_token: str,
) -> TokenResponse:
    result = await session.execute(
        select(User).where(User.refresh_token == current_refresh_token)
    )
    user = result.scalar_one_or_none()
    if (
        user is None
        or user.is_blocked
        or _is_refresh_token_expired(current_refresh_token)
    ):
        if user is not None:
            user.refresh_token = None
            await session.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=Messages.INVALID_REFRESH_TOKEN,
        )
    await ensure_user_not_suspended(session, user)

    return TokenResponse(
        access_token=create_access_token(
            user,
            expires_minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES,
        ),
    )


async def logout(session: AsyncSession, user_id: int) -> None:
    user = await session.get(User, user_id)
    if user is None:
        return

    user.refresh_token = None
    await session.commit()
