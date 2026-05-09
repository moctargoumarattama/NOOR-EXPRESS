from datetime import datetime
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, Mock, patch

from fastapi import HTTPException

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.api import admin, driver
from app.models.user import User, UserRole
from app.models.withdrawal_request import WithdrawalRequest, WithdrawalRequestStatus
from app.services import wallet_service


class _ScalarOneOrNoneResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class WithdrawalRequestsServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_create_succeeds_if_due_amount_at_least_minimum(self) -> None:
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarOneOrNoneResult(None)),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            add=Mock(),
        )
        wallet = wallet_service.DriverWallet(
            driver_id=8,
            total_commission=Decimal("900.00"),
        )
        created = {}

        async def _fake_refresh(withdrawal) -> None:
            created["entity"] = withdrawal

        session.refresh = AsyncMock(side_effect=_fake_refresh)

        with (
            patch(
                "app.services.wallet_service.get_or_create_driver_wallet",
                new=AsyncMock(return_value=wallet),
            ),
            patch(
                "app.services.wallet_service.get_platform_commission_percent",
                new=AsyncMock(return_value=Decimal("12.50")),
            ),
        ):
            payload = await wallet_service.create_driver_withdrawal_request(
                session,
                driver_id=8,
                driver_note="  Reglement demain  ",
            )

        self.assertEqual(payload["amount_due"], 900.0)
        self.assertEqual(payload["commission_rate_snapshot"], 12.5)
        self.assertEqual(payload["driver_note"], "Reglement demain")
        self.assertEqual(payload["status"], WithdrawalRequestStatus.PENDING.value)
        session.commit.assert_awaited_once()
        session.add.assert_called_once()
        self.assertIn("entity", created)

    async def test_create_refused_if_due_amount_below_minimum(self) -> None:
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarOneOrNoneResult(None)),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            add=AsyncMock(),
        )
        wallet = wallet_service.DriverWallet(
            driver_id=8,
            total_commission=Decimal("400.00"),
        )

        with patch(
            "app.services.wallet_service.get_or_create_driver_wallet",
            new=AsyncMock(return_value=wallet),
        ):
            with self.assertRaises(wallet_service.WithdrawalRequestAmountTooLowError):
                await wallet_service.create_driver_withdrawal_request(
                    session,
                    driver_id=8,
                    driver_note="Besoin de regler en cash",
                )

        session.commit.assert_not_awaited()

    async def test_create_refused_if_pending_request_exists(self) -> None:
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarOneOrNoneResult("existing-id")),
            commit=AsyncMock(),
            refresh=AsyncMock(),
            add=AsyncMock(),
        )

        with self.assertRaises(wallet_service.WithdrawalRequestPendingConflictError):
            await wallet_service.create_driver_withdrawal_request(
                session,
                driver_id=11,
                driver_note=None,
            )

    async def test_confirm_decrements_wallet_and_sends_notification(self) -> None:
        withdrawal = WithdrawalRequest(
            id="req-1",
            driver_id=31,
            amount_due=Decimal("1200.00"),
            commission_rate_snapshot=Decimal("15.00"),
            status=WithdrawalRequestStatus.PENDING.value,
            created_at=datetime.utcnow(),
        )
        wallet = wallet_service.DriverWallet(
            driver_id=31,
            total_commission=Decimal("1800.00"),
        )
        session = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

        with (
            patch(
                "app.services.wallet_service._get_withdrawal_request_or_404",
                new=AsyncMock(return_value=withdrawal),
            ),
            patch(
                "app.services.wallet_service.get_or_create_driver_wallet",
                new=AsyncMock(return_value=wallet),
            ),
            patch("app.services.wallet_service.notify_user", new=AsyncMock()) as mocked_notify,
        ):
            payload = await wallet_service.resolve_admin_withdrawal_request(
                session,
                withdrawal_request_id="req-1",
                action="confirm",
                admin_id=7,
                admin_note="Recu en main propre",
            )

        self.assertEqual(wallet.total_commission, Decimal("600.00"))
        self.assertEqual(payload["status"], WithdrawalRequestStatus.CONFIRMED.value)
        self.assertEqual(payload["confirmed_by"], 7)
        mocked_notify.assert_awaited_once()

    async def test_reject_keeps_wallet_unchanged_and_sends_note(self) -> None:
        withdrawal = WithdrawalRequest(
            id="req-2",
            driver_id=42,
            amount_due=Decimal("900.00"),
            commission_rate_snapshot=Decimal("12.50"),
            status=WithdrawalRequestStatus.PENDING.value,
            created_at=datetime.utcnow(),
        )
        session = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

        with (
            patch(
                "app.services.wallet_service._get_withdrawal_request_or_404",
                new=AsyncMock(return_value=withdrawal),
            ),
            patch("app.services.wallet_service.notify_user", new=AsyncMock()) as mocked_notify,
        ):
            payload = await wallet_service.resolve_admin_withdrawal_request(
                session,
                withdrawal_request_id="req-2",
                action="reject",
                admin_id=9,
                admin_note="Verification manuelle necessaire",
            )

        self.assertEqual(payload["status"], WithdrawalRequestStatus.REJECTED.value)
        self.assertEqual(payload["admin_note"], "Verification manuelle necessaire")
        mocked_notify.assert_awaited_once()
        notify_call = mocked_notify.await_args
        self.assertIn("Verification manuelle necessaire", notify_call.kwargs["body"])

    async def test_cancel_pending_request_is_allowed(self) -> None:
        withdrawal = WithdrawalRequest(
            id="req-3",
            driver_id=55,
            amount_due=Decimal("700.00"),
            commission_rate_snapshot=Decimal("15.00"),
            status=WithdrawalRequestStatus.PENDING.value,
            created_at=datetime.utcnow(),
        )
        session = SimpleNamespace(delete=AsyncMock(), commit=AsyncMock())

        with patch(
            "app.services.wallet_service._get_withdrawal_request_or_404",
            new=AsyncMock(return_value=withdrawal),
        ):
            await wallet_service.cancel_driver_withdrawal_request(
                session,
                driver_id=55,
                withdrawal_request_id="req-3",
            )

        session.delete.assert_awaited_once()
        session.commit.assert_awaited_once()

    async def test_cancel_confirmed_request_is_refused(self) -> None:
        withdrawal = WithdrawalRequest(
            id="req-4",
            driver_id=55,
            amount_due=Decimal("700.00"),
            commission_rate_snapshot=Decimal("15.00"),
            status=WithdrawalRequestStatus.CONFIRMED.value,
            created_at=datetime.utcnow(),
        )
        session = SimpleNamespace(delete=AsyncMock(), commit=AsyncMock())

        with patch(
            "app.services.wallet_service._get_withdrawal_request_or_404",
            new=AsyncMock(return_value=withdrawal),
        ):
            with self.assertRaises(wallet_service.WithdrawalRequestStateConflictError):
                await wallet_service.cancel_driver_withdrawal_request(
                    session,
                    driver_id=55,
                    withdrawal_request_id="req-4",
                )

        session.delete.assert_not_awaited()


class WithdrawalRequestsApiTest(unittest.IsolatedAsyncioTestCase):
    async def test_driver_create_maps_low_amount_to_http_400(self) -> None:
        current_user = User(id=8, phone_number="+22790000008", role=UserRole.DRIVER)
        with patch(
            "app.api.driver.create_driver_withdrawal_request",
            new=AsyncMock(
                side_effect=wallet_service.WithdrawalRequestAmountTooLowError("too low")
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await driver.create_driver_withdrawal_request_endpoint(
                    request_in=driver.DriverWithdrawalCreateRequest(driver_note=None),
                    current_user=current_user,
                    session=object(),
                )
        self.assertEqual(context.exception.status_code, 400)

    async def test_driver_create_maps_pending_conflict_to_http_409(self) -> None:
        current_user = User(id=8, phone_number="+22790000008", role=UserRole.DRIVER)
        with patch(
            "app.api.driver.create_driver_withdrawal_request",
            new=AsyncMock(
                side_effect=wallet_service.WithdrawalRequestPendingConflictError(
                    "pending exists"
                )
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await driver.create_driver_withdrawal_request_endpoint(
                    request_in=driver.DriverWithdrawalCreateRequest(driver_note=None),
                    current_user=current_user,
                    session=object(),
                )
        self.assertEqual(context.exception.status_code, 409)

    async def test_admin_patch_maps_not_found_to_http_404(self) -> None:
        with patch(
            "app.api.admin.resolve_admin_withdrawal_request",
            new=AsyncMock(
                side_effect=wallet_service.WithdrawalRequestNotFoundError("not found")
            ),
        ):
            with self.assertRaises(HTTPException) as context:
                await admin.admin_resolve_withdrawal_request_endpoint(
                    withdrawal_request_id="missing",
                    resolve_in=admin.AdminWithdrawalResolveRequest(
                        action=admin.AdminWithdrawalAction.CONFIRM,
                        admin_note=None,
                    ),
                    _admin={"sub": "3"},
                    session=object(),
                )
        self.assertEqual(context.exception.status_code, 404)
