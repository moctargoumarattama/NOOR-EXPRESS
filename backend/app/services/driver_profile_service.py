from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.driver_profile import DriverProfile, DriverVerificationStatus
from app.models.user import User, UserRole
from app.schemas.driver_profile import DriverProfileCreate


async def create_or_update_profile(
    session: AsyncSession,
    user_id: int,
    data: DriverProfileCreate,
) -> DriverProfile:
    profile = await get_profile(session, user_id)
    now = datetime.utcnow()

    if profile is None:
        profile = DriverProfile(user_id=user_id)
        session.add(profile)

    profile.first_name = data.first_name.strip()
    profile.last_name = data.last_name.strip()
    profile.address = data.address.strip() if data.address else None
    profile.id_card_photo = data.id_card_photo
    profile.selfie_photo = data.selfie_photo
    profile.verification_status = DriverVerificationStatus.PENDING
    profile.rejection_reason = None
    profile.submitted_at = now
    profile.verified_at = None

    await session.commit()
    await session.refresh(profile)
    return profile


async def get_profile(session: AsyncSession, user_id: int) -> DriverProfile | None:
    result = await session.execute(
        select(DriverProfile).where(DriverProfile.user_id == user_id)
    )
    return result.scalar_one_or_none()


async def get_pending_drivers(session: AsyncSession) -> list[dict]:
    result = await session.execute(
        select(DriverProfile, User)
        .join(User, DriverProfile.user_id == User.id)
        .where(
            DriverProfile.verification_status == DriverVerificationStatus.PENDING,
            User.role == UserRole.DRIVER,
        )
        .order_by(DriverProfile.submitted_at.desc())
    )
    return [
        _admin_row(profile, user)
        for profile, user in result.all()
    ]


async def verify_driver(session: AsyncSession, user_id: int) -> DriverProfile:
    profile = await _get_profile_or_404(session, user_id)
    profile.verification_status = DriverVerificationStatus.VERIFIED
    profile.rejection_reason = None
    profile.verified_at = datetime.utcnow()
    await session.commit()
    await session.refresh(profile)
    return profile


async def reject_driver(
    session: AsyncSession,
    user_id: int,
    reason: str,
) -> DriverProfile:
    profile = await _get_profile_or_404(session, user_id)
    profile.verification_status = DriverVerificationStatus.REJECTED
    profile.rejection_reason = reason.strip()
    profile.verified_at = None
    await session.commit()
    await session.refresh(profile)
    return profile


async def _get_profile_or_404(session: AsyncSession, user_id: int) -> DriverProfile:
    profile = await get_profile(session, user_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver profile not found",
        )
    return profile


def _admin_row(profile: DriverProfile, user: User) -> dict:
    return {
        "id": profile.id,
        "user_id": profile.user_id,
        "phone_number": user.phone_number,
        "user_name": user.name,
        "first_name": profile.first_name,
        "last_name": profile.last_name,
        "address": profile.address,
        "id_card_photo": profile.id_card_photo,
        "selfie_photo": profile.selfie_photo,
        "verification_status": profile.verification_status.value,
        "rejection_reason": profile.rejection_reason,
        "submitted_at": profile.submitted_at,
        "verified_at": profile.verified_at,
    }
