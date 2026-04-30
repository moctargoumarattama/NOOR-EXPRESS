from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import admin
from app.models.user import DriverStatus, UserRole
from app.services import admin_service


class AdminUserManagementServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_block_user_marks_account_blocked_and_invalidates_tokens(self) -> None:
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


if __name__ == "__main__":
    unittest.main()
