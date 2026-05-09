from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.messages import Messages
from app.core.security import get_current_driver
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.driver_wallet import DriverDashboardStatsRead
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
    WithdrawalRequestAmountTooLowError,
    WithdrawalRequestNotFoundError,
    WithdrawalRequestPendingConflictError,
    WithdrawalRequestStateConflictError,
    get_driver_dashboard_stats,
    get_driver_wallet_summary,
    create_driver_withdrawal_request,
    list_driver_withdrawal_requests,
    cancel_driver_withdrawal_request,
)

router = APIRouter(prefix="/drivers", tags=["drivers"])


class DriverWithdrawalCreateRequest(BaseModel):
    driver_note: str | None = Field(default=None, max_length=200)


@router.get("/me/profile", response_model=UserRead)
async def get_driver_profile_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    driver = await get_driver_profile(session, current_user.id)
    if driver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=Messages.DRIVER_NOT_FOUND,
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
            detail=Messages.DRIVER_NOT_FOUND,
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
            detail=Messages.DRIVER_NOT_FOUND,
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
            detail=Messages.DRIVER_NOT_FOUND,
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
            detail=Messages.DRIVER_NOT_FOUND,
        )
    return UserRead.model_validate(driver)


@router.get("/me/wallet")
async def get_driver_wallet_summary_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, object]:
    return await get_driver_wallet_summary(session, current_user.id)


@router.get("/me/stats", response_model=DriverDashboardStatsRead)
async def get_driver_dashboard_stats_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> DriverDashboardStatsRead:
    return await get_driver_dashboard_stats(session, current_user.id)


@router.post("/me/withdrawal-requests", status_code=status.HTTP_201_CREATED)
async def create_driver_withdrawal_request_endpoint(
    request_in: DriverWithdrawalCreateRequest,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, object]:
    try:
        return await create_driver_withdrawal_request(
            session,
            driver_id=current_user.id,
            driver_note=request_in.driver_note,
        )
    except WithdrawalRequestAmountTooLowError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except WithdrawalRequestPendingConflictError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc


@router.get("/me/withdrawal-requests")
async def list_driver_withdrawal_requests_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=10, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
) -> dict[str, object]:
    return await list_driver_withdrawal_requests(
        session,
        driver_id=current_user.id,
        limit=limit,
        offset=offset,
    )


@router.delete(
    "/me/withdrawal-requests/{withdrawal_request_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def cancel_driver_withdrawal_request_endpoint(
    withdrawal_request_id: str,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    try:
        await cancel_driver_withdrawal_request(
            session,
            driver_id=current_user.id,
            withdrawal_request_id=withdrawal_request_id,
        )
    except WithdrawalRequestNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    except WithdrawalRequestStateConflictError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
