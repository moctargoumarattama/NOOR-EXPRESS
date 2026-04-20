from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db_session
from app.services.admin_service import (
    AdminAlreadyExistsError,
    create_admin,
    get_all_reports,
    get_all_rides,
    get_all_users,
    get_dashboard_stats,
    login_admin,
    require_admin,
)
from app.schemas.driver_profile import DriverRejectRequest
from app.services.driver_profile_service import (
    get_pending_drivers,
    reject_driver,
    verify_driver,
)
from app.services.ride_request_service import get_top_drivers

router = APIRouter(prefix="/admin", tags=["admin"])


class AdminLoginRequest(BaseModel):
    username: str
    password: str


class AdminInitRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=4)


class AdminTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


@router.post("/auth/login", response_model=AdminTokenResponse)
async def admin_login_endpoint(
    login_in: AdminLoginRequest,
    session: AsyncSession = Depends(get_db_session),
) -> AdminTokenResponse:
    token = await login_admin(session, login_in.username, login_in.password)
    return AdminTokenResponse(access_token=token)


@router.post("/init", response_model=AdminTokenResponse, status_code=status.HTTP_201_CREATED)
async def admin_init_endpoint(
    init_in: AdminInitRequest,
    session: AsyncSession = Depends(get_db_session),
) -> AdminTokenResponse:
    try:
        admin = await create_admin(session, init_in.username, init_in.password)
    except AdminAlreadyExistsError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    token = await login_admin(session, admin.username, init_in.password)
    return AdminTokenResponse(access_token=token)


@router.get("/users")
async def admin_users_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_users(session)


@router.get("/rides")
async def admin_rides_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_rides(session)


@router.get("/reports")
async def admin_reports_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_reports(session)


@router.get("/dashboard")
async def admin_dashboard_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    stats = await get_dashboard_stats(session)
    stats["top_drivers"] = [
        driver.model_dump() for driver in await get_top_drivers(session, limit=5)
    ]
    return stats


@router.get("/drivers/pending")
async def admin_pending_drivers_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_pending_drivers(session)


@router.post("/drivers/{user_id}/verify")
async def admin_verify_driver_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    profile = await verify_driver(session, user_id)
    return {
        "user_id": profile.user_id,
        "verification_status": profile.verification_status.value,
    }


@router.post("/drivers/{user_id}/reject")
async def admin_reject_driver_endpoint(
    user_id: int,
    reject_in: DriverRejectRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    profile = await reject_driver(session, user_id, reject_in.reason)
    return {
        "user_id": profile.user_id,
        "verification_status": profile.verification_status.value,
        "rejection_reason": profile.rejection_reason,
    }
