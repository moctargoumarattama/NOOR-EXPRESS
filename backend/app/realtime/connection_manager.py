from math import asin, cos, radians, sin, sqrt

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect

from app.realtime.registry import ConnectionRegistry, connection_registry
from app.realtime.schemas import (
    ConnectedDriverLocation,
    DriverPositionNotification,
    DriverLocationUpdate,
    NearbyDriverLocation,
    NewRideRequestNotification,
    NewOfferNotification,
    OfferAcceptedNotification,
    OfferRejectedNotification,
    RideMessageNotification,
    RideStatusNotification,
)
from app.realtime.store import RealtimeStore, realtime_store


class RealtimeConnectionManager:
    DRIVER_POSITION_EXPIRATION_SECONDS = 30

    def __init__(
        self,
        connection_registry: ConnectionRegistry,
        presence_store: RealtimeStore,
    ) -> None:
        self._connection_registry = connection_registry
        self._presence_store = presence_store

    async def connect_driver(self, driver_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connection_registry.set_driver_connection(driver_id, websocket)
        await self._presence_store.set_driver_status(driver_id, "connected")

    async def connect_client(self, client_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connection_registry.set_client_connection(client_id, websocket)

    async def update_position(self, driver_id: int, location: DriverLocationUpdate) -> None:
        await self._presence_store.upsert_driver_position(driver_id, location)
        await self._presence_store.set_driver_status(driver_id, "connected")

    async def send_driver_position_notification_to_clients(
        self,
        notification: DriverPositionNotification,
    ) -> None:
        disconnected_client_ids: list[int] = []

        for client_id, websocket in self._connection_registry.list_client_connections():
            try:
                await websocket.send_json(notification.model_dump())
            except (RuntimeError, WebSocketDisconnect):
                disconnected_client_ids.append(client_id)

        for client_id in disconnected_client_ids:
            self.disconnect_client(client_id)

    async def disconnect_driver(self, driver_id: int) -> None:
        self._connection_registry.remove_driver_connection(driver_id)
        await self._presence_store.remove_driver(driver_id)

    def disconnect_client(self, client_id: int) -> None:
        self._connection_registry.remove_client_connection(client_id)

    async def get_connected_drivers(self) -> list[ConnectedDriverLocation]:
        await self._cleanup_expired_drivers()
        return [
            ConnectedDriverLocation(
                driver_id=driver.driver_id,
                latitude=driver.latitude,
                longitude=driver.longitude,
            )
            for driver in await self._presence_store.list_driver_positions()
        ]

    def is_driver_connected(self, driver_id: int) -> bool:
        return self._connection_registry.has_driver_connection(driver_id)

    async def get_nearby_drivers(
        self,
        latitude: float,
        longitude: float,
        max_distance_km: float,
        limit: int | None = None,
    ) -> list[NearbyDriverLocation]:
        await self._cleanup_expired_drivers()
        return await self._presence_store.get_nearby_drivers(
            latitude=latitude,
            longitude=longitude,
            max_distance_km=max_distance_km,
            limit=limit,
        )

    async def _cleanup_expired_drivers(self) -> None:
        expired_driver_ids = await self._presence_store.cleanup_expired_drivers(
            self.DRIVER_POSITION_EXPIRATION_SECONDS
        )
        for driver_id in expired_driver_ids:
            self._connection_registry.remove_driver_connection(driver_id)

    async def send_ride_status_notification(
        self,
        client_id: int,
        notification: RideStatusNotification,
    ) -> None:
        websocket = self._connection_registry.get_client_connection(client_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            self.disconnect_client(client_id)

    async def send_ride_status_notification_to_driver(
        self,
        driver_id: int,
        notification: RideStatusNotification,
    ) -> None:
        websocket = self._connection_registry.get_driver_connection(driver_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            await self.disconnect_driver(driver_id)

    async def send_new_ride_request_notification(
        self,
        driver_id: int,
        notification: NewRideRequestNotification,
    ) -> None:
        websocket = self._connection_registry.get_driver_connection(driver_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            await self.disconnect_driver(driver_id)

    async def send_new_offer_notification(
        self,
        client_id: int,
        notification: NewOfferNotification,
    ) -> None:
        websocket = self._connection_registry.get_client_connection(client_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            self.disconnect_client(client_id)

    async def send_offer_accepted_notification(
        self,
        driver_id: int,
        notification: OfferAcceptedNotification,
    ) -> None:
        websocket = self._connection_registry.get_driver_connection(driver_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            await self.disconnect_driver(driver_id)

    async def send_offer_rejected_notification(
        self,
        driver_id: int,
        notification: OfferRejectedNotification,
    ) -> None:
        websocket = self._connection_registry.get_driver_connection(driver_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            await self.disconnect_driver(driver_id)

    async def send_ride_message_notification(
        self,
        client_id: int,
        notification: RideMessageNotification,
    ) -> None:
        websocket = self._connection_registry.get_client_connection(client_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            self.disconnect_client(client_id)

    async def send_ride_message_notification_to_driver(
        self,
        driver_id: int,
        notification: RideMessageNotification,
    ) -> None:
        websocket = self._connection_registry.get_driver_connection(driver_id)
        if websocket is None:
            return

        try:
            await websocket.send_json(notification.model_dump())
        except (RuntimeError, WebSocketDisconnect):
            await self.disconnect_driver(driver_id)

    @staticmethod
    def _calculate_distance_km(
        latitude_1: float,
        longitude_1: float,
        latitude_2: float,
        longitude_2: float,
    ) -> float:
        earth_radius_km = 6371.0

        latitude_1_rad = radians(latitude_1)
        longitude_1_rad = radians(longitude_1)
        latitude_2_rad = radians(latitude_2)
        longitude_2_rad = radians(longitude_2)

        latitude_delta = latitude_2_rad - latitude_1_rad
        longitude_delta = longitude_2_rad - longitude_1_rad

        haversine = (
            sin(latitude_delta / 2) ** 2
            + cos(latitude_1_rad) * cos(latitude_2_rad) * sin(longitude_delta / 2) ** 2
        )
        arc = 2 * asin(sqrt(haversine))
        return earth_radius_km * arc


manager = RealtimeConnectionManager(
    connection_registry=connection_registry,
    presence_store=realtime_store,
)
