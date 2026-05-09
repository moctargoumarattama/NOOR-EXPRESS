from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import geocoding


class GeocodingApiTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        geocoding._cache.clear()

    def tearDown(self) -> None:
        geocoding._cache.clear()

    async def test_reverse_returns_422_when_position_cannot_be_resolved(self) -> None:
        with patch(
            "app.api.geocoding._request_nominatim",
            new=AsyncMock(return_value=[]),
        ):
            with self.assertRaises(HTTPException) as context:
                await geocoding.reverse_address_endpoint(lat=13.5137, lng=2.1098)

        self.assertEqual(context.exception.status_code, 422)
        self.assertEqual(
            context.exception.detail,
            "Position introuvable - demandez a l'utilisateur de saisir son adresse manuellement",
        )

    async def test_reverse_uses_requested_coordinates_when_lookup_succeeds(self) -> None:
        with patch(
            "app.api.geocoding._request_nominatim",
            new=AsyncMock(
                return_value={
                    "display_name": "Quartier Plateau, Niamey, Niger",
                    "address": {"suburb": "Plateau"},
                }
            ),
        ):
            result = await geocoding.reverse_address_endpoint(lat=13.52, lng=2.08)

        self.assertEqual(result.name, "Plateau")
        self.assertEqual(result.lat, 13.52)
        self.assertEqual(result.lon, 2.08)
        self.assertEqual(result.type, "current_location")


if __name__ == "__main__":
    unittest.main()
