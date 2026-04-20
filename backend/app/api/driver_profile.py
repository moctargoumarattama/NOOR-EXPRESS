from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_driver
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.driver_profile import DriverProfileCreate, DriverProfileRead
from app.services.driver_profile_service import (
    create_or_update_profile,
    get_profile,
)

router = APIRouter(prefix="/driver-profile", tags=["driver-profile"])


@router.post("/submit", response_model=DriverProfileRead)
async def submit_driver_profile_endpoint(
    profile_in: DriverProfileCreate,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> DriverProfileRead:
    if not profile_in.id_card_photo or not profile_in.selfie_photo:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="ID card photo and selfie are required",
        )
    profile = await create_or_update_profile(session, current_user.id, profile_in)
    return DriverProfileRead.model_validate(profile)


@router.get("/me", response_model=DriverProfileRead | None)
async def get_driver_profile_status_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> DriverProfileRead | None:
    profile = await get_profile(session, current_user.id)
    if profile is None:
        return None
    return DriverProfileRead.model_validate(profile)
