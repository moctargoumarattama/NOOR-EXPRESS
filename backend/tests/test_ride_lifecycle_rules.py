from pathlib import Path
import sys
import unittest
from datetime import datetime, timedelta
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

from pydantic import ValidationError

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.api_errors import ApiError
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import DriverStatus, User, UserRole
from app.realtime.schemas import NearbyDriverLocation
from app.schemas.ride_request import RideRequestCancel
from app.schemas.user import DriverRadiusUpdate, DriverStatusUpdate
from app.services import ride_lifecycle_service
from app.services import ride_offer_service
from app.services import ride_request_service
from app.services import user_service
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

    def test_active_statuses_include_pending_offered_accepted_arrived_started(
        self,
    ) -> None:
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
    async def test_second_accept_is_rejected_if_another_offer_is_already_winning(
        self,
    ) -> None:
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


class ActiveRideLookupTest(unittest.IsolatedAsyncioTestCase):
    async def test_active_ride_lookup_keeps_valid_client_ride(self) -> None:
        session = AsyncMock()
        ride_request = RideRequest(
            id=77,
            client_id=56,
            status=RideRequestStatus.ACCEPTED,
        )
        execute_result = Mock()
        execute_result.scalar_one_or_none.return_value = ride_request
        session.execute.return_value = execute_result
        current_user = User(
            id=56,
            phone_number="+212600000056",
            role=UserRole.CLIENT,
        )

        with patch(
            "app.services.ride_lifecycle_service.expire_ride",
            new=AsyncMock(return_value=ride_request),
        ):
            result = await ride_request_service.get_active_ride_request(
                session,
                current_user,
            )

        self.assertIs(result, ride_request)
        session.execute.assert_awaited_once()


class RideSuspensionRulesTest(unittest.IsolatedAsyncioTestCase):
    async def test_suspended_client_cannot_create_ride_request(self) -> None:
        suspended_client = User(
            id=91,
            phone_number="+22790000091",
            role=UserRole.CLIENT,
            is_suspended=True,
            suspension_reason="Abus",
        )
        ride_in = SimpleNamespace(
            pickup_location="Rond-point Kennedy",
            dropoff_location="Plateau",
            client_latitude=13.5116,
            client_longitude=2.1254,
            dropoff_latitude=13.5340,
            dropoff_longitude=2.1090,
            estimated_price=None,
        )

        with self.assertRaises(ApiError) as context:
            await ride_lifecycle_service.create_ride(
                session=AsyncMock(),
                ride_request_in=ride_in,
                current_user=suspended_client,
            )

        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(context.exception.code, "account_suspended")

    async def test_suspended_driver_cannot_create_offer(self) -> None:
        ride_request = RideRequest(
            id=17,
            client_id=5,
            status=RideRequestStatus.PENDING,
            pickup_location="A",
            dropoff_location="B",
            estimated_price=Decimal("2000.00"),
        )
        suspended_driver = User(
            id=72,
            phone_number="+22790000072",
            role=UserRole.DRIVER,
            is_suspended=True,
            suspension_reason="Fraude",
        )
        session = SimpleNamespace(
            get=AsyncMock(side_effect=[ride_request, suspended_driver]),
        )

        with self.assertRaises(ApiError) as context:
            await ride_offer_service.create_offer(
                session=session,
                ride_id=17,
                driver_id=72,
                proposed_price=Decimal("2200.00"),
            )

        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(context.exception.code, "account_suspended")


class DriverStatsCacheInvalidationOnCompletionTest(unittest.IsolatedAsyncioTestCase):
    async def test_complete_ride_invalidates_driver_stats_cache(self) -> None:
        current_driver = User(
            id=44,
            phone_number="+22790000044",
            role=UserRole.DRIVER,
        )
        ride = RideRequest(
            id=504,
            client_id=10,
            driver_id=current_driver.id,
            status=RideRequestStatus.STARTED,
            estimated_price=Decimal("3500.00"),
            agreed_price=Decimal("4200.00"),
        )

        with (
            patch(
                "app.services.ride_lifecycle_service._get_driver_assigned_ride",
                new=AsyncMock(return_value=ride),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_platform_commission_percent",
                new=AsyncMock(return_value=Decimal("15.00")),
            ),
            patch(
                "app.services.ride_lifecycle_service.sync_completed_ride_to_wallet",
                new=AsyncMock(),
            ),
            patch(
                "app.services.ride_lifecycle_service.invalidate_driver_dashboard_stats_cache",
                new=Mock(),
            ) as mocked_cache_invalidate,
            patch(
                "app.services.ride_lifecycle_service.update_driver_status",
                new=AsyncMock(),
            ),
            patch(
                "app.services.ride_lifecycle_service._notify_client_status",
                new=AsyncMock(),
            ),
            patch(
                "app.services.ride_lifecycle_service.notify_user",
                new=AsyncMock(),
            ),
        ):
            session = AsyncMock()
            await ride_lifecycle_service.complete_ride(
                session=session,
                ride_request_id=ride.id,
                current_user=current_driver,
            )

        mocked_cache_invalidate.assert_called_once_with(current_driver.id)


class RideCancellationPolicyTest(unittest.IsolatedAsyncioTestCase):
    async def test_first_passenger_cancellation_allows_missing_reason(self) -> None:
        session = AsyncMock()
        current_user = User(
            id=56,
            phone_number="+22790000056",
            role=UserRole.CLIENT,
            cancellations_today=0,
            cancellations_last_24h=0,
        )
        ride = RideRequest(
            id=901,
            client_id=current_user.id,
            status=RideRequestStatus.PENDING,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service._get_ride_for_update",
                new=AsyncMock(return_value=ride),
            ),
            patch(
                "app.services.ride_lifecycle_service._expire_ride_if_needed",
                new=AsyncMock(return_value=False),
            ),
            patch(
                "app.services.ride_lifecycle_service._get_ride_offers_for_update",
                new=AsyncMock(return_value=[]),
            ),
            patch(
                "app.services.ride_lifecycle_service.notify_user",
                new=AsyncMock(),
            ),
            patch(
                "app.services.ride_lifecycle_service.ride_notifier.send_offer_rejected_notification",
                new=AsyncMock(),
            ),
        ):
            result = await ride_lifecycle_service.cancel_by_client(
                session=session,
                ride_request_id=ride.id,
                current_user=current_user,
                ride_request_cancel_in=RideRequestCancel(),
            )

        self.assertIs(result, ride)
        self.assertEqual(ride.status, RideRequestStatus.CANCELLED)
        self.assertEqual(current_user.cancellations_today, 1)
        self.assertEqual(current_user.cancellations_last_24h, 1)
        session.commit.assert_awaited_once()

    async def test_second_passenger_cancellation_without_reason_is_rejected(self) -> None:
        session = AsyncMock()
        current_user = User(
            id=56,
            phone_number="+22790000056",
            role=UserRole.CLIENT,
            cancellations_today=1,
            cancellations_last_24h=1,
            cancellation_window_started_at=datetime.utcnow(),
        )
        ride = RideRequest(
            id=902,
            client_id=current_user.id,
            status=RideRequestStatus.PENDING,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service._get_ride_for_update",
                new=AsyncMock(return_value=ride),
            ),
            patch(
                "app.services.ride_lifecycle_service._expire_ride_if_needed",
                new=AsyncMock(return_value=False),
            ),
        ):
            with self.assertRaises(ApiError) as context:
                await ride_lifecycle_service.cancel_by_client(
                    session=session,
                    ride_request_id=ride.id,
                    current_user=current_user,
                    ride_request_cancel_in=RideRequestCancel(),
                )

        self.assertEqual(context.exception.status_code, 422)
        self.assertEqual(
            context.exception.code,
            "passenger_cancellation_reason_required",
        )
        session.commit.assert_not_awaited()

    async def test_fifth_passenger_cancellation_blocks_new_request_for_two_hours(self) -> None:
        session = AsyncMock()
        now = datetime.utcnow()
        current_user = User(
            id=56,
            phone_number="+22790000056",
            role=UserRole.CLIENT,
            cancellations_today=4,
            cancellations_last_24h=4,
            cancellation_window_started_at=now - timedelta(hours=1),
        )
        ride = RideRequest(
            id=903,
            client_id=current_user.id,
            status=RideRequestStatus.PENDING,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service._get_ride_for_update",
                new=AsyncMock(return_value=ride),
            ),
            patch(
                "app.services.ride_lifecycle_service._expire_ride_if_needed",
                new=AsyncMock(return_value=False),
            ),
            patch(
                "app.services.ride_lifecycle_service._get_ride_offers_for_update",
                new=AsyncMock(return_value=[]),
            ),
            patch(
                "app.services.ride_lifecycle_service.notify_user",
                new=AsyncMock(),
            ),
            patch(
                "app.services.ride_lifecycle_service.ride_notifier.send_offer_rejected_notification",
                new=AsyncMock(),
            ),
        ):
            await ride_lifecycle_service.cancel_by_client(
                session=session,
                ride_request_id=ride.id,
                current_user=current_user,
                ride_request_cancel_in=RideRequestCancel(
                    reason_code="other_transport",
                ),
            )

        self.assertEqual(current_user.cancellations_last_24h, 5)
        self.assertIsNotNone(current_user.ride_request_blocked_until)
        assert current_user.ride_request_blocked_until is not None
        self.assertGreater(
            current_user.ride_request_blocked_until - now,
            timedelta(hours=1, minutes=55),
        )

        with patch(
            "app.services.ride_lifecycle_service.ensure_user_not_suspended",
            new=AsyncMock(),
        ):
            with self.assertRaises(ApiError) as context:
                await ride_lifecycle_service.create_ride(
                    session=AsyncMock(),
                    ride_request_in=SimpleNamespace(),
                    current_user=current_user,
                )

        self.assertEqual(
            context.exception.code,
            ride_lifecycle_service.PASSENGER_BLOCK_ERROR_CODE,
        )

    async def test_driver_cancellation_requires_reason(self) -> None:
        current_driver = User(
            id=72,
            phone_number="+22790000072",
            role=UserRole.DRIVER,
            cancellations_today=0,
            cancellations_last_24h=0,
        )
        ride = RideRequest(
            id=904,
            client_id=10,
            driver_id=current_driver.id,
            status=RideRequestStatus.ACCEPTED,
        )

        with patch(
            "app.services.ride_lifecycle_service._get_driver_assigned_ride",
            new=AsyncMock(return_value=ride),
        ), patch(
            "app.services.ride_lifecycle_service._get_ride_offers_for_update",
            new=AsyncMock(return_value=[]),
        ):
            with self.assertRaises(ApiError) as context:
                await ride_lifecycle_service.cancel_by_driver(
                    session=AsyncMock(),
                    ride_request_id=ride.id,
                    current_user=current_driver,
                    ride_request_cancel_in=RideRequestCancel(),
                )

        self.assertEqual(context.exception.status_code, 422)
        self.assertEqual(
            context.exception.code,
            "driver_cancellation_reason_required",
        )

    def test_cancellation_24h_counter_resets_after_window(self) -> None:
        user = User(
            id=81,
            phone_number="+22790000081",
            role=UserRole.CLIENT,
            cancellations_today=7,
            cancellations_last_24h=4,
            cancellation_window_started_at=datetime.utcnow() - timedelta(hours=25),
        )
        now = datetime.utcnow()

        today_count, last_24h_count = ride_lifecycle_service._register_user_cancellation_event(
            user,
            now=now,
        )

        self.assertEqual(today_count, 8)
        self.assertEqual(last_24h_count, 1)
        self.assertEqual(user.cancellation_window_started_at, now)


class DriverRadiusMatchingRulesTest(unittest.IsolatedAsyncioTestCase):
    async def test_progressive_matching_expands_radius_until_three_drivers(self) -> None:
        side_effect_batches = [
            [
                NearbyDriverLocation(
                    driver_id=1,
                    latitude=13.5100,
                    longitude=2.1200,
                    distance_km=1.2,
                )
            ],
            [
                NearbyDriverLocation(
                    driver_id=1,
                    latitude=13.5100,
                    longitude=2.1200,
                    distance_km=1.2,
                ),
                NearbyDriverLocation(
                    driver_id=2,
                    latitude=13.5140,
                    longitude=2.1180,
                    distance_km=2.4,
                ),
            ],
            [
                NearbyDriverLocation(
                    driver_id=1,
                    latitude=13.5100,
                    longitude=2.1200,
                    distance_km=1.2,
                ),
                NearbyDriverLocation(
                    driver_id=2,
                    latitude=13.5140,
                    longitude=2.1180,
                    distance_km=2.4,
                ),
                NearbyDriverLocation(
                    driver_id=3,
                    latitude=13.5200,
                    longitude=2.1100,
                    distance_km=4.8,
                ),
            ],
        ]

        with patch(
            "app.services.ride_lifecycle_service._get_available_verified_nearby_drivers",
            new=AsyncMock(side_effect=side_effect_batches),
        ) as mocked_available:
            drivers, search_radius = await ride_lifecycle_service._get_progressive_available_nearby_drivers(
                session=object(),
                latitude=13.5116,
                longitude=2.1254,
            )

        self.assertEqual(len(drivers), 3)
        self.assertEqual(search_radius, 10.0)
        self.assertEqual(mocked_available.await_count, 3)
        searched_radii = [
            call.kwargs["max_distance_km"] for call in mocked_available.await_args_list
        ]
        self.assertEqual(searched_radii, [3.0, 5.0, 10.0])

    async def test_driver_outside_own_radius_is_hidden_from_matching(self) -> None:
        nearby_drivers = [
            NearbyDriverLocation(
                driver_id=18,
                latitude=13.5340,
                longitude=2.1090,
                distance_km=4.0,
            ),
            NearbyDriverLocation(
                driver_id=21,
                latitude=13.5200,
                longitude=2.1150,
                distance_km=2.0,
            ),
        ]
        online_drivers = [
            User(
                id=18,
                phone_number="+22790000018",
                role=UserRole.DRIVER,
                max_radius_km=3,
            ),
            User(
                id=21,
                phone_number="+22790000021",
                role=UserRole.DRIVER,
                max_radius_km=3,
            ),
        ]

        with (
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(return_value=nearby_drivers),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_drivers_by_status",
                new=AsyncMock(return_value=online_drivers),
            ),
            patch(
                "app.services.ride_lifecycle_service._is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
        ):
            matched = await ride_lifecycle_service._get_available_verified_nearby_drivers(
                session=object(),
                latitude=13.5116,
                longitude=2.1254,
                max_distance_km=10.0,
            )

        self.assertEqual([driver.driver_id for driver in matched], [21])

    async def test_driver_inside_own_radius_remains_visible_for_matching(self) -> None:
        nearby_drivers = [
            NearbyDriverLocation(
                driver_id=22,
                latitude=13.5150,
                longitude=2.1200,
                distance_km=2.0,
            )
        ]
        online_drivers = [
            User(
                id=22,
                phone_number="+22790000022",
                role=UserRole.DRIVER,
                max_radius_km=3,
            )
        ]

        with (
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(return_value=nearby_drivers),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_drivers_by_status",
                new=AsyncMock(return_value=online_drivers),
            ),
            patch(
                "app.services.ride_lifecycle_service._is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
        ):
            matched = await ride_lifecycle_service._get_available_verified_nearby_drivers(
                session=object(),
                latitude=13.5116,
                longitude=2.1254,
                max_distance_km=10.0,
            )

        self.assertEqual([driver.driver_id for driver in matched], [22])

    def test_driver_radius_schema_rejects_0_and_11_km(self) -> None:
        with self.assertRaises(ValidationError):
            DriverRadiusUpdate(max_radius_km=0)
        with self.assertRaises(ValidationError):
            DriverRadiusUpdate(max_radius_km=11)

    async def test_driver_paused_is_hidden_from_matching(self) -> None:
        now = datetime.utcnow()
        nearby_drivers = [
            NearbyDriverLocation(
                driver_id=33,
                latitude=13.5150,
                longitude=2.1200,
                distance_km=2.0,
            )
        ]
        paused_driver = User(
            id=33,
            phone_number="+22790000033",
            role=UserRole.DRIVER,
            driver_status=DriverStatus.PAUSED,
            is_available=True,
            pause_started_at=now - timedelta(minutes=10),
            max_radius_km=5,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(return_value=nearby_drivers),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_drivers_by_status",
                new=AsyncMock(side_effect=[[], [paused_driver]]),
            ),
            patch(
                "app.services.ride_lifecycle_service.update_driver_status",
                new=AsyncMock(),
            ) as mocked_update_driver_status,
        ):
            matched = await ride_lifecycle_service._get_available_verified_nearby_drivers(
                session=object(),
                latitude=13.5116,
                longitude=2.1254,
                max_distance_km=10.0,
            )

        self.assertEqual(matched, [])
        mocked_update_driver_status.assert_not_awaited()

    async def test_driver_pause_over_30_minutes_is_auto_resumed_to_online(self) -> None:
        now = datetime.utcnow()
        nearby_drivers = [
            NearbyDriverLocation(
                driver_id=34,
                latitude=13.5150,
                longitude=2.1200,
                distance_km=2.0,
            )
        ]
        paused_driver = User(
            id=34,
            phone_number="+22790000034",
            role=UserRole.DRIVER,
            driver_status=DriverStatus.PAUSED,
            is_available=True,
            pause_started_at=now - timedelta(minutes=31),
            max_radius_km=5,
        )
        resumed_driver = User(
            id=34,
            phone_number="+22790000034",
            role=UserRole.DRIVER,
            driver_status=DriverStatus.ONLINE,
            is_available=True,
            max_radius_km=5,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service.driver_locator.get_nearby_drivers",
                new=AsyncMock(return_value=nearby_drivers),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_drivers_by_status",
                new=AsyncMock(side_effect=[[], [paused_driver]]),
            ),
            patch(
                "app.services.ride_lifecycle_service.update_driver_status",
                new=AsyncMock(return_value=resumed_driver),
            ) as mocked_update_driver_status,
            patch(
                "app.services.ride_lifecycle_service._is_driver_verified",
                new=AsyncMock(return_value=True),
            ),
        ):
            matched = await ride_lifecycle_service._get_available_verified_nearby_drivers(
                session=object(),
                latitude=13.5116,
                longitude=2.1254,
                max_distance_km=10.0,
            )

        self.assertEqual([driver.driver_id for driver in matched], [34])
        mocked_update_driver_status.assert_awaited_once()


class DriverStatusCycleRulesTest(unittest.IsolatedAsyncioTestCase):
    async def test_driver_status_cycle_offline_online_paused(self) -> None:
        driver = User(
            id=41,
            phone_number="+22790000041",
            role=UserRole.DRIVER,
            driver_status=DriverStatus.ONLINE,
            is_available=True,
        )
        session = SimpleNamespace(
            get=AsyncMock(return_value=driver),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with patch(
            "app.services.user_service.is_driver_verified",
            new=AsyncMock(return_value=True),
        ):
            await user_service.update_driver_presence_status(
                session,
                driver.id,
                DriverStatusUpdate(status=DriverStatus.OFFLINE),
            )
            self.assertEqual(driver.driver_status, DriverStatus.OFFLINE)
            self.assertFalse(driver.is_available)
            self.assertIsNone(driver.pause_started_at)

            await user_service.update_driver_presence_status(
                session,
                driver.id,
                DriverStatusUpdate(status=DriverStatus.ONLINE),
            )
            self.assertEqual(driver.driver_status, DriverStatus.ONLINE)
            self.assertTrue(driver.is_available)
            self.assertIsNone(driver.pause_started_at)

            await user_service.update_driver_presence_status(
                session,
                driver.id,
                DriverStatusUpdate(status=DriverStatus.PAUSED),
            )
            self.assertEqual(driver.driver_status, DriverStatus.PAUSED)
            self.assertTrue(driver.is_available)
            self.assertIsNotNone(driver.pause_started_at)


if __name__ == "__main__":
    unittest.main()
