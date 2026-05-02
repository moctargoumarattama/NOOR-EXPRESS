from pathlib import Path
from types import SimpleNamespace
from datetime import datetime, timedelta
from decimal import Decimal
import sys
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
from pydantic import ValidationError

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import admin
from app.api import user as user_api
from app.core import security
from app.core.api_errors import ApiError
from app.models.ride_report import RideReportStatus
from app.models.user import DriverStatus, UserRole
from app.services import admin_service, user_service


class AdminUserManagementServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_block_user_marks_account_blocked_and_invalidates_tokens(
        self,
    ) -> None:
        user = SimpleNamespace(
            id=10,
            role=UserRole.DRIVER,
            is_blocked=False,
            refresh_token="refresh-token",
            fcm_token="fcm-token",
            is_available=True,
            driver_status=DriverStatus.ONLINE,
        )
        session = SimpleNamespace(
            get=AsyncMock(return_value=user),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        result = await admin_service.block_user(session, 10)

        self.assertIs(result, user)
        self.assertTrue(user.is_blocked)
        self.assertIsNone(user.refresh_token)
        self.assertIsNone(user.fcm_token)
        self.assertFalse(user.is_available)
        self.assertEqual(user.driver_status, DriverStatus.OFFLINE)
        session.commit.assert_awaited_once()

    async def test_delete_user_translates_integrity_errors_to_conflict(self) -> None:
        session = SimpleNamespace(
            get=AsyncMock(return_value=SimpleNamespace(id=10)),
            delete=AsyncMock(),
            commit=AsyncMock(side_effect=admin_service.IntegrityError("", "", "")),
            rollback=AsyncMock(),
        )

        with self.assertRaises(admin_service.AdminUserDeleteBlockedError):
            await admin_service.delete_user(session, 10)

        session.rollback.assert_awaited_once()


class AdminSuspensionServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_suspend_user_supports_temporary_and_permanent_modes(self) -> None:
        temporary_user = SimpleNamespace(
            id=20,
            role=UserRole.CLIENT,
            is_suspended=False,
            suspended_until=None,
            suspension_reason=None,
            refresh_token="token",
        )
        permanent_user = SimpleNamespace(
            id=21,
            role=UserRole.DRIVER,
            is_suspended=False,
            suspended_until=None,
            suspension_reason=None,
            refresh_token="token",
            is_available=True,
            driver_status=DriverStatus.ONLINE,
        )
        session = SimpleNamespace(
            get=AsyncMock(side_effect=[temporary_user, permanent_user]),
            add=lambda *_args, **_kwargs: None,
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        temporary_result = await admin_service.suspend_user(
            session,
            temporary_user.id,
            reason="Fraude detectee",
            duration_days=3,
        )
        permanent_result = await admin_service.suspend_user(
            session,
            permanent_user.id,
            reason="Incident grave",
            duration_days=None,
        )

        self.assertIs(temporary_result, temporary_user)
        self.assertTrue(temporary_user.is_suspended)
        self.assertIsNotNone(temporary_user.suspended_until)
        self.assertEqual(temporary_user.suspension_reason, "Fraude detectee")

        self.assertIs(permanent_result, permanent_user)
        self.assertTrue(permanent_user.is_suspended)
        self.assertIsNone(permanent_user.suspended_until)
        self.assertEqual(permanent_user.suspension_reason, "Incident grave")
        self.assertFalse(permanent_user.is_available)
        self.assertEqual(permanent_user.driver_status, DriverStatus.OFFLINE)

    async def test_unsuspend_user_clears_flags_and_closes_last_history_row(
        self,
    ) -> None:
        user = SimpleNamespace(
            id=30,
            is_suspended=True,
            suspended_until=datetime.utcnow() + timedelta(days=2),
            suspension_reason="Test",
        )
        suspension_history = SimpleNamespace(
            user_id=30,
            lifted_at=None,
        )
        session = SimpleNamespace(
            get=AsyncMock(return_value=user),
            execute=AsyncMock(
                return_value=SimpleNamespace(
                    scalar_one_or_none=lambda: suspension_history
                )
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        result = await admin_service.unsuspend_user(session, user.id)

        self.assertIs(result, user)
        self.assertFalse(user.is_suspended)
        self.assertIsNone(user.suspended_until)
        self.assertIsNone(user.suspension_reason)
        self.assertIsNotNone(suspension_history.lifted_at)


class ReportWorkflowServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_update_report_status_notifies_reported_user(self) -> None:
        report = SimpleNamespace(
            id=41,
            ride_request_id=501,
            reported_by_id=99,
            status=RideReportStatus.NOUVEAU,
            note_admin=None,
        )
        ride_request = SimpleNamespace(
            id=501,
            client_id=99,
            driver_id=77,
        )
        session = SimpleNamespace(
            get=AsyncMock(side_effect=[report, ride_request]),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.admin_service.notify_user",
            new=AsyncMock(),
        ) as notify_user_mock:
            updated_report = await admin_service.update_report(
                session,
                report_id=41,
                status=RideReportStatus.EN_COURS,
                note_admin="En verification",
            )

        self.assertIs(updated_report, report)
        self.assertEqual(report.status, RideReportStatus.EN_COURS)
        self.assertEqual(report.note_admin, "En verification")
        notify_user_mock.assert_awaited_once()
        self.assertEqual(notify_user_mock.await_args.args[1], 77)

    async def test_report_workflow_supports_all_statuses(self) -> None:
        report = SimpleNamespace(
            id=42,
            ride_request_id=502,
            reported_by_id=10,
            status=RideReportStatus.NOUVEAU,
            note_admin=None,
        )
        ride_request = SimpleNamespace(
            id=502,
            client_id=10,
            driver_id=88,
        )
        session = SimpleNamespace(
            get=AsyncMock(
                side_effect=[
                    report,
                    ride_request,
                    report,
                    ride_request,
                    report,
                    ride_request,
                ]
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.admin_service.notify_user",
            new=AsyncMock(),
        ) as notify_user_mock:
            await admin_service.update_report(
                session,
                report_id=42,
                status=RideReportStatus.EN_COURS,
                note_admin="En cours",
            )
            await admin_service.update_report(
                session,
                report_id=42,
                status=RideReportStatus.RESOLU,
                note_admin="Resolution",
            )
            await admin_service.update_report(
                session,
                report_id=42,
                status=RideReportStatus.CLASSE_SANS_SUITE,
                note_admin="Classe sans suite",
            )

        self.assertEqual(report.status, RideReportStatus.CLASSE_SANS_SUITE)
        self.assertEqual(notify_user_mock.await_count, 3)


class AuthSuspensionRulesTest(unittest.IsolatedAsyncioTestCase):
    async def test_login_with_suspended_account_is_rejected_with_403(self) -> None:
        suspended_user = SimpleNamespace(
            id=60,
            is_blocked=False,
            is_suspended=True,
            suspension_reason="Agressivite",
            suspended_until=datetime.utcnow() + timedelta(days=1),
        )
        session = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

        with patch(
            "app.services.user_service.get_user_by_phone_number",
            new=AsyncMock(return_value=suspended_user),
        ):
            with self.assertRaises(ApiError) as context:
                await user_service.authenticate_user(session, "+22790000060")

        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(context.exception.code, user_service.SUSPENSION_CODE)
        self.assertIn("Agressivite", context.exception.message)

    async def test_login_after_suspension_expiry_is_allowed(self) -> None:
        expired_suspension_user = SimpleNamespace(
            id=61,
            is_blocked=False,
            is_suspended=True,
            suspension_reason="Retard",
            suspended_until=datetime.utcnow() - timedelta(minutes=5),
        )
        session = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

        with patch(
            "app.services.user_service.get_user_by_phone_number",
            new=AsyncMock(return_value=expired_suspension_user),
        ):
            result = await user_service.authenticate_user(session, "+22790000061")

        self.assertIs(result, expired_suspension_user)
        self.assertFalse(expired_suspension_user.is_suspended)
        self.assertIsNone(expired_suspension_user.suspended_until)
        self.assertIsNone(expired_suspension_user.suspension_reason)


class AccountDeletionServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_delete_account_rejects_user_with_ongoing_ride(self) -> None:
        user = _build_deletable_user(role=UserRole.CLIENT)
        session = SimpleNamespace(
            get=AsyncMock(return_value=user),
            execute=AsyncMock(
                return_value=SimpleNamespace(scalar_one_or_none=lambda: 501)
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )

        with self.assertRaises(ApiError) as context:
            await user_service.delete_current_user_account(session, user)

        self.assertEqual(context.exception.status_code, 409)
        self.assertEqual(context.exception.code, "account_deletion_ride_in_progress")
        session.commit.assert_not_awaited()

    async def test_delete_account_blocks_driver_with_non_zero_wallet(self) -> None:
        user = _build_deletable_user(role=UserRole.DRIVER)
        session = SimpleNamespace(
            get=AsyncMock(return_value=user),
            execute=AsyncMock(
                side_effect=[
                    SimpleNamespace(scalar_one_or_none=lambda: None),
                    SimpleNamespace(
                        scalar_one_or_none=lambda: Decimal("1250.00")
                    ),
                ]
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )

        with self.assertRaises(ApiError) as context:
            await user_service.delete_current_user_account(session, user)

        self.assertEqual(context.exception.status_code, 409)
        self.assertEqual(context.exception.code, "driver_wallet_not_settled")
        self.assertEqual(
            context.exception.message,
            "Soldez votre wallet avant de supprimer votre compte",
        )
        session.commit.assert_not_awaited()

    async def test_delete_account_anonymizes_personal_data(self) -> None:
        user = _build_deletable_user(role=UserRole.CLIENT)
        session = SimpleNamespace(
            get=AsyncMock(return_value=user),
            execute=AsyncMock(
                side_effect=[
                    SimpleNamespace(scalar_one_or_none=lambda: None),
                    SimpleNamespace(),
                    SimpleNamespace(),
                    SimpleNamespace(scalar_one_or_none=lambda: None),
                ]
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )

        with patch(
            "app.services.user_service._delete_profile_photo_file"
        ) as delete_photo_mock:
            await user_service.delete_current_user_account(
                session,
                user,
                deletion_reason="Demande utilisateur",
            )

        self.assertEqual(user.name, "Utilisateur supprimé")
        self.assertTrue(user.phone_number.startswith("del_"))
        self.assertIsNone(user.profile_photo)
        self.assertIsNone(user.refresh_token)
        self.assertIsNone(user.fcm_token)
        self.assertTrue(user.is_blocked)
        self.assertIsNotNone(user.deleted_at)
        self.assertEqual(user.deletion_reason, "Demande utilisateur")
        session.commit.assert_awaited_once()
        session.refresh.assert_awaited_once_with(user)
        delete_photo_mock.assert_called_once_with("/uploads/profile_photos/avatar.jpg")

    async def test_delete_account_invalidates_existing_jwt(self) -> None:
        user = _build_deletable_user(role=UserRole.CLIENT)
        access_token = security.create_access_token(user)
        session = SimpleNamespace(
            get=AsyncMock(return_value=user),
            execute=AsyncMock(
                side_effect=[
                    SimpleNamespace(scalar_one_or_none=lambda: None),
                    SimpleNamespace(),
                    SimpleNamespace(),
                    SimpleNamespace(scalar_one_or_none=lambda: None),
                ]
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )

        with patch(
            "app.services.user_service._delete_profile_photo_file"
        ), patch(
            "app.core.security.get_user_by_id",
            new=AsyncMock(return_value=user),
        ):
            await user_service.delete_current_user_account(session, user)
            verified_user = await security.verify_token(access_token, session=object())

        self.assertIsNone(verified_user)


class AdminNotificationBroadcastServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_broadcast_limit_rejects_sixth_send_in_hour(self) -> None:
        target_user = SimpleNamespace(id=90, fcm_token="fcm-token")
        count_result = SimpleNamespace(scalar_one=lambda: 5)
        oldest_result = SimpleNamespace(
            scalar_one_or_none=lambda: datetime.utcnow() - timedelta(minutes=30)
        )
        session = SimpleNamespace(
            get=AsyncMock(return_value=target_user),
            execute=AsyncMock(side_effect=[count_result, oldest_result]),
            add=lambda *_args, **_kwargs: None,
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with self.assertRaises(admin_service.AdminNotificationRateLimitError) as context:
            await admin_service.send_notification_broadcast(
                session,
                target="user_id",
                user_id=90,
                title="Info",
                message="Test",
                notification_type="info",
            )

        self.assertGreater(context.exception.retry_after_seconds, 0)
        session.commit.assert_not_awaited()


class AdminRequestValidationTest(unittest.TestCase):
    def test_suspend_request_requires_duration_when_not_permanent(self) -> None:
        with self.assertRaises(ValidationError):
            admin.AdminUserSuspendRequest(reason="Test", is_permanent=False)

    def test_suspend_request_rejects_duration_with_permanent_mode(self) -> None:
        with self.assertRaises(ValidationError):
            admin.AdminUserSuspendRequest(
                reason="Test",
                is_permanent=True,
                duration_days=5,
            )

    def test_notification_broadcast_rejects_invalid_target(self) -> None:
        with self.assertRaises(ValidationError):
            admin.AdminNotificationBroadcastRequest(
                target="invalid",
                title="Info",
                message="Message test",
                type="info",
            )

    def test_notification_broadcast_rejects_blank_title(self) -> None:
        with self.assertRaises(ValidationError):
            admin.AdminNotificationBroadcastRequest(
                target=admin.AdminNotificationTarget.ALL,
                title="   ",
                message="Message test",
                type=admin.AdminNotificationType.INFO,
            )


class SupportConfigRouteTest(unittest.IsolatedAsyncioTestCase):
    async def test_support_config_endpoint_returns_environment_values(self) -> None:
        with patch.object(
            user_api.settings,
            "SUPPORT_WHATSAPP_NUMBER",
            " +22799001122 ",
        ), patch.object(
            user_api.settings,
            "SUPPORT_HOURS",
            " 08:00-22:00 ",
        ):
            payload = await user_api.support_config_endpoint()

        self.assertEqual(payload["whatsapp_number"], "+22799001122")
        self.assertEqual(payload["support_hours"], "08:00-22:00")


class LegalPagesRouteTest(unittest.IsolatedAsyncioTestCase):
    async def test_legal_terms_endpoint_returns_public_html(self) -> None:
        response = await user_api.legal_terms_endpoint()

        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.headers.get("content-type", ""))
        body = response.body.decode("utf-8")
        self.assertIn("Noor Express", body)
        self.assertIn("Niamey", body)

    async def test_legal_privacy_endpoint_returns_public_html(self) -> None:
        response = await user_api.legal_privacy_endpoint()

        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.headers.get("content-type", ""))
        body = response.body.decode("utf-8")
        self.assertIn("Politique de Confidentialite", body)
        self.assertIn("Droit de suppression", body)


class AdminUserManagementRoutesTest(unittest.IsolatedAsyncioTestCase):
    async def test_block_user_endpoint_returns_blocked_flag(self) -> None:
        with patch(
            "app.api.admin.block_user",
            new=AsyncMock(return_value=SimpleNamespace(id=12, is_blocked=True)),
        ):
            payload = await admin.admin_block_user_endpoint(
                user_id=12,
                _admin={},
                session=object(),
            )

        self.assertEqual(payload, {"user_id": 12, "is_blocked": True})

    async def test_deleted_users_endpoint_returns_service_payload(self) -> None:
        deleted_rows = [
            {
                "id": 1,
                "role": "client",
                "phone_hash": "del_1234567890abcdef",
                "deleted_at": datetime.utcnow(),
                "deletion_reason": "Demande utilisateur",
            }
        ]
        with patch(
            "app.api.admin.get_deleted_users",
            new=AsyncMock(return_value=deleted_rows),
        ):
            payload = await admin.admin_deleted_users_endpoint(
                _admin={},
                session=object(),
            )

        self.assertEqual(payload, deleted_rows)

    async def test_delete_user_endpoint_maps_related_data_conflict(self) -> None:
        with patch(
            "app.api.admin.delete_user",
            new=AsyncMock(
                side_effect=admin_service.AdminUserDeleteBlockedError(
                    "User has related data. Block this account instead."
                )
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await admin.admin_delete_user_endpoint(
                    user_id=12,
                    _admin={},
                    session=object(),
                )

        self.assertEqual(context.exception.status_code, 409)

    async def test_suspend_user_endpoint_returns_suspension_state(self) -> None:
        with patch(
            "app.api.admin.suspend_user",
            new=AsyncMock(
                return_value=SimpleNamespace(
                    id=19,
                    is_suspended=True,
                    suspended_until=None,
                    suspension_reason="Fraude",
                )
            ),
        ):
            payload = await admin.admin_suspend_user_endpoint(
                user_id=19,
                suspend_in=admin.AdminUserSuspendRequest(
                    reason="Fraude",
                    is_permanent=True,
                ),
                _admin={},
                session=object(),
            )

        self.assertTrue(payload["is_suspended"])
        self.assertEqual(payload["suspension_reason"], "Fraude")

    async def test_update_report_endpoint_maps_not_found(self) -> None:
        with patch(
            "app.api.admin.update_report",
            new=AsyncMock(
                side_effect=admin_service.AdminReportNotFoundError("missing")
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await admin.admin_update_report_endpoint(
                    report_id=77,
                    report_in=admin.RideReportAdminUpdate(
                        status=RideReportStatus.RESOLU,
                    ),
                    _admin={},
                    session=object(),
                )

        self.assertEqual(context.exception.status_code, 404)

    async def test_broadcast_endpoint_maps_unknown_user_to_404(self) -> None:
        with patch(
            "app.api.admin.send_notification_broadcast",
            new=AsyncMock(
                side_effect=admin_service.AdminUserNotFoundError("User not found")
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await admin.admin_notification_broadcast_endpoint(
                    broadcast_in=admin.AdminNotificationBroadcastRequest(
                        target=admin.AdminNotificationTarget.USER_ID,
                        user_id=9999,
                        title="Info plateforme",
                        message="Message test",
                        type=admin.AdminNotificationType.INFO,
                    ),
                    _admin={},
                    session=object(),
                )

        self.assertEqual(context.exception.status_code, 404)

    async def test_broadcast_endpoint_maps_rate_limit_to_429(self) -> None:
        with patch(
            "app.api.admin.send_notification_broadcast",
            new=AsyncMock(
                side_effect=admin_service.AdminNotificationRateLimitError(120)
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await admin.admin_notification_broadcast_endpoint(
                    broadcast_in=admin.AdminNotificationBroadcastRequest(
                        target=admin.AdminNotificationTarget.DRIVERS,
                        title="Alerte",
                        message="Forte demande ce soir",
                        type=admin.AdminNotificationType.ALERTE,
                    ),
                    _admin={},
                    session=object(),
                )

        self.assertEqual(context.exception.status_code, 429)
        self.assertEqual(context.exception.headers.get("Retry-After"), "120")


def _build_deletable_user(*, role: UserRole) -> SimpleNamespace:
    return SimpleNamespace(
        id=77,
        role=role,
        deleted_at=None,
        deletion_reason=None,
        name="Ali",
        phone_number="+22790000077",
        profile_photo="/uploads/profile_photos/avatar.jpg",
        refresh_token="refresh-token",
        fcm_token="fcm-token",
        is_blocked=False,
        is_suspended=False,
        suspended_until=None,
        suspension_reason=None,
        vehicle_brand="Toyota",
        vehicle_model="Yaris",
        vehicle_color="Blanc",
        vehicle_photo="vehicle.png",
        plate_number="AB-1234",
        is_available=True if role == UserRole.DRIVER else None,
        driver_status=DriverStatus.ONLINE if role == UserRole.DRIVER else None,
        pause_started_at=datetime.utcnow(),
    )


if __name__ == "__main__":
    unittest.main()
