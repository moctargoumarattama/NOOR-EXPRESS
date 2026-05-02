import unittest
from datetime import datetime, time, timedelta
from pathlib import Path
from types import SimpleNamespace
import sys
from unittest.mock import AsyncMock, Mock, patch

from fastapi import HTTPException


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import admin
from app.models.driver_profile import (
    DriverDocumentStatus,
    DriverDocumentType,
    DriverVerificationStatus,
)
from app.schemas.driver_profile import (
    DriverDocumentReviewRequest,
    DriverProfileCreate,
    DriverProfileRead,
)
from app.services import driver_profile_service


class AdminDriverManagementServiceTest(unittest.IsolatedAsyncioTestCase):
    def test_driver_profile_create_requires_private_driver_documents(self) -> None:
        payload = _profile_create_payload()
        profile = DriverProfileCreate(**payload)

        self.assertEqual(profile.driver_license_file, "license")
        self.assertEqual(
            profile.technical_inspection_expires_at.isoformat(),
            "2027-01-04",
        )

    def test_driver_profile_read_marks_expired_documents_and_alerts(self) -> None:
        profile = DriverProfileRead.model_validate(
            SimpleNamespace(
                id=1,
                user_id=11,
                first_name="Amine",
                last_name="El Idrissi",
                address=None,
                id_card_photo="card",
                selfie_photo="selfie",
                verification_status=DriverVerificationStatus.PENDING,
                rejection_reason=None,
                submitted_at=None,
                verified_at=None,
                driver_license_file="license",
                driver_license_expires_at=driver_profile_service.today_utc(),
                driver_license_status=DriverDocumentStatus.VALIDATED,
                vehicle_registration_file="registration",
                vehicle_registration_expires_at=driver_profile_service.today_utc(),
                vehicle_registration_status=DriverDocumentStatus.VALIDATED,
                vehicle_insurance_file="insurance",
                vehicle_insurance_expires_at=driver_profile_service.today_utc(),
                vehicle_insurance_status=DriverDocumentStatus.VALIDATED,
                technical_inspection_file="inspection",
                technical_inspection_expires_at=driver_profile_service.today_utc(),
                technical_inspection_status=DriverDocumentStatus.VALIDATED,
            )
        )

        self.assertEqual(profile.driver_license_status, DriverDocumentStatus.VALIDATED)
        self.assertTrue(profile.document_expiry_alerts)

    def test_effective_document_status_supports_datetime_expiry(self) -> None:
        today = driver_profile_service.today_utc()
        expiry_as_datetime = datetime.combine(today - timedelta(days=1), time.min)

        status = driver_profile_service.effective_document_status(
            DriverDocumentStatus.VALIDATED,
            expiry_as_datetime,
            today=today,
        )

        self.assertEqual(status, DriverDocumentStatus.EXPIRED)

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
            **_document_namespace_values(),
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
        self.assertEqual(rows[0]["driver_license_status"], "en_attente")

    async def test_get_all_drivers_handles_datetime_document_expiry(self) -> None:
        today = driver_profile_service.today_utc()
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
            **_document_namespace_values(),
        )
        profile.driver_license_status = DriverDocumentStatus.VALIDATED
        profile.driver_license_expires_at = datetime.combine(
            today - timedelta(days=1),
            time.min,
        )
        user = SimpleNamespace(
            phone_number="+212600000000",
            name="Amine",
            is_blocked=False,
        )
        result = Mock()
        result.all.return_value = [(profile, user)]
        session = SimpleNamespace(execute=AsyncMock(return_value=result))

        rows = await driver_profile_service.get_all_drivers(session)

        self.assertEqual(
            rows[0]["driver_license_status"],
            DriverDocumentStatus.EXPIRED.value,
        )

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

    async def test_create_or_update_profile_stores_private_driver_documents(self) -> None:
        profile = SimpleNamespace(user_id=9)
        session = SimpleNamespace(
            add=Mock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.driver_profile_service.get_profile",
            new=AsyncMock(return_value=profile),
        ):
            await driver_profile_service.create_or_update_profile(
                session,
                9,
                DriverProfileCreate(**_profile_create_payload()),
            )

        self.assertEqual(profile.driver_license_file, "license")
        self.assertEqual(
            profile.vehicle_insurance_status,
            DriverDocumentStatus.PENDING,
        )
        session.commit.assert_awaited_once()

    async def test_review_driver_document_updates_only_selected_document(self) -> None:
        profile = SimpleNamespace(**_document_namespace_values())
        session = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

        with patch(
            "app.services.driver_profile_service.get_profile",
            new=AsyncMock(return_value=profile),
        ):
            await driver_profile_service.review_driver_document(
                session,
                9,
                DriverDocumentType.VEHICLE_INSURANCE,
                DriverDocumentStatus.REJECTED,
            )

        self.assertEqual(
            profile.vehicle_insurance_status,
            DriverDocumentStatus.REJECTED,
        )
        self.assertEqual(profile.driver_license_status, DriverDocumentStatus.PENDING)
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

    async def test_admin_review_driver_document_endpoint_returns_document_status(
        self,
    ) -> None:
        with patch(
            "app.api.admin.review_driver_document",
            new=AsyncMock(
                return_value=SimpleNamespace(
                    user_id=9,
                    driver_license_status=DriverDocumentStatus.VALIDATED,
                )
            ),
        ):
            payload = await admin.admin_review_driver_document_endpoint(
                9,
                DriverDocumentType.DRIVER_LICENSE,
                DriverDocumentReviewRequest(status=DriverDocumentStatus.VALIDATED),
                _admin={"sub": "1"},
                session=AsyncMock(),
            )

        self.assertEqual(payload["document_status"], "validé")


def _profile_create_payload() -> dict:
    return {
        "first_name": "Amine",
        "last_name": "El Idrissi",
        "address": "Niamey Plateau",
        "id_card_photo": "card",
        "selfie_photo": "selfie",
        "driver_license_file": "license",
        "driver_license_expires_at": "2027-01-01",
        "vehicle_registration_file": "registration",
        "vehicle_registration_expires_at": "2027-01-02",
        "vehicle_insurance_file": "insurance",
        "vehicle_insurance_expires_at": "2027-01-03",
        "technical_inspection_file": "inspection",
        "technical_inspection_expires_at": "2027-01-04",
    }


def _document_namespace_values() -> dict:
    return {
        "driver_license_file": "license",
        "driver_license_expires_at": None,
        "driver_license_status": DriverDocumentStatus.PENDING,
        "vehicle_registration_file": "registration",
        "vehicle_registration_expires_at": None,
        "vehicle_registration_status": DriverDocumentStatus.PENDING,
        "vehicle_insurance_file": "insurance",
        "vehicle_insurance_expires_at": None,
        "vehicle_insurance_status": DriverDocumentStatus.PENDING,
        "technical_inspection_file": "inspection",
        "technical_inspection_expires_at": None,
        "technical_inspection_status": DriverDocumentStatus.PENDING,
    }


if __name__ == "__main__":
    unittest.main()
