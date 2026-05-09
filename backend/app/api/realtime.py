import asyncio
from contextlib import suppress
from typing import TypeVar

from pydantic import ValidationError
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.messages import Messages
from app.core.security import verify_token
from app.db.database import AsyncSessionLocal
from app.models.user import DriverStatus, User, UserRole
from app.realtime.gateway import realtime_gateway
from app.realtime.schemas import (
    ConnectedDriverLocation,
    DriverPositionNotification,
    DriverLocationUpdate,
    NearbyDriverLocation,
)
from app.services.ride_request_service import (
    get_fresh_driver_position_from_database,
    persist_driver_last_known_position,
)
from app.services.user_service import get_drivers_by_status, update_driver_status

router = APIRouter()
KEEPALIVE_SECONDS = 30
WS_CLOSE_UNAUTHENTICATED = 4001
WS_CLOSE_FORBIDDEN = 4003
DriverLocationT = TypeVar(
    "DriverLocationT",
    ConnectedDriverLocation,
    NearbyDriverLocation,
)


async def send_keepalive(websocket: WebSocket) -> None:
    while True:
        await asyncio.sleep(KEEPALIVE_SECONDS)
        await websocket.send_json({"type": "ping"})


async def stop_keepalive(task: asyncio.Task[None]) -> None:
    task.cancel()
    with suppress(asyncio.CancelledError):
        await task


async def authenticate_websocket_user(
    websocket: WebSocket,
    expected_user_id: int,
    expected_role: UserRole,
) -> User | None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=WS_CLOSE_UNAUTHENTICATED)
        return None

    async with AsyncSessionLocal() as session:
        user = await verify_token(token, session)

    if user is None:
        await websocket.close(code=WS_CLOSE_UNAUTHENTICATED)
        return None

    if user.id != expected_user_id or user.role != expected_role:
        await websocket.close(code=WS_CLOSE_FORBIDDEN)
        return None

    return user


async def _filter_available_driver_locations(
    session,
    locations: list[DriverLocationT],
) -> list[DriverLocationT]:
    if not locations:
        return []

    available_drivers = await get_drivers_by_status(
        session,
        driver_ids=[location.driver_id for location in locations],
        driver_status=DriverStatus.ONLINE,
        is_available=True,
    )
    available_driver_ids = {driver.id for driver in available_drivers}
    return [
        location
        for location in locations
        if location.driver_id in available_driver_ids
    ]


async def _driver_has_store_position(driver_id: int) -> bool:
    connected_drivers = await realtime_gateway.get_connected_drivers()
    return any(driver.driver_id == driver_id for driver in connected_drivers)


async def _restore_driver_position_from_database_if_fresh(driver_id: int) -> None:
    if await _driver_has_store_position(driver_id):
        return
    async with AsyncSessionLocal() as session:
        position = await get_fresh_driver_position_from_database(
            session,
            driver_id,
        )
    if position is None:
        return
    await realtime_gateway.update_position(
        driver_id,
        DriverLocationUpdate(latitude=position[0], longitude=position[1]),
    )


async def _persist_driver_position_background(
    driver_id: int,
    location: DriverLocationUpdate,
) -> None:
    try:
        async with AsyncSessionLocal() as session:
            await persist_driver_last_known_position(
                session,
                driver_id=driver_id,
                latitude=location.latitude,
                longitude=location.longitude,
            )
    except Exception:
        # Do not break realtime flow if persistence fails in the background.
        return


@router.websocket("/ws/drivers/{driver_id}")
async def driver_websocket(websocket: WebSocket, driver_id: int) -> None:
    driver = await authenticate_websocket_user(
        websocket,
        expected_user_id=driver_id,
        expected_role=UserRole.DRIVER,
    )
    if driver is None:
        return

    async with AsyncSessionLocal() as session:
        persisted_driver = await session.get(User, driver_id)
        if (
            persisted_driver is not None
            and persisted_driver.driver_status != DriverStatus.PAUSED
        ):
            await update_driver_status(
                session,
                driver_id,
                DriverStatus.ONLINE,
                is_available=True,
            )

    await realtime_gateway.connect_driver(driver_id, websocket)
    await _restore_driver_position_from_database_if_fresh(driver_id)
    keepalive_task = asyncio.create_task(send_keepalive(websocket))

    try:
        while True:
            payload = await websocket.receive_json()
            if payload.get("type") == "pong":
                continue
            try:
                location = DriverLocationUpdate.model_validate(payload)
            except ValidationError:
                await websocket.send_json({"detail": Messages.FORBIDDEN})
                continue

            await realtime_gateway.update_position(driver_id, location)
            asyncio.create_task(
                _persist_driver_position_background(driver_id, location)
            )
            await realtime_gateway.send_driver_position_notification_to_clients(
                DriverPositionNotification(
                    driver_id=driver_id,
                    latitude=location.latitude,
                    longitude=location.longitude,
                )
            )
            await websocket.send_json({"status": "ok"})
    except WebSocketDisconnect:
        pass
    finally:
        await stop_keepalive(keepalive_task)
        await realtime_gateway.disconnect_driver(driver_id)
        async with AsyncSessionLocal() as session:
            await update_driver_status(
                session,
                driver_id,
                DriverStatus.OFFLINE,
                is_available=False,
            )


@router.websocket("/ws/clients/{client_id}")
async def client_websocket(websocket: WebSocket, client_id: int) -> None:
    client = await authenticate_websocket_user(
        websocket,
        expected_user_id=client_id,
        expected_role=UserRole.CLIENT,
    )
    if client is None:
        return

    await realtime_gateway.connect_client(client_id, websocket)
    keepalive_task = asyncio.create_task(send_keepalive(websocket))

    try:
        while True:
            payload = await websocket.receive_json()
            if payload.get("type") == "pong":
                continue
    except WebSocketDisconnect:
        pass
    finally:
        await stop_keepalive(keepalive_task)
        realtime_gateway.disconnect_client(client_id)


@router.get("/realtime/drivers", response_model=list[ConnectedDriverLocation])
async def get_connected_drivers() -> list[ConnectedDriverLocation]:
    locations = await realtime_gateway.get_connected_drivers()
    if not locations:
        return []

    async with AsyncSessionLocal() as session:
        return await _filter_available_driver_locations(session, locations)


@router.get("/realtime/drivers/nearby", response_model=list[NearbyDriverLocation])
async def get_nearby_drivers(
    latitude: float,
    longitude: float,
    max_distance_km: float,
) -> list[NearbyDriverLocation]:
    locations = await realtime_gateway.get_nearby_drivers(
        latitude=latitude,
        longitude=longitude,
        max_distance_km=max_distance_km,
        limit=50,
    )
    if not locations:
        return []

    async with AsyncSessionLocal() as session:
        return await _filter_available_driver_locations(session, locations)
