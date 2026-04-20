from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_driver
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.user import (
    DriverAvailabilityUpdate,
    DriverProfileUpdate,
    UserRead,
)
from app.services.user_service import (
    get_driver_profile,
    update_driver_availability,
    update_driver_profile,
)

router = APIRouter(prefix="/drivers", tags=["drivers"])


@router.get("/me/profile", response_model=UserRead)
async def get_driver_profile_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    driver = await get_driver_profile(session, current_user.id)
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver not found",
        )
    return UserRead.model_validate(driver)


@router.put("/me/profile", response_model=UserRead)
async def update_driver_profile_endpoint(
    profile_in: DriverProfileUpdate,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    driver = await update_driver_profile(session, current_user.id, profile_in)
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver not found",
        )
    return UserRead.model_validate(driver)


@router.put("/me/availability", response_model=UserRead)
async def update_driver_availability_endpoint(
    availability_in: DriverAvailabilityUpdate,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    driver = await update_driver_availability(
        session,
        current_user.id,
        availability_in,
    )
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver not found",
        )
    return UserRead.model_validate(driver)
