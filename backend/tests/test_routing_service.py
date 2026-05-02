from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import routing_service
from app.models.user import DriverStatus, User, UserRole
from app.realtime.schemas import NearbyDriverLocation
from app.services import ride_lifecycle_service
from app.services.pricing_service import calculate_distance_km


class RoutingServiceFallbackTest(unittest.IsolatedAsyncioTestCase):
    async def test_get_route_payload_uses_haversine_fallback_when_osrm_is_down(
        self,
    ) -> None:
        origin_lat = 13.5116
        origin_lng = 2.1254
        dest_lat = 13.5340
        dest_lng = 2.1090
        expected_distance = round(
            calculate_distance_km(
                origin_lat,
                origin_lng,
                dest_lat,
                dest_lng,
            )
            * 1.3,
            2,
        )

        with patch(
            "app.services.routing_service._fetch_json",
            side_effect=TimeoutError("osrm down"),
        ):
            payload = await routing_service.get_route_payload(
                origin_lat,
                origin_lng,
                dest_lat,
                dest_lng,
            )

        self.assertEqual(
            payload["polyline"],
            [[origin_lat, origin_lng], [dest_lat, dest_lng]],
        )
        self.assertEqual(payload["distance_km"], expected_distance)
        self.assertGreaterEqual(payload["duration_min"], 1)


class RideEstimatePreviewTest(unittest.IsolatedAsyncioTestCase):
    async def test_estimate_uses_route_metrics_price_range_and_driver_count(
        self,
    ) -> None:
        available_driver = User(
            id=11,
            phone_number="+227900000011",
            role=UserRole.DRIVER,
            driver_status=DriverStatus.ONLINE,
            is_available=True,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service.get_route_payload",
                new=AsyncMock(
                    return_value={
                        "polyline": [[13.5116, 2.1254], [13.5340, 2.1090]],
                        "distance_km": 6.4,
                        "duration_min": 18,
                    }
                ),
            ),
            patch(
                "app.services.ride_lifecycle_service.calculate_ride_price",
                new=AsyncMock(
                    return_value={
                        "estimated_price": 2500.0,
                        "final_estimated_price": 2500.0,
                        "distance_km": 6.4,
                        "pickup_zone": "Plateau",
                        "dropoff_zone": "Aeroport",
                        "base_price": 1500.0,
                        "price_per_km": 300.0,
                        "applied_mode": "mixed_distance",
                        "applied_zone_rule": None,
                        "applied_time_rule": None,
                        "platform_commission_preview": 375.0,
                    }
                ),
            ),
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(
                    return_value=[
                        NearbyDriverLocation(
                            driver_id=11,
                            latitude=13.5100,
                            longitude=2.1200,
                            distance_km=1.1,
                        ),
                        NearbyDriverLocation(
                            driver_id=12,
                            latitude=13.5200,
                            longitude=2.1400,
                            distance_km=2.8,
                        ),
                    ]
                ),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_drivers_by_status",
                new=AsyncMock(return_value=[available_driver]),
            ),
            patch(
                "app.services.ride_lifecycle_service._is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
        ):
            payload = await ride_lifecycle_service.estimate_ride_preview(
                session=object(),
                pickup_latitude=13.5116,
                pickup_longitude=2.1254,
                dropoff_latitude=13.5340,
                dropoff_longitude=2.1090,
            )

        self.assertEqual(payload["distance_km"], 6.4)
        self.assertEqual(payload["duration_min"], 18)
        self.assertEqual(payload["estimated_price"], 2500.0)
        self.assertEqual(payload["min_price"], 2200.0)
        self.assertEqual(payload["max_price"], 2800.0)
        self.assertEqual(payload["available_drivers_count"], 1)

    async def test_estimate_uses_haversine_fallback_when_osrm_lookup_fails(
        self,
    ) -> None:
        captured_kwargs: dict[str, object] = {}

        async def fake_calculate_ride_price(session, **kwargs):
            del session
            captured_kwargs.update(kwargs)
            return {
                "estimated_price": 1800.0,
                "final_estimated_price": 1800.0,
                "distance_km": float(kwargs["distance_km"]),
                "pickup_zone": None,
                "dropoff_zone": None,
                "base_price": 1500.0,
                "price_per_km": 300.0,
                "applied_mode": "distance",
                "applied_zone_rule": None,
                "applied_time_rule": None,
                "platform_commission_preview": 270.0,
            }

        with (
            patch(
                "app.services.routing_service._fetch_json",
                side_effect=TimeoutError("osrm down"),
            ),
            patch(
                "app.services.ride_lifecycle_service.calculate_ride_price",
                new=AsyncMock(side_effect=fake_calculate_ride_price),
            ),
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(return_value=[]),
            ),
        ):
            payload = await ride_lifecycle_service.estimate_ride_preview(
                session=object(),
                pickup_latitude=13.4116,
                pickup_longitude=2.0154,
                dropoff_latitude=13.4540,
                dropoff_longitude=2.0890,
            )

        self.assertGreater(float(captured_kwargs["distance_km"]), 0.0)
        self.assertGreater(int(captured_kwargs["estimated_duration_minutes"]), 0)
        self.assertEqual(
            payload["distance_km"],
            round(float(captured_kwargs["distance_km"]), 3),
        )
        self.assertEqual(
            payload["duration_min"],
            int(captured_kwargs["estimated_duration_minutes"]),
        )
        self.assertEqual(payload["available_drivers_count"], 0)

    async def test_estimate_returns_zero_available_drivers_when_none_match(
        self,
    ) -> None:
        with (
            patch(
                "app.services.ride_lifecycle_service.get_route_payload",
                new=AsyncMock(
                    return_value={
                        "polyline": [[13.5000, 2.1000], [13.4800, 2.1700]],
                        "distance_km": 5.2,
                        "duration_min": 14,
                    }
                ),
            ),
            patch(
                "app.services.ride_lifecycle_service.calculate_ride_price",
                new=AsyncMock(
                    return_value={
                        "estimated_price": 2200.0,
                        "final_estimated_price": 2200.0,
                        "distance_km": 5.2,
                        "pickup_zone": "Grand Marche",
                        "dropoff_zone": "Aeroport",
                        "base_price": 1500.0,
                        "price_per_km": 300.0,
                        "applied_mode": "mixed_distance",
                        "applied_zone_rule": None,
                        "applied_time_rule": None,
                        "platform_commission_preview": 330.0,
                    }
                ),
            ),
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(return_value=[]),
            ),
        ):
            payload = await ride_lifecycle_service.estimate_ride_preview(
                session=object(),
                pickup_latitude=13.5000,
                pickup_longitude=2.1000,
                dropoff_latitude=13.4800,
                dropoff_longitude=2.1700,
            )

        self.assertEqual(payload["available_drivers_count"], 0)
        self.assertEqual(payload["min_price"], 1900.0)
        self.assertEqual(payload["max_price"], 2500.0)


if __name__ == "__main__":
    unittest.main()
