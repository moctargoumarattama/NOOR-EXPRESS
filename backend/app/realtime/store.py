from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime, timedelta

from app.realtime.schemas import DriverLocationUpdate, StoredDriverLocation


class RealtimeStore(ABC):
    @abstractmethod
    def upsert_driver_position(
        self,
        driver_id: int,
        location: DriverLocationUpdate,
    ) -> None:
        raise NotImplementedError

    @abstractmethod
    def list_driver_positions(self) -> list[StoredDriverLocation]:
        raise NotImplementedError

    @abstractmethod
    def remove_driver(self, driver_id: int) -> None:
        raise NotImplementedError

    @abstractmethod
    def set_driver_status(self, driver_id: int, status: str) -> None:
        raise NotImplementedError

    @abstractmethod
    def get_driver_status(self, driver_id: int) -> str | None:
        raise NotImplementedError

    @abstractmethod
    def cleanup_expired_drivers(self, expiration_seconds: int) -> list[int]:
        raise NotImplementedError


class InMemoryRealtimeStore(RealtimeStore):
    def __init__(self) -> None:
        self._driver_positions: dict[int, StoredDriverLocation] = {}
        self._driver_statuses: dict[int, str] = {}

    def upsert_driver_position(
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

    def list_driver_positions(self) -> list[StoredDriverLocation]:
        return list(self._driver_positions.values())

    def remove_driver(self, driver_id: int) -> None:
        self._driver_positions.pop(driver_id, None)
        self._driver_statuses.pop(driver_id, None)

    def set_driver_status(self, driver_id: int, status: str) -> None:
        self._driver_statuses[driver_id] = status

    def get_driver_status(self, driver_id: int) -> str | None:
        return self._driver_statuses.get(driver_id)

    def cleanup_expired_drivers(self, expiration_seconds: int) -> list[int]:
        expired_driver_ids = [
            driver_id
            for driver_id, driver_location in self._driver_positions.items()
            if self._is_position_expired(driver_location, expiration_seconds)
        ]
        for driver_id in expired_driver_ids:
            self.remove_driver(driver_id)
        return expired_driver_ids

    @staticmethod
    def _is_position_expired(
        driver_location: StoredDriverLocation,
        expiration_seconds: int,
    ) -> bool:
        expires_at = driver_location.updated_at + timedelta(seconds=expiration_seconds)
        return datetime.now() >= expires_at


realtime_store: RealtimeStore = InMemoryRealtimeStore()
