from datetime import datetime, timedelta
import secrets

from fastapi import HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import create_access_token
from app.models.otp import OtpCode
from app.models.user import DriverStatus, User, UserRole
from app.schemas.user import TokenResponse
from app.services.user_service import get_user_by_phone_number

OTP_TTL_MINUTES = 10


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
    if user is not None:
        if user.is_blocked:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is blocked.",
            )
        user.name = name
        user.role = role
        if role == UserRole.DRIVER:
            user.is_available = (
                user.is_available if user.is_available is not None else True
            )
            user.driver_status = user.driver_status or DriverStatus.OFFLINE
        else:
            user.is_available = None
            user.driver_status = None
        await session.commit()
        await session.refresh(user)
        return user

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


async def send_otp(session: AsyncSession, phone_number: str) -> None:
    user = await get_user_by_phone_number(session, phone_number)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found. Register first.",
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is blocked.",
        )

    otp_code = settings.OTP_CODE_DEV
    otp = OtpCode(
        user_id=user.id,
        code=otp_code,
        expires_at=datetime.utcnow() + timedelta(minutes=OTP_TTL_MINUTES),
    )
    session.add(otp)
    await session.commit()

    # TODO: brancher ici un vrai fournisseur SMS en production.
    print(f"OTP pour {phone_number}: {otp_code}")


async def verify_otp(
    session: AsyncSession,
    phone_number: str,
    code: str,
) -> TokenResponse:
    user = await get_user_by_phone_number(session, phone_number)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is blocked.",
        )

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
            detail="Invalid or expired OTP.",
        )

    otp.is_used = True
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
    if user is None or user.is_blocked or _is_refresh_token_expired(current_refresh_token):
        if user is not None:
            user.refresh_token = None
            await session.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token.",
        )

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
