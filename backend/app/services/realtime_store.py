from __future__ import annotations

from datetime import datetime, timezone
import json
from typing import Any

from app.services.redis_client import get_redis_client


_MISSING = object()


class RedisRealtimeService:
    POSITION_TTL_SECONDS = 30
    ONLINE_TTL_SECONDS = 60
    GEO_SEARCH_LIMIT = 50
    GEO_KEY = "drivers:geo"

    def __init__(self, client: Any | None = _MISSING) -> None:
        self._client = get_redis_client() if client is _MISSING else client

    async def set_driver_position(self, driver_id: int, lat: float, lng: float) -> None:
        payload = json.dumps(
            {
                "driver_id": driver_id,
                "lat": lat,
                "lng": lng,
                "ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            }
        )

        if not await self._write_command(
            ["SET", self._position_key(driver_id), payload, "EX", str(self.POSITION_TTL_SECONDS)]
        ):
            return

        if not await self._write_command(
            ["SET", self._online_key(driver_id), "1", "EX", str(self.ONLINE_TTL_SECONDS)]
        ):
            return

        await self._write_command(
            ["GEOADD", self.GEO_KEY, str(lng), str(lat), str(driver_id)]
        )

    async def get_driver_position(self, driver_id: int) -> dict[str, Any] | None:
        raw_payload = await self._read_command(["GET", self._position_key(driver_id)])
        return self._decode_position_payload(raw_payload)

    async def is_driver_online(self, driver_id: int) -> bool:
        exists = await self._read_command(["EXISTS", self._online_key(driver_id)])
        return bool(exists)

    async def find_nearby_drivers(
        self,
        *,
        lat: float,
        lng: float,
        radius_km: float,
    ) -> list[dict[str, Any]]:
        members = await self._read_command(
            [
                "GEOSEARCH",
                self.GEO_KEY,
                "FROMLONLAT",
                str(lng),
                str(lat),
                "BYRADIUS",
                str(radius_km),
                "km",
                "COUNT",
                str(self.GEO_SEARCH_LIMIT),
                "ASC",
            ]
        )
        driver_ids = self._coerce_driver_ids(members)

        nearby_drivers: list[dict[str, Any]] = []
        for driver_id in driver_ids:
            payload = await self.get_driver_position(driver_id)
            if payload is not None:
                nearby_drivers.append(payload)

        return nearby_drivers

    async def list_driver_ids(self) -> list[int]:
        members = await self._read_command(["ZRANGE", self.GEO_KEY, "0", "-1"])
        return self._coerce_driver_ids(members)

    async def remove_driver(self, driver_id: int) -> None:
        if not await self._write_command(
            ["DEL", self._position_key(driver_id), self._online_key(driver_id)]
        ):
            return

        await self._write_command(["ZREM", self.GEO_KEY, str(driver_id)])

    async def _read_command(self, command: list[str]) -> Any | None:
        if self._client is None:
            return None

        try:
            return await self._client.execute(command)
        except Exception:
            return None

    async def _write_command(self, command: list[str]) -> bool:
        if self._client is None:
            return False

        try:
            await self._client.execute(command)
            return True
        except Exception:
            return False

    @staticmethod
    def _position_key(driver_id: int) -> str:
        return f"driver:{driver_id}:pos"

    @staticmethod
    def _online_key(driver_id: int) -> str:
        return f"driver:{driver_id}:online"

    @staticmethod
    def _coerce_driver_ids(raw_members: Any) -> list[int]:
        if not isinstance(raw_members, list):
            return []

        driver_ids: list[int] = []
        for item in raw_members:
            member = item[0] if isinstance(item, list) and item else item
            try:
                driver_ids.append(int(member))
            except (TypeError, ValueError):
                continue
        return driver_ids

    @staticmethod
    def _decode_position_payload(raw_payload: Any) -> dict[str, Any] | None:
        if raw_payload is None:
            return None

        payload: dict[str, Any]
        if isinstance(raw_payload, bytes):
            try:
                payload = json.loads(raw_payload.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                return None
        elif isinstance(raw_payload, str):
            try:
                payload = json.loads(raw_payload)
            except json.JSONDecodeError:
                return None
        elif isinstance(raw_payload, dict):
            payload = raw_payload
        else:
            return None

        try:
            return {
                "driver_id": int(payload["driver_id"]),
                "lat": float(payload["lat"]),
                "lng": float(payload["lng"]),
                "ts": str(payload["ts"]),
            }
        except (KeyError, TypeError, ValueError):
            return None
