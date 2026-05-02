import sys
import unittest
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.models.ride_offer import RideOfferStatus
from app.services import ride_offer_service


class RideOfferEnrichmentTest(unittest.IsolatedAsyncioTestCase):
    async def test_build_offer_read_exposes_trust_and_vehicle_details(self) -> None:
        offer = SimpleNamespace(
            id=5,
            proposed_price=Decimal("2800"),
            status=RideOfferStatus.PENDING,
            created_at=datetime(2026, 5, 1, 8, 0, 0),
        )
        ride_request = SimpleNamespace(
            pickup_latitude=13.51,
            pickup_longitude=2.11,
        )
        driver = SimpleNamespace(
            id=9,
            name="Amadou",
            phone_number="+22790000000",
            vehicle_brand="Toyota",
            vehicle_model="Corolla",
            vehicle_color="blanche",
            plate_number="NE-2456",
            vehicle_photo="vehicle-photo",
        )

        with patch(
            "app.services.ride_offer_service.driver_locator.get_connected_drivers",
            new=AsyncMock(return_value=[SimpleNamespace(driver_id=9)]),
        ), patch(
            "app.services.ride_offer_service._get_driver_rating",
            new=AsyncMock(return_value=4.8),
        ), patch(
            "app.services.ride_offer_service._get_driver_completed_rides",
            new=AsyncMock(return_value=128),
        ), patch(
            "app.services.ride_offer_service._driver_has_valid_documents",
            new=AsyncMock(return_value=True),
        ), patch(
            "app.services.ride_offer_service._get_driver_route_metrics",
            new=AsyncMock(return_value=(1.7, 6)),
        ):
            payload = await ride_offer_service._build_offer_read(
                AsyncMock(),
                offer,
                ride_request,
                driver,
            )

        self.assertEqual(payload.driver_completed_rides, 128)
        self.assertTrue(payload.driver_verified)
        self.assertEqual(payload.driver_eta_minutes, 6)
        self.assertEqual(payload.vehicle_photo, "vehicle-photo")


if __name__ == "__main__":
    unittest.main()
