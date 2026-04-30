import unittest
from pathlib import Path
from types import SimpleNamespace
import sys
from unittest.mock import AsyncMock, Mock, patch

from fastapi import HTTPException


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import admin
from app.models.driver_profile import DriverVerificationStatus
from app.services import driver_profile_service


class AdminDriverManagementServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_get_all_drivers_includes_verified_and_blocked_profiles(self) -> None:
        profile = SimpleNamespace(
            id=7,
            user_id=11,
            first_name="Amine",
            last_name="El Idrissi",
            address="Rabat Agdal",
            id_card_photo="card",
            selfie_photo="selfie",
            verification_status=DriverVerificationStatus.VERIFIED,
            rejection_reason=None,
            submitted_at=None,
            verified_at=None,
        )
        user = SimpleNamespace(
            phone_number="+212600000000",
            name="Amine",
            is_blocked=True,
        )
        result = Mock()
        result.all.return_value = [(profile, user)]
        session = SimpleNamespace(execute=AsyncMock(return_value=result))

        rows = await driver_profile_service.get_all_drivers(session)

        self.assertEqual(rows[0]["verification_status"], "verified")
        self.assertTrue(rows[0]["is_blocked"])

    async def test_admin_update_driver_profile_saves_contact_details(self) -> None:
        profile = SimpleNamespace(
            first_name="Old",
            last_name="Name",
            address=None,
            id_card_photo="card",
            selfie_photo="selfie",
        )
        session = SimpleNamespace(
            get=AsyncMock(return_value=SimpleNamespace(name="Old")),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.driver_profile_service.get_profile",
            new=AsyncMock(return_value=profile),
        ):
            result = await driver_profile_service.admin_update_driver_profile(
                session,
                9,
                driver_profile_service.DriverProfileAdminUpdate(
                    first_name="Sara",
                    last_name="Bennani",
                    phone_number="+212611111111",
                    address="Hay Riad",
                ),
            )

        self.assertIs(result, profile)
        self.assertEqual(profile.first_name, "Sara")
        self.assertEqual(profile.last_name, "Bennani")
        self.assertEqual(profile.address, "Hay Riad")
        session.commit.assert_awaited_once()


class AdminDriverManagementRoutesTest(unittest.IsolatedAsyncioTestCase):
    async def test_admin_drivers_endpoint_returns_all_profiles(self) -> None:
        with patch(
            "app.api.admin.get_all_drivers",
            new=AsyncMock(return_value=[{"user_id": 9, "is_blocked": False}]),
        ):
            payload = await admin.admin_drivers_endpoint(
                _admin={"sub": "1"},
                session=AsyncMock(),
            )

        self.assertEqual(payload, [{"user_id": 9, "is_blocked": False}])

    async def test_admin_update_driver_profile_endpoint_maps_missing_profile(self) -> None:
        with patch(
            "app.api.admin.admin_update_driver_profile",
            new=AsyncMock(side_effect=HTTPException(status_code=404, detail="missing")),
        ):
            with self.assertRaises(HTTPException) as exc:
                await admin.admin_update_driver_profile_endpoint(
                    9,
                    admin.DriverProfileAdminUpdate(
                        first_name="Sara",
                        last_name="Bennani",
                        phone_number="+212611111111",
                        address="Hay Riad",
                    ),
                    _admin={"sub": "1"},
                    session=AsyncMock(),
                )

        self.assertEqual(exc.exception.status_code, 404)


if __name__ == "__main__":
    unittest.main()
