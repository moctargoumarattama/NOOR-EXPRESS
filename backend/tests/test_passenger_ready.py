from datetime import datetime
from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.api_errors import ApiError
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import User, UserRole
from app.services import ride_request_service


class PassengerReadyServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_marks_passenger_ready_when_ride_is_arrived(self) -> None:
        current_user = User(
            id=45,
            phone_number="+22790000045",
            role=UserRole.CLIENT,
            name="Amina Issoufou",
        )
        ride_request = RideRequest(
            id=500,
            client_id=current_user.id,
            driver_id=17,
            status=RideRequestStatus.ARRIVED,
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=ride_request)

        with (
            patch(
                "app.services.ride_request_service.ride_notifier.send_passenger_ready_notification_to_driver",
                new=AsyncMock(),
            ) as mocked_notify,
        ):
            payload = await ride_request_service.mark_passenger_ready(
                session=session,
                ride_request_id=ride_request.id,
                current_user=current_user,
            )

        self.assertIs(payload, ride_request)
        self.assertIsNotNone(ride_request.passenger_ready_at)
        session.commit.assert_awaited_once()
        session.refresh.assert_awaited_once_with(ride_request)
        mocked_notify.assert_awaited_once()
        sent_notification = mocked_notify.await_args.kwargs["notification"]
        self.assertEqual(sent_notification.type, "passenger_ready")
        self.assertEqual(sent_notification.ride_id, str(ride_request.id))
        self.assertEqual(sent_notification.passenger_name, "Amina")

    async def test_rejects_when_ride_is_not_arrived(self) -> None:
        current_user = User(
            id=46,
            phone_number="+22790000046",
            role=UserRole.CLIENT,
        )
        ride_request = RideRequest(
            id=501,
            client_id=current_user.id,
            driver_id=18,
            status=RideRequestStatus.ACCEPTED,
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=ride_request)

        with self.assertRaises(ApiError) as context:
            await ride_request_service.mark_passenger_ready(
                session=session,
                ride_request_id=ride_request.id,
                current_user=current_user,
            )

        self.assertEqual(context.exception.status_code, 409)
        self.assertEqual(context.exception.code, "ride_not_arrived")
        session.commit.assert_not_awaited()
        session.refresh.assert_not_awaited()

    async def test_second_call_is_idempotent_without_overwrite(self) -> None:
        current_user = User(
            id=47,
            phone_number="+22790000047",
            role=UserRole.CLIENT,
            name="Moussa",
        )
        ready_at = datetime(2026, 5, 5, 10, 0, 0)
        ride_request = RideRequest(
            id=502,
            client_id=current_user.id,
            driver_id=19,
            status=RideRequestStatus.ARRIVED,
            passenger_ready_at=ready_at,
        )
        session = AsyncMock()
        session.get = AsyncMock(return_value=ride_request)

        with (
            patch(
                "app.services.ride_request_service.ride_notifier.send_passenger_ready_notification_to_driver",
                new=AsyncMock(),
            ) as mocked_notify,
        ):
            payload = await ride_request_service.mark_passenger_ready(
                session=session,
                ride_request_id=ride_request.id,
                current_user=current_user,
            )

        self.assertIs(payload, ride_request)
        self.assertEqual(ride_request.passenger_ready_at, ready_at)
        session.commit.assert_not_awaited()
        session.refresh.assert_not_awaited()
        mocked_notify.assert_not_awaited()


if __name__ == "__main__":
    unittest.main()
