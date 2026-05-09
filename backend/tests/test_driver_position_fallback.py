from datetime import datetime, timedelta
from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, Mock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import User, UserRole
from app.realtime.schemas import DriverLocationUpdate
from app.services import ride_request_service


class DriverPositionFallbackServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_driver_with_realtime_store_position_is_visible(self) -> None:
        driver = User(
            id=301,
            phone_number="+22790000301",
            role=UserRole.DRIVER,
            max_radius_km=5,
        )
        session = AsyncMock()
        session.execute = AsyncMock(return_value=_ride_query_result([_ride()]))

        with (
            patch(
                "app.services.ride_request_service.is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
            patch(
                "app.services.ride_request_service._get_connected_driver_position",
                new=AsyncMock(return_value=(13.5137, 2.1098)),
            ),
            patch(
                "app.services.ride_lifecycle_service.expire_ride",
                new=AsyncMock(side_effect=lambda _session, _ride_id: None),
            ),
            patch(
                "app.services.ride_request_service.notify_user",
                new=AsyncMock(),
            ) as mocked_notify,
        ):
            rides = await ride_request_service.get_available_ride_requests(
                session=session,
                current_user=driver,
            )

        self.assertEqual(len(rides), 1)
        mocked_notify.assert_not_awaited()

    async def test_driver_with_fresh_database_position_is_visible(self) -> None:
        now = datetime.utcnow()
        driver = User(
            id=302,
            phone_number="+22790000302",
            role=UserRole.DRIVER,
            max_radius_km=5,
        )
        persisted_driver = User(
            id=302,
            phone_number="+22790000302",
            role=UserRole.DRIVER,
            last_known_lat=13.5137,
            last_known_lon=2.1098,
            last_position_at=now - timedelta(minutes=8),
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=persisted_driver)
        session.execute = AsyncMock(return_value=_ride_query_result([_ride()]))

        with (
            patch(
                "app.services.ride_request_service.is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
            patch(
                "app.services.ride_request_service._get_connected_driver_position",
                new=AsyncMock(return_value=None),
            ),
            patch(
                "app.services.ride_lifecycle_service.expire_ride",
                new=AsyncMock(side_effect=lambda _session, _ride_id: None),
            ),
            patch(
                "app.services.ride_request_service.notify_user",
                new=AsyncMock(),
            ) as mocked_notify,
        ):
            rides = await ride_request_service.get_available_ride_requests(
                session=session,
                current_user=driver,
            )

        self.assertEqual(len(rides), 1)
        mocked_notify.assert_not_awaited()

    async def test_driver_with_stale_database_position_is_invisible(self) -> None:
        now = datetime.utcnow()
        driver = User(
            id=303,
            phone_number="+22790000303",
            role=UserRole.DRIVER,
            max_radius_km=5,
        )
        persisted_driver = User(
            id=303,
            phone_number="+22790000303",
            role=UserRole.DRIVER,
            last_known_lat=13.5137,
            last_known_lon=2.1098,
            last_position_at=now - timedelta(minutes=45),
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=persisted_driver)

        with (
            patch(
                "app.services.ride_request_service.is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
            patch(
                "app.services.ride_request_service._get_connected_driver_position",
                new=AsyncMock(return_value=None),
            ),
            patch(
                "app.services.ride_request_service.notify_user",
                new=AsyncMock(),
            ) as mocked_notify,
        ):
            rides = await ride_request_service.get_available_ride_requests(
                session=session,
                current_user=driver,
            )

        self.assertEqual(rides, [])
        session.execute.assert_not_awaited()
        mocked_notify.assert_awaited_once()

    async def test_driver_without_any_position_is_invisible_and_gets_fcm(self) -> None:
        driver = User(
            id=304,
            phone_number="+22790000304",
            role=UserRole.DRIVER,
            max_radius_km=5,
        )
        persisted_driver = User(
            id=304,
            phone_number="+22790000304",
            role=UserRole.DRIVER,
            last_known_lat=None,
            last_known_lon=None,
            last_position_at=None,
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=persisted_driver)

        with (
            patch(
                "app.services.ride_request_service.is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
            patch(
                "app.services.ride_request_service._get_connected_driver_position",
                new=AsyncMock(return_value=None),
            ),
            patch(
                "app.services.ride_request_service.notify_user",
                new=AsyncMock(),
            ) as mocked_notify,
        ):
            rides = await ride_request_service.get_available_ride_requests(
                session=session,
                current_user=driver,
            )

        self.assertEqual(rides, [])
        mocked_notify.assert_awaited_once()
        args, kwargs = mocked_notify.await_args
        self.assertIn(
            "Activez votre GPS pour recevoir des demandes de courses",
            kwargs["body"] if "body" in kwargs else args[3],
        )

    async def test_persist_driver_last_known_position_updates_database_fields(self) -> None:
        driver = User(
            id=305,
            phone_number="+22790000305",
            role=UserRole.DRIVER,
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=driver)

        await ride_request_service.persist_driver_last_known_position(
            session,
            driver_id=305,
            latitude=13.5001,
            longitude=2.1002,
        )

        self.assertEqual(driver.last_known_lat, 13.5001)
        self.assertEqual(driver.last_known_lon, 2.1002)
        self.assertIsNotNone(driver.last_position_at)
        session.commit.assert_awaited_once()


class DriverPositionRealtimeHydrationTest(unittest.IsolatedAsyncioTestCase):
    async def test_websocket_reconnect_reinjects_fresh_database_position(self) -> None:
        from app.api import realtime as realtime_api

        with (
            patch(
                "app.api.realtime._driver_has_store_position",
                new=AsyncMock(return_value=False),
            ),
            patch(
                "app.api.realtime.get_fresh_driver_position_from_database",
                new=AsyncMock(return_value=(13.51, 2.11)),
            ),
            patch(
                "app.api.realtime.realtime_gateway.update_position",
                new=AsyncMock(),
            ) as mocked_update,
            patch(
                "app.api.realtime.AsyncSessionLocal",
                return_value=_AsyncSessionContext(session=object()),
            ),
        ):
            await realtime_api._restore_driver_position_from_database_if_fresh(401)

        mocked_update.assert_awaited_once()
        notification = mocked_update.await_args.args[1]
        self.assertIsInstance(notification, DriverLocationUpdate)
        self.assertEqual(notification.latitude, 13.51)
        self.assertEqual(notification.longitude, 2.11)


class _AsyncSessionContext:
    def __init__(self, session: object) -> None:
        self._session = session

    async def __aenter__(self) -> object:
        return self._session

    async def __aexit__(self, exc_type, exc, tb) -> None:
        return None


def _ride() -> RideRequest:
    return RideRequest(
        id=9001,
        client_id=11,
        status=RideRequestStatus.PENDING,
        pickup_location="Plateau",
        dropoff_location="Aeroport",
        pickup_latitude=13.5138,
        pickup_longitude=2.1097,
        estimated_price=2500,
    )


def _ride_query_result(rides: list[RideRequest]) -> Mock:
    scalars = Mock()
    scalars.all.return_value = rides
    result = Mock()
    result.scalars.return_value = scalars
    return result


if __name__ == "__main__":
    unittest.main()
