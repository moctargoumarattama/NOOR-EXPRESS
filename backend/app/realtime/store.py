from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime, timedelta
from math import asin, cos, radians, sin, sqrt

from app.core.config import settings
from app.realtime.schemas import (
    DriverLocationUpdate,
    NearbyDriverLocation,
    StoredDriverLocation,
)
from app.services.realtime_store import RedisRealtimeService


class RealtimeStore(ABC):
    @abstractmethod
    async def upsert_driver_position(
        self,
        driver_id: int,
        location: DriverLocationUpdate,
    ) -> None:
        raise NotImplementedError

    @abstractmethod
    async def list_driver_positions(self) -> list[StoredDriverLocation]:
        raise NotImplementedError

    @abstractmethod
    async def get_nearby_drivers(
        self,
        latitude: float,
        longitude: float,
        max_distance_km: float,
        limit: int | None = None,
    ) -> list[NearbyDriverLocation]:
        raise NotImplementedError

    @abstractmethod
    async def remove_driver(self, driver_id: int) -> None:
        raise NotImplementedError

    @abstractmethod
    async def set_driver_status(self, driver_id: int, status: str) -> None:
        raise NotImplementedError

    @abstractmethod
    async def get_driver_status(self, driver_id: int) -> str | None:
        raise NotImplementedError

    @abstractmethod
    async def cleanup_expired_drivers(self, expiration_seconds: int) -> list[int]:
        raise NotImplementedError


class InMemoryRealtimeStore(RealtimeStore):
    def __init__(self) -> None:
        self._driver_positions: dict[int, StoredDriverLocation] = {}
        self._driver_statuses: dict[int, str] = {}

    async def upsert_driver_position(
        self,
        driver_id: int,
        location: DriverLocationUpdate,
    ) -> None:
        self._driver_positions[driver_id] = StoredDriverLocation(
            driver_id=driver_id,
            latitude=location.latitude,
            longitude=location.longitude,
            updated_at=datetime.now(),
        )

    async def list_driver_positions(self) -> list[StoredDriverLocation]:
        return list(self._driver_positions.values())

    async def get_nearby_drivers(
        self,
        latitude: float,
        longitude: float,
        max_distance_km: float,
        limit: int | None = None,
    ) -> list[NearbyDriverLocation]:
        nearby_drivers: list[NearbyDriverLocation] = []

        for driver in self._driver_positions.values():
            distance_km = _calculate_distance_km(
                latitude_1=latitude,
                longitude_1=longitude,
                latitude_2=driver.latitude,
                longitude_2=driver.longitude,
            )
            if distance_km <= max_distance_km:
                nearby_drivers.append(
                    NearbyDriverLocation(
                        driver_id=driver.driver_id,
                        latitude=driver.latitude,
                        longitude=driver.longitude,
                        distance_km=round(distance_km, 3),
                    )
                )

        nearby_drivers.sort(key=lambda driver: driver.distance_km)
        if limit is not None:
            return nearby_drivers[:limit]
        return nearby_drivers

    async def remove_driver(self, driver_id: int) -> None:
        self._driver_positions.pop(driver_id, None)
        self._driver_statuses.pop(driver_id, None)

    async def set_driver_status(self, driver_id: int, status: str) -> None:
        self._driver_statuses[driver_id] = status

    async def get_driver_status(self, driver_id: int) -> str | None:
        return self._driver_statuses.get(driver_id)

    async def cleanup_expired_drivers(self, expiration_seconds: int) -> list[int]:
        expired_driver_ids = [
            driver_id
            for driver_id, driver_location in self._driver_positions.items()
            if self._is_position_expired(driver_location, expiration_seconds)
        ]
        for driver_id in expired_driver_ids:
            await self.remove_driver(driver_id)
        return expired_driver_ids

    @staticmethod
    def _is_position_expired(
        driver_location: StoredDriverLocation,
        expiration_seconds: int,
    ) -> bool:
        expires_at = driver_location.updated_at + timedelta(seconds=expiration_seconds)
        return datetime.now() >= expires_at


class RedisRealtimeStore(RealtimeStore):
    def __init__(self, redis_service: RedisRealtimeService | None = None) -> None:
        self._redis_service = redis_service or RedisRealtimeService()

    async def upsert_driver_position(
        self,
        driver_id: int,
        location: DriverLocationUpdate,
    ) -> None:
        await self._redis_service.set_driver_position(
            driver_id=driver_id,
            lat=location.latitude,
            lng=location.longitude,
        )

    async def list_driver_positions(self) -> list[StoredDriverLocation]:
        driver_ids = await self._redis_service.list_driver_ids()
        positions: list[StoredDriverLocation] = []

        for driver_id in driver_ids:
            payload = await self._redis_service.get_driver_position(driver_id)
            if payload is None:
                continue
            positions.append(_payload_to_stored_location(payload))

        return positions

    async def get_nearby_drivers(
        self,
        latitude: float,
        longitude: float,
        max_distance_km: float,
        limit: int | None = None,
    ) -> list[NearbyDriverLocation]:
        payloads = await self._redis_service.find_nearby_drivers(
            lat=latitude,
            lng=longitude,
            radius_km=max_distance_km,
        )
        nearby_drivers: list[NearbyDriverLocation] = []

        for payload in payloads:
            distance_km = _calculate_distance_km(
                latitude_1=latitude,
                longitude_1=longitude,
                latitude_2=float(payload["lat"]),
                longitude_2=float(payload["lng"]),
            )
            if distance_km <= max_distance_km:
                nearby_drivers.append(
                    NearbyDriverLocation(
                        driver_id=int(payload["driver_id"]),
                        latitude=float(payload["lat"]),
                        longitude=float(payload["lng"]),
                        distance_km=round(distance_km, 3),
                    )
                )

        nearby_drivers.sort(key=lambda driver: driver.distance_km)
        if limit is not None:
            return nearby_drivers[:limit]
        return nearby_drivers

    async def remove_driver(self, driver_id: int) -> None:
        await self._redis_service.remove_driver(driver_id)

    async def set_driver_status(self, driver_id: int, status: str) -> None:
        return None

    async def get_driver_status(self, driver_id: int) -> str | None:
        if await self._redis_service.is_driver_online(driver_id):
            return "connected"
        return None

    async def cleanup_expired_drivers(self, expiration_seconds: int) -> list[int]:
        return []


def build_realtime_store(
    *,
    backend: str | None = None,
    redis_service: RedisRealtimeService | None = None,
) -> RealtimeStore:
    selected_backend = (backend or settings.REALTIME_STORE_BACKEND).strip().lower()
    if selected_backend == "redis":
        return RedisRealtimeStore(redis_service=redis_service)
    return InMemoryRealtimeStore()


def _payload_to_stored_location(payload: dict[str, object]) -> StoredDriverLocation:
    updated_at = datetime.fromisoformat(str(payload["ts"]).replace("Z", "+00:00"))
    return StoredDriverLocation(
        driver_id=int(payload["driver_id"]),
        latitude=float(payload["lat"]),
        longitude=float(payload["lng"]),
        updated_at=updated_at,
    )


def _calculate_distance_km(
    *,
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


realtime_store: RealtimeStore = build_realtime_store()
