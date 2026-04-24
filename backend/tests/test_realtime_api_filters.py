from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.models.user import DriverStatus, User, UserRole
from app.realtime.schemas import NearbyDriverLocation


class RealtimeApiFilterTest(unittest.IsolatedAsyncioTestCase):
    async def test_filter_available_driver_locations_keeps_only_online_available_drivers(
        self,
    ) -> None:
        from app.api.realtime import _filter_available_driver_locations

        session = object()
        locations = [
            NearbyDriverLocation(
                driver_id=11,
                latitude=34.0,
                longitude=-6.8,
                distance_km=0.8,
            ),
            NearbyDriverLocation(
                driver_id=12,
                latitude=34.1,
                longitude=-6.7,
                distance_km=1.6,
            ),
        ]
        available_driver = User(
            id=11,
            phone_number="+212600000011",
            role=UserRole.DRIVER,
            driver_status=DriverStatus.ONLINE,
            is_available=True,
        )

        with patch(
            "app.api.realtime.get_drivers_by_status",
            new=AsyncMock(return_value=[available_driver]),
        ) as get_drivers_by_status:
            filtered = await _filter_available_driver_locations(session, locations)

        self.assertEqual([location.driver_id for location in filtered], [11])
        get_drivers_by_status.assert_awaited_once()

    async def test_filter_available_driver_locations_returns_empty_for_empty_input(
        self,
    ) -> None:
        from app.api.realtime import _filter_available_driver_locations

        with patch(
            "app.api.realtime.get_drivers_by_status",
            new=AsyncMock(),
        ) as get_drivers_by_status:
            filtered = await _filter_available_driver_locations(object(), [])

        self.assertEqual(filtered, [])
        get_drivers_by_status.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
