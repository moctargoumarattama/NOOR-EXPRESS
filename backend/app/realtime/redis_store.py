from app.realtime.schemas import DriverLocationUpdate, StoredDriverLocation
from app.realtime.store import RealtimeStore


class RedisRealtimeStore(RealtimeStore):
    def __init__(self, redis_url: str) -> None:
        self.redis_url = redis_url

    def upsert_driver_position(
        self,
        driver_id: int,
        location: DriverLocationUpdate,
    ) -> None:
        raise NotImplementedError("Redis realtime store is not enabled yet")

    def list_driver_positions(self) -> list[StoredDriverLocation]:
        raise NotImplementedError("Redis realtime store is not enabled yet")

    def remove_driver(self, driver_id: int) -> None:
        raise NotImplementedError("Redis realtime store is not enabled yet")

    def set_driver_status(self, driver_id: int, status: str) -> None:
        raise NotImplementedError("Redis realtime store is not enabled yet")

    def get_driver_status(self, driver_id: int) -> str | None:
        raise NotImplementedError("Redis realtime store is not enabled yet")

    def cleanup_expired_drivers(self, expiration_seconds: int) -> list[int]:
        raise NotImplementedError("Redis realtime store is not enabled yet")
