from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, Mock, patch

from fastapi import HTTPException

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.models.user import DriverStatus, UserRole
from app.services import auth_service


class RegisterRolePolicyTest(unittest.IsolatedAsyncioTestCase):
    async def test_unknown_number_creates_account_with_requested_role(self) -> None:
        session = SimpleNamespace(
            add=Mock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.auth_service.get_user_by_phone_number",
            new=AsyncMock(return_value=None),
        ):
            user = await auth_service.register(
                session,
                phone_number="+22790000001",
                name="Amina",
                role=UserRole.DRIVER,
            )

        self.assertEqual(user.phone_number, "+22790000001")
        self.assertEqual(user.role, UserRole.DRIVER)
        self.assertTrue(user.is_available)
        self.assertEqual(user.driver_status, DriverStatus.OFFLINE)
        session.commit.assert_awaited_once()
        session.refresh.assert_awaited_once_with(user)

    async def test_existing_number_same_role_keeps_account_unchanged(self) -> None:
        existing_user = SimpleNamespace(
            id=12,
            role=UserRole.CLIENT,
            is_blocked=False,
            is_suspended=False,
            name="Nadia",
        )
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.auth_service.get_user_by_phone_number",
            new=AsyncMock(return_value=existing_user),
        ), patch(
            "app.services.auth_service.ensure_user_not_suspended",
            new=AsyncMock(),
        ) as ensure_not_suspended_mock:
            result = await auth_service.register(
                session,
                phone_number="+22790000012",
                name="Nadia Update",
                role=UserRole.CLIENT,
            )

        self.assertIs(result, existing_user)
        self.assertEqual(existing_user.role, UserRole.CLIENT)
        self.assertEqual(existing_user.name, "Nadia")
        ensure_not_suspended_mock.assert_awaited_once_with(session, existing_user)
        session.commit.assert_not_awaited()

    async def test_existing_number_different_role_returns_409_without_override(self) -> None:
        existing_user = SimpleNamespace(
            id=13,
            role=UserRole.DRIVER,
            is_blocked=False,
            is_suspended=False,
        )
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.auth_service.get_user_by_phone_number",
            new=AsyncMock(return_value=existing_user),
        ):
            with self.assertRaises(HTTPException) as context:
                await auth_service.register(
                    session,
                    phone_number="+22790000013",
                    name="Moussa",
                    role=UserRole.CLIENT,
                )

        self.assertEqual(context.exception.status_code, 409)
        self.assertIn("chauffeur", str(context.exception.detail).lower())
        self.assertEqual(existing_user.role, UserRole.DRIVER)
        session.commit.assert_not_awaited()

    async def test_suspended_account_re_register_returns_403(self) -> None:
        existing_user = SimpleNamespace(
            id=14,
            role=UserRole.CLIENT,
            is_blocked=False,
            is_suspended=True,
        )
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.auth_service.get_user_by_phone_number",
            new=AsyncMock(return_value=existing_user),
        ):
            with self.assertRaises(HTTPException) as context:
                await auth_service.register(
                    session,
                    phone_number="+22790000014",
                    name="Ali",
                    role=UserRole.CLIENT,
                )

        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(
            context.exception.detail,
            auth_service.REGISTER_SUSPENDED_ACCOUNT_MESSAGE,
        )
        session.commit.assert_not_awaited()

    async def test_role_in_database_remains_unchanged_after_409(self) -> None:
        existing_user = SimpleNamespace(
            id=15,
            role=UserRole.CLIENT,
            is_blocked=False,
            is_suspended=False,
        )
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.auth_service.get_user_by_phone_number",
            new=AsyncMock(return_value=existing_user),
        ):
            with self.assertRaises(HTTPException):
                await auth_service.register(
                    session,
                    phone_number="+22790000015",
                    name="Test",
                    role=UserRole.DRIVER,
                )

        self.assertEqual(existing_user.role, UserRole.CLIENT)
        session.commit.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
