from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, patch

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from scripts import create_admin as create_admin_script
from app.services.admin_service import AdminAlreadyExistsError


class _AsyncSessionContext:
    def __init__(self, session: object) -> None:
        self._session = session

    async def __aenter__(self) -> object:
        return self._session

    async def __aexit__(self, exc_type, exc, tb) -> None:
        return None


class CreateAdminScriptTest(unittest.IsolatedAsyncioTestCase):
    async def test_create_admin_script_creates_admin_account(self) -> None:
        session = object()
        with patch(
            "scripts.create_admin.AsyncSessionLocal",
            return_value=_AsyncSessionContext(session),
        ), patch(
            "scripts.create_admin.create_admin",
            new=AsyncMock(return_value=SimpleNamespace(username="root-admin")),
        ) as create_admin_mock:
            exit_code = await create_admin_script._create_first_admin(
                username="root-admin",
                password="super-secret",
            )

        self.assertEqual(exit_code, 0)
        create_admin_mock.assert_awaited_once_with(
            session,
            username="root-admin",
            password="super-secret",
        )

    async def test_create_admin_script_returns_error_if_admin_exists(self) -> None:
        session = object()
        with patch(
            "scripts.create_admin.AsyncSessionLocal",
            return_value=_AsyncSessionContext(session),
        ), patch(
            "scripts.create_admin.create_admin",
            new=AsyncMock(side_effect=AdminAlreadyExistsError("already")),
        ):
            exit_code = await create_admin_script._create_first_admin(
                username="root-admin",
                password="super-secret",
            )

        self.assertEqual(exit_code, 1)


if __name__ == "__main__":
    unittest.main()
