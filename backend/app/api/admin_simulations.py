from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db_session
from app.services.admin_service import require_admin
from app.services.admin_simulation_service import (
    SimulationDisabledError,
    SimulationUnsafeTargetError,
    get_simulation_status,
    start_client_simulation,
    start_driver_simulation,
    stop_simulation,
)


router = APIRouter(prefix="/admin/simulations", tags=["admin_simulations"])


class AdminSimulationRequest(BaseModel):
    ride_id: int | None = None
    allow_real_users: bool | None = None


def _disabled_response(exc: SimulationDisabledError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=str(exc),
    )


def _unsafe_response(exc: SimulationUnsafeTargetError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=str(exc),
    )


@router.post("/client")
async def admin_client_simulation_endpoint(
    payload: AdminSimulationRequest | None = None,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        return await start_client_simulation(
            session,
            ride_id=payload.ride_id if payload is not None else None,
            allow_real_users=bool(payload.allow_real_users) if payload is not None else False,
        )
    except SimulationDisabledError as exc:
        raise _disabled_response(exc) from exc
    except SimulationUnsafeTargetError as exc:
        raise _unsafe_response(exc) from exc


@router.post("/driver")
async def admin_driver_simulation_endpoint(
    payload: AdminSimulationRequest | None = None,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        return await start_driver_simulation(
            session,
            allow_real_users=(
                payload.allow_real_users
                if payload is not None and payload.allow_real_users is not None
                else True
            ),
        )
    except SimulationDisabledError as exc:
        raise _disabled_response(exc) from exc
    except SimulationUnsafeTargetError as exc:
        raise _unsafe_response(exc) from exc


@router.post("/stop")
async def admin_stop_simulation_endpoint(
    _admin: dict = Depends(require_admin),
) -> dict:
    try:
        return await stop_simulation()
    except SimulationDisabledError as exc:
        raise _disabled_response(exc) from exc


@router.get("/status")
async def admin_simulation_status_endpoint(
    _admin: dict = Depends(require_admin),
) -> dict:
    try:
        return get_simulation_status()
    except SimulationDisabledError as exc:
        raise _disabled_response(exc) from exc
