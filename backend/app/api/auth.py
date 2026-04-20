from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.core.security import get_current_user
from app.db.database import get_db_session
from app.models.user import User, UserRole
from app.schemas.user import TokenResponse, UserLogin, UserRead
from app.services.auth_service import (
    logout,
    refresh_token,
    register,
    send_otp,
    verify_otp,
)
from app.services.user_service import authenticate_user

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    phone_number: str
    name: str
    role: UserRole

    @field_validator("phone_number", "name")
    @classmethod
    def validate_not_empty(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Field cannot be empty")
        return cleaned


class PhoneRequest(BaseModel):
    phone_number: str


class OtpVerifyRequest(BaseModel):
    phone_number: str
    code: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class AuthMessageResponse(BaseModel):
    message: str


@router.post("/login", response_model=TokenResponse)
async def login_endpoint(
    user_in: UserLogin,
    session: AsyncSession = Depends(get_db_session),
) -> TokenResponse:
    user = await authenticate_user(session, user_in.phone_number)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    return TokenResponse(access_token=create_access_token(user))


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register_endpoint(
    user_in: RegisterRequest,
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    user = await register(
        session,
        phone_number=user_in.phone_number,
        name=user_in.name,
        role=user_in.role,
    )
    return UserRead.model_validate(user)


@router.post("/otp/send", response_model=AuthMessageResponse)
async def send_otp_endpoint(
    otp_in: PhoneRequest,
    session: AsyncSession = Depends(get_db_session),
) -> AuthMessageResponse:
    await send_otp(session, otp_in.phone_number)
    return AuthMessageResponse(message="OTP sent")


@router.post("/otp/verify", response_model=TokenResponse)
async def verify_otp_endpoint(
    otp_in: OtpVerifyRequest,
    session: AsyncSession = Depends(get_db_session),
) -> TokenResponse:
    return await verify_otp(session, otp_in.phone_number, otp_in.code)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token_endpoint(
    token_in: RefreshTokenRequest,
    session: AsyncSession = Depends(get_db_session),
) -> TokenResponse:
    return await refresh_token(session, token_in.refresh_token)


@router.post("/logout", response_model=AuthMessageResponse)
async def logout_endpoint(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> AuthMessageResponse:
    await logout(session, current_user.id)
    return AuthMessageResponse(message="Logged out")
