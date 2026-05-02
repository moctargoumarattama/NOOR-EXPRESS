from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_driver
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.driver_wallet import DriverDashboardStatsRead, DriverWalletSummaryRead
from app.schemas.user import (
    DriverAvailabilityUpdate,
    DriverProfileUpdate,
    DriverRadiusUpdate,
    DriverStatusUpdate,
    UserRead,
)
from app.services.user_service import (
    get_driver_profile,
    update_driver_availability,
    update_driver_max_radius,
    update_driver_presence_status,
    update_driver_profile,
)
from app.services.wallet_service import (
    get_driver_dashboard_stats,
    get_driver_wallet_summary,
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


@router.patch("/me/radius", response_model=UserRead)
async def update_driver_radius_endpoint(
    radius_in: DriverRadiusUpdate,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    driver = await update_driver_max_radius(
        session,
        current_user.id,
        radius_in,
    )
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver not found",
        )
    return UserRead.model_validate(driver)


@router.patch("/me/status", response_model=UserRead)
async def update_driver_status_endpoint(
    status_in: DriverStatusUpdate,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    driver = await update_driver_presence_status(
        session,
        current_user.id,
        status_in,
    )
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver not found",
        )
    return UserRead.model_validate(driver)


@router.get("/me/wallet", response_model=DriverWalletSummaryRead)
async def get_driver_wallet_summary_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> DriverWalletSummaryRead:
    return await get_driver_wallet_summary(session, current_user.id)


@router.get("/me/stats", response_model=DriverDashboardStatsRead)
async def get_driver_dashboard_stats_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> DriverDashboardStatsRead:
    return await get_driver_dashboard_stats(session, current_user.id)
