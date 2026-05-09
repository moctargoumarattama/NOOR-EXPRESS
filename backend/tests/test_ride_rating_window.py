from datetime import datetime, timedelta
from decimal import Decimal
import unittest

from app.models.ride_request import RideRequest, RideRequestStatus
from app.schemas.ride_request import ClientRideRatingCreate, DriverRideRatingCreate
from app.services.ride_request_service import _is_rating_window_expired


def _build_completed_ride(
    *,
    created_at: datetime,
    completed_at: datetime | None,
) -> RideRequest:
    return RideRequest(
        client_id=1,
        driver_id=2,
        pickup_location="A",
        dropoff_location="B",
        estimated_price=Decimal("1000.00"),
        status=RideRequestStatus.COMPLETED,
        created_at=created_at,
        completed_at=completed_at,
    )


class RideRatingWindowTests(unittest.TestCase):
    def test_rating_window_is_open_before_24h(self) -> None:
        now = datetime.utcnow()
        ride = _build_completed_ride(
            created_at=now - timedelta(hours=2),
            completed_at=now - timedelta(hours=23, minutes=59),
        )
        self.assertFalse(_is_rating_window_expired(ride, now=now))

    def test_rating_window_is_closed_after_24h(self) -> None:
        now = datetime.utcnow()
        ride = _build_completed_ride(
            created_at=now - timedelta(days=2),
            completed_at=now - timedelta(hours=25),
        )
        self.assertTrue(_is_rating_window_expired(ride, now=now))

    def test_rating_window_falls_back_to_created_at(self) -> None:
        now = datetime.utcnow()
        ride = _build_completed_ride(
            created_at=now - timedelta(hours=26),
            completed_at=None,
        )
        self.assertTrue(_is_rating_window_expired(ride, now=now))


class RideRatingCommentValidationTests(unittest.TestCase):
    def test_client_rating_comment_is_trimmed(self) -> None:
        payload = ClientRideRatingCreate(rating=5, comment="  excellent  ")
        self.assertEqual(payload.comment, "excellent")

    def test_driver_rating_comment_empty_string_becomes_none(self) -> None:
        payload = DriverRideRatingCreate(rating=4, comment="   ")
        self.assertIsNone(payload.comment)

