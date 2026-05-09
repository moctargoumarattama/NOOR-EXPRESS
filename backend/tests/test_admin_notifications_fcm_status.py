from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core import firebase
from app.services import admin_service


class FirebaseDeliveryResultTest(unittest.TestCase):
    def test_send_to_multiple_returns_not_configured_result(self) -> None:
        with patch("app.core.firebase._ensure_firebase", return_value=False):
            result = firebase.send_to_multiple(
                ["token-1", "token-2"],
                title="Info",
                body="Message",
            )

        self.assertFalse(result["success"])
        self.assertEqual(result["sent_count"], 0)
        self.assertEqual(result["failed_count"], 2)
        self.assertEqual(
            result["error_reason"],
            firebase.FIREBASE_NOT_CONFIGURED_REASON,
        )


class AdminBroadcastStatusTest(unittest.IsolatedAsyncioTestCase):
    async def test_broadcast_status_sent_when_everything_is_delivered(self) -> None:
        session = _SessionStub()
        with patch(
            "app.services.admin_service._resolve_broadcast_recipient_ids",
            new=AsyncMock(return_value=([1, 2], "drivers")),
        ), patch(
            "app.services.admin_service._enforce_broadcast_rate_limit",
            new=AsyncMock(),
        ), patch(
            "app.services.admin_service.notify_users_with_result",
            new=AsyncMock(
                return_value={
                    "success": True,
                    "sent_count": 2,
                    "failed_count": 0,
                    "error_reason": None,
                }
            ),
        ):
            payload = await admin_service.send_notification_broadcast(
                session,
                target="drivers",
                user_id=None,
                title="Info",
                message="Message",
                notification_type="info",
            )

        self.assertEqual(payload["fcm_status"], "sent")
        self.assertEqual(payload["fcm_sent_count"], 2)
        self.assertEqual(payload["fcm_failed_count"], 0)
        self.assertIsNone(payload["fcm_error_reason"])

    async def test_broadcast_status_partial_when_sent_and_failed_mix(self) -> None:
        session = _SessionStub()
        with patch(
            "app.services.admin_service._resolve_broadcast_recipient_ids",
            new=AsyncMock(return_value=([1, 2, 3, 4], "all")),
        ), patch(
            "app.services.admin_service._enforce_broadcast_rate_limit",
            new=AsyncMock(),
        ), patch(
            "app.services.admin_service.notify_users_with_result",
            new=AsyncMock(
                return_value={
                    "success": False,
                    "sent_count": 2,
                    "failed_count": 2,
                    "error_reason": "Timeout FCM",
                }
            ),
        ):
            payload = await admin_service.send_notification_broadcast(
                session,
                target="all",
                user_id=None,
                title="Alerte",
                message="Message",
                notification_type="alerte",
            )

        self.assertEqual(payload["fcm_status"], "partial")
        self.assertEqual(payload["fcm_sent_count"], 2)
        self.assertEqual(payload["fcm_failed_count"], 2)

    async def test_broadcast_status_failed_when_nothing_was_delivered(self) -> None:
        session = _SessionStub()
        with patch(
            "app.services.admin_service._resolve_broadcast_recipient_ids",
            new=AsyncMock(return_value=([5, 6], "passengers")),
        ), patch(
            "app.services.admin_service._enforce_broadcast_rate_limit",
            new=AsyncMock(),
        ), patch(
            "app.services.admin_service.notify_users_with_result",
            new=AsyncMock(
                return_value={
                    "success": False,
                    "sent_count": 0,
                    "failed_count": 2,
                    "error_reason": "Erreur FCM",
                }
            ),
        ):
            payload = await admin_service.send_notification_broadcast(
                session,
                target="passengers",
                user_id=None,
                title="Info",
                message="Message",
                notification_type="info",
            )

        self.assertEqual(payload["fcm_status"], "failed")
        self.assertEqual(payload["fcm_sent_count"], 0)
        self.assertEqual(payload["fcm_failed_count"], 2)

    async def test_broadcast_status_non_configured_when_firebase_missing(self) -> None:
        session = _SessionStub()
        with patch(
            "app.services.admin_service._resolve_broadcast_recipient_ids",
            new=AsyncMock(return_value=([7, 8, 9], "drivers")),
        ), patch(
            "app.services.admin_service._enforce_broadcast_rate_limit",
            new=AsyncMock(),
        ), patch(
            "app.services.admin_service.notify_users_with_result",
            new=AsyncMock(
                return_value={
                    "success": False,
                    "sent_count": 0,
                    "failed_count": 3,
                    "error_reason": firebase.FIREBASE_NOT_CONFIGURED_REASON,
                }
            ),
        ):
            payload = await admin_service.send_notification_broadcast(
                session,
                target="drivers",
                user_id=None,
                title="Info",
                message="Message",
                notification_type="info",
            )

        self.assertEqual(payload["fcm_status"], "firebase_not_configured")
        self.assertEqual(payload["fcm_sent_count"], 0)
        self.assertEqual(payload["fcm_failed_count"], 3)
        session.commit.assert_awaited_once()

    async def test_history_is_created_after_notification_dispatch(self) -> None:
        session = _SessionStub()
        events: list[str] = []

        async def notify_side_effect(*_args, **_kwargs) -> dict[str, object]:
            events.append("notify")
            self.assertEqual(len(session.added), 0)
            return {
                "success": True,
                "sent_count": 1,
                "failed_count": 0,
                "error_reason": None,
            }

        with patch(
            "app.services.admin_service._resolve_broadcast_recipient_ids",
            new=AsyncMock(return_value=([42], "user_id:42")),
        ), patch(
            "app.services.admin_service._enforce_broadcast_rate_limit",
            new=AsyncMock(),
        ), patch(
            "app.services.admin_service.notify_users_with_result",
            new=AsyncMock(side_effect=notify_side_effect),
        ):
            await admin_service.send_notification_broadcast(
                session,
                target="user_id",
                user_id=42,
                title="Info",
                message="Message",
                notification_type="info",
            )

        events.extend(session.events)
        self.assertGreaterEqual(len(events), 2)
        self.assertEqual(events[0], "notify")
        self.assertEqual(events[1], "add")


class _SessionStub:
    def __init__(self) -> None:
        self.added: list[object] = []
        self.events: list[str] = []
        self.commit = AsyncMock()
        self.refresh = AsyncMock()

    def add(self, value: object) -> None:
        self.added.append(value)
        self.events.append("add")


if __name__ == "__main__":
    unittest.main()
