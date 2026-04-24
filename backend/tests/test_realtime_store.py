from datetime import datetime, timedelta
from pathlib import Path
import json
import sys
import unittest


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.realtime.schemas import DriverLocationUpdate
from app.realtime.store import InMemoryRealtimeStore, RedisRealtimeStore, build_realtime_store
from app.services.redis_client import build_redis_client
from app.services.realtime_store import RedisRealtimeService


class FakeAsyncRedisClient:
    def __init__(self) -> None:
        self.commands: list[list[str]] = []
        self._strings: dict[str, str] = {}
        self._geo_members: dict[str, tuple[float, float]] = {}
        self._forced_geosearch_members: list[str] | None = None

    async def execute(self, command: list[str]):
        self.commands.append(command)
        name = command[0].upper()

        if name == "SET":
            self._strings[command[1]] = command[2]
            return "OK"

        if name == "GET":
            return self._strings.get(command[1])

        if name == "EXISTS":
            return 1 if command[1] in self._strings else 0

        if name == "DEL":
            deleted = 0
            for key in command[1:]:
                if key in self._strings:
                    deleted += 1
                    self._strings.pop(key, None)
            return deleted

        if name == "GEOADD":
            self._geo_members[str(command[4])] = (float(command[3]), float(command[2]))
            return 1

        if name == "GEOSEARCH":
            if self._forced_geosearch_members is not None:
                return self._forced_geosearch_members

            limit = 50
            if "COUNT" in command:
                limit = int(command[command.index("COUNT") + 1])
            return list(self._geo_members.keys())[:limit]

        if name == "ZREM":
            self._geo_members.pop(str(command[2]), None)
            return 1

        if name == "ZRANGE":
            return list(self._geo_members.keys())

        raise AssertionError(f"Unsupported fake Redis command: {command}")


class RedisClientFactoryTest(unittest.TestCase):
    def test_build_redis_client_returns_none_when_backend_is_memory(self) -> None:
        client = build_redis_client(
            backend="memory",
            url="https://example.upstash.io",
            token="token",
        )

        self.assertIsNone(client)

    def test_build_redis_client_returns_none_when_credentials_are_blank(self) -> None:
        client = build_redis_client(
            backend="redis",
            url="",
            token="",
        )

        self.assertIsNone(client)

    def test_build_realtime_store_defaults_to_memory_backend(self) -> None:
        store = build_realtime_store(backend="memory")

        self.assertIsInstance(store, InMemoryRealtimeStore)


class InMemoryRealtimeStoreTest(unittest.IsolatedAsyncioTestCase):
    async def test_cleanup_expired_drivers_removes_stale_positions(self) -> None:
        store = InMemoryRealtimeStore()
        await store.upsert_driver_position(
            driver_id=5,
            location=DriverLocationUpdate(latitude=33.0, longitude=-7.0),
        )
        store._driver_positions[5] = store._driver_positions[5].model_copy(  # noqa: SLF001
            update={"updated_at": datetime.now() - timedelta(seconds=120)}
        )

        expired_driver_ids = await store.cleanup_expired_drivers(expiration_seconds=30)

        self.assertEqual(expired_driver_ids, [5])
        self.assertEqual(await store.list_driver_positions(), [])


class RedisRealtimeServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_set_driver_position_writes_structured_json_in_required_order(self) -> None:
        client = FakeAsyncRedisClient()
        service = RedisRealtimeService(client=client)

        await service.set_driver_position(
            driver_id=12,
            lat=34.0485,
            lng=-6.8147,
        )

        self.assertEqual(
            [command[0] for command in client.commands[:3]],
            ["SET", "SET", "GEOADD"],
        )
        self.assertEqual(
            client.commands[0],
            [
                "SET",
                "driver:12:pos",
                client.commands[0][2],
                "EX",
                "30",
            ],
        )
        self.assertEqual(
            client.commands[1],
            ["SET", "driver:12:online", "1", "EX", "60"],
        )
        self.assertEqual(
            client.commands[2],
            ["GEOADD", "drivers:geo", "-6.8147", "34.0485", "12"],
        )

        payload = json.loads(client.commands[0][2])
        self.assertEqual(
            payload,
            {
                "driver_id": 12,
                "lat": 34.0485,
                "lng": -6.8147,
                "ts": payload["ts"],
            },
        )
        self.assertTrue(payload["ts"])

    async def test_get_driver_position_returns_decoded_payload(self) -> None:
        client = FakeAsyncRedisClient()
        service = RedisRealtimeService(client=client)
        await service.set_driver_position(driver_id=7, lat=1.5, lng=2.5)

        payload = await service.get_driver_position(7)

        self.assertEqual(
            payload,
            {
                "driver_id": 7,
                "lat": 1.5,
                "lng": 2.5,
                "ts": payload["ts"],
            },
        )

    async def test_is_driver_online_uses_online_key(self) -> None:
        client = FakeAsyncRedisClient()
        service = RedisRealtimeService(client=client)

        self.assertFalse(await service.is_driver_online(4))

        await service.set_driver_position(driver_id=4, lat=10.0, lng=20.0)

        self.assertTrue(await service.is_driver_online(4))

    async def test_find_nearby_drivers_filters_stale_geo_entries_and_caps_query(self) -> None:
        client = FakeAsyncRedisClient()
        service = RedisRealtimeService(client=client)
        await service.set_driver_position(driver_id=21, lat=13.5, lng=2.1)
        client._geo_members["22"] = (13.6, 2.2)
        client._forced_geosearch_members = ["21", "22"]

        nearby = await service.find_nearby_drivers(
            lat=13.5,
            lng=2.1,
            radius_km=5.0,
        )

        self.assertEqual(
            nearby,
            [
                {
                    "driver_id": 21,
                    "lat": 13.5,
                    "lng": 2.1,
                    "ts": nearby[0]["ts"],
                }
            ],
        )
        geosearch_command = next(
            command for command in client.commands if command[0] == "GEOSEARCH"
        )
        self.assertIn("COUNT", geosearch_command)
        self.assertIn("50", geosearch_command)


class RedisRealtimeStoreTest(unittest.IsolatedAsyncioTestCase):
    async def test_redis_store_fails_open_when_client_is_missing(self) -> None:
        store = RedisRealtimeStore(redis_service=RedisRealtimeService(client=None))

        await store.upsert_driver_position(
            driver_id=99,
            location=DriverLocationUpdate(latitude=1.0, longitude=2.0),
        )

        self.assertEqual(await store.list_driver_positions(), [])
        self.assertEqual(
            await store.get_nearby_drivers(
                latitude=1.0,
                longitude=2.0,
                max_distance_km=3.0,
            ),
            [],
        )
        self.assertIsNone(await store.get_driver_status(99))


if __name__ == "__main__":
    unittest.main()
