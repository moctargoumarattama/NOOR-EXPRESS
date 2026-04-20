import asyncio
from contextlib import suppress

from pydantic import ValidationError
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

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
from app.services.user_service import update_driver_status

router = APIRouter()
KEEPALIVE_SECONDS = 30
WS_CLOSE_UNAUTHENTICATED = 4001
WS_CLOSE_FORBIDDEN = 4003


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
        await update_driver_status(session, driver_id, DriverStatus.ONLINE)

    await realtime_gateway.connect_driver(driver_id, websocket)
    keepalive_task = asyncio.create_task(send_keepalive(websocket))

    try:
        while True:
            payload = await websocket.receive_json()
            if payload.get("type") == "pong":
                continue
            try:
                location = DriverLocationUpdate.model_validate(payload)
            except ValidationError:
                await websocket.send_json({"detail": "Invalid location payload"})
                continue

            realtime_gateway.update_position(driver_id, location)
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
        realtime_gateway.disconnect_driver(driver_id)
        async with AsyncSessionLocal() as session:
            await update_driver_status(session, driver_id, DriverStatus.OFFLINE)


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
    return realtime_gateway.get_connected_drivers()


@router.get("/realtime/drivers/nearby", response_model=list[NearbyDriverLocation])
async def get_nearby_drivers(
    latitude: float,
    longitude: float,
    max_distance_km: float,
) -> list[NearbyDriverLocation]:
    return realtime_gateway.get_nearby_drivers(
        latitude=latitude,
        longitude=longitude,
        max_distance_km=max_distance_km,
    )
