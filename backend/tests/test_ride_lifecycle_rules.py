from pathlib import Path
import sys
import unittest
from decimal import Decimal
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.api_errors import ApiError
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import User, UserRole
from app.services import ride_lifecycle_service
from app.services.ride_policy import (
    ACTIVE_RIDE_STATUSES,
    CORE_RIDE_FLOW_STATUSES,
    apply_driver_cancellation_reset,
    apply_ride_completion,
    assert_transition_allowed,
    ensure_offer_acceptance_allowed,
    ensure_verified_driver,
    sync_ride_offer_state,
)


class RideLifecycleRulesTest(unittest.TestCase):
    def test_core_ride_flow_remains_linear(self) -> None:
        self.assertEqual(
            CORE_RIDE_FLOW_STATUSES,
            (
                RideRequestStatus.PENDING,
                RideRequestStatus.OFFERED,
                RideRequestStatus.ACCEPTED,
                RideRequestStatus.ARRIVED,
                RideRequestStatus.STARTED,
                RideRequestStatus.COMPLETED,
            ),
        )

        transitions = (
            (RideRequestStatus.PENDING, RideRequestStatus.OFFERED),
            (RideRequestStatus.OFFERED, RideRequestStatus.ACCEPTED),
            (RideRequestStatus.ACCEPTED, RideRequestStatus.ARRIVED),
            (RideRequestStatus.ARRIVED, RideRequestStatus.STARTED),
            (RideRequestStatus.STARTED, RideRequestStatus.COMPLETED),
        )
        for current_status, target_status in transitions:
            assert_transition_allowed(
                current_status=current_status,
                target_status=target_status,
            )

    def test_active_statuses_include_pending_offered_accepted_arrived_started(self) -> None:
        self.assertEqual(
            ACTIVE_RIDE_STATUSES,
            (
                RideRequestStatus.PENDING,
                RideRequestStatus.OFFERED,
                RideRequestStatus.ACCEPTED,
                RideRequestStatus.ARRIVED,
                RideRequestStatus.STARTED,
            ),
        )

    def test_offered_status_tracks_pending_offers(self) -> None:
        ride = RideRequest(status=RideRequestStatus.PENDING)

        sync_ride_offer_state(ride, pending_offer_count=1)
        self.assertEqual(ride.status, RideRequestStatus.OFFERED)

        sync_ride_offer_state(ride, pending_offer_count=0)
        self.assertEqual(ride.status, RideRequestStatus.PENDING)

    def test_started_requires_arrived(self) -> None:
        with self.assertRaises(ApiError) as context:
            assert_transition_allowed(
                current_status=RideRequestStatus.ACCEPTED,
                target_status=RideRequestStatus.STARTED,
            )

        self.assertEqual(context.exception.code, "ride_transition_not_allowed")

    def test_unverified_driver_cannot_join_lifecycle(self) -> None:
        with self.assertRaises(ApiError) as context:
            ensure_verified_driver(is_verified=False)

        self.assertEqual(context.exception.code, "driver_not_verified")

    def test_driver_cancellation_resets_accepted_ride_to_pending(self) -> None:
        ride = RideRequest(
            status=RideRequestStatus.ACCEPTED,
            driver_id=7,
            agreed_price=Decimal("4200.00"),
        )
        offer = RideOffer(
            ride_request_id=ride.id or 1,
            driver_id=7,
            proposed_price=Decimal("4200.00"),
            status=RideOfferStatus.ACCEPTED,
        )

        apply_driver_cancellation_reset(ride, accepted_offer=offer)

        self.assertEqual(ride.status, RideRequestStatus.PENDING)
        self.assertIsNone(ride.driver_id)
        self.assertEqual(offer.status, RideOfferStatus.INVALIDATED)

    def test_driver_cancellation_resets_arrived_ride_to_pending(self) -> None:
        ride = RideRequest(
            status=RideRequestStatus.ARRIVED,
            driver_id=8,
            agreed_price=Decimal("3900.00"),
        )

        apply_driver_cancellation_reset(ride, accepted_offer=None)

        self.assertEqual(ride.status, RideRequestStatus.PENDING)
        self.assertIsNone(ride.driver_id)
        self.assertIsNone(ride.agreed_price)

    def test_driver_cancellation_is_forbidden_after_start(self) -> None:
        ride = RideRequest(
            status=RideRequestStatus.STARTED,
            driver_id=9,
            agreed_price=Decimal("5100.00"),
        )

        with self.assertRaises(ApiError) as context:
            apply_driver_cancellation_reset(ride, accepted_offer=None)

        self.assertEqual(context.exception.code, "ride_transition_not_allowed")

    def test_completion_uses_locked_agreed_price(self) -> None:
        ride = RideRequest(
            status=RideRequestStatus.STARTED,
            agreed_price=Decimal("5000.00"),
        )

        apply_ride_completion(
            ride,
            commission_percent=Decimal("10.0"),
        )

        self.assertEqual(ride.status, RideRequestStatus.COMPLETED)
        self.assertEqual(ride.final_price, Decimal("5000.00"))
        self.assertEqual(ride.driver_net_earnings, Decimal("4500.00"))

    def test_second_offer_cannot_win_after_locked_acceptance_recheck(self) -> None:
        ride = RideRequest(
            status=RideRequestStatus.ACCEPTED,
            driver_id=12,
            agreed_price=Decimal("4600.00"),
        )
        late_offer = RideOffer(
            ride_request_id=ride.id or 1,
            driver_id=18,
            proposed_price=Decimal("4300.00"),
            status=RideOfferStatus.PENDING,
        )

        with self.assertRaises(ApiError) as context:
            ensure_offer_acceptance_allowed(
                ride=ride,
                offer=late_offer,
                driver_has_active_ride=False,
                driver_is_verified=True,
            )

        self.assertEqual(context.exception.code, "ride_already_assigned")

    def test_terminal_statuses_do_not_allow_more_transitions(self) -> None:
        terminal_statuses = (
            RideRequestStatus.COMPLETED,
            RideRequestStatus.CANCELLED,
            RideRequestStatus.EXPIRED,
        )

        for status in terminal_statuses:
            with self.assertRaises(ApiError) as context:
                assert_transition_allowed(
                    current_status=status,
                    target_status=RideRequestStatus.STARTED,
                )
            self.assertEqual(context.exception.code, "ride_transition_not_allowed")


class RideAcceptanceConcurrencyTest(unittest.IsolatedAsyncioTestCase):
    async def test_second_accept_is_rejected_if_another_offer_is_already_winning(self) -> None:
        session = AsyncMock()
        current_user = User(
            id=56,
            phone_number="+212600000056",
            role=UserRole.CLIENT,
        )
        winning_offer = RideOffer(
            id=1,
            ride_request_id=10,
            driver_id=201,
            proposed_price=Decimal("4200.00"),
            status=RideOfferStatus.ACCEPTED,
        )
        losing_offer = RideOffer(
            id=2,
            ride_request_id=10,
            driver_id=202,
            proposed_price=Decimal("4100.00"),
            status=RideOfferStatus.PENDING,
        )
        ride_request = RideRequest(
            id=10,
            client_id=current_user.id,
            status=RideRequestStatus.OFFERED,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service._get_offer_for_update",
                new=AsyncMock(return_value=losing_offer),
            ),
            patch(
                "app.services.ride_lifecycle_service._get_ride_for_update",
                new=AsyncMock(return_value=ride_request),
            ),
            patch(
                "app.services.ride_lifecycle_service._expire_ride_if_needed",
                new=AsyncMock(return_value=False),
            ),
            patch(
                "app.services.ride_lifecycle_service._get_ride_offers_for_update",
                new=AsyncMock(return_value=[winning_offer, losing_offer]),
            ),
        ):
            with self.assertRaises(ApiError) as context:
                await ride_lifecycle_service.accept_offer(
                    session=session,
                    offer_id=losing_offer.id,
                    current_user=current_user,
                )

        self.assertEqual(context.exception.code, "ride_already_assigned")
        session.commit.assert_not_awaited()
        self.assertEqual(winning_offer.status, RideOfferStatus.ACCEPTED)
        self.assertEqual(losing_offer.status, RideOfferStatus.PENDING)


if __name__ == "__main__":
    unittest.main()
