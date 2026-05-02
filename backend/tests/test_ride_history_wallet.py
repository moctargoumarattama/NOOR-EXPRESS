from decimal import Decimal
import importlib
import importlib.util
from pathlib import Path
from types import SimpleNamespace
from uuid import UUID
import sys
import unittest
from unittest.mock import AsyncMock, Mock, patch

from pydantic import ValidationError

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import SavedAddress, User, UserRole
from app.core.api_errors import ApiError
from app.schemas.pricing import PriceEstimateRead
from app.schemas.driver_wallet import (
    CommissionLedgerRead,
    DriverDashboardStatsRead,
    DriverPeakHourStatsRead,
    DriverReputationStatsRead,
    DriverRevenueStatsRead,
    DriverRideStatusStatsRead,
    DriverZoneProfitabilityRead,
    DriverWalletSummaryRead,
    EarningsWindowRead,
)
from app.schemas.ride_request import RideRequestCreate
from app.schemas.user import SavedAddressCreate, SavedAddressUpdate
from app.api import admin, driver, pricing, ride_request
from app.services import ride_lifecycle_service, user_service, wallet_service
from app.services import ride_request_service


class RideCreationMetricsTest(unittest.IsolatedAsyncioTestCase):
    async def test_create_ride_stores_route_distance_and_duration(self) -> None:
        captured: dict[str, RideRequest] = {}

        session = SimpleNamespace(
            add=Mock(side_effect=lambda ride: captured.setdefault("ride", ride)),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )
        current_user = User(
            id=45,
            phone_number="+22790000045",
            role=UserRole.CLIENT,
        )
        ride_in = RideRequestCreate(
            pickup_location="Hopital National",
            dropoff_location="Grand Marche",
            client_latitude=13.5116,
            client_longitude=2.1254,
            dropoff_latitude=13.5340,
            dropoff_longitude=2.1090,
        )

        with (
            patch(
                "app.services.ride_lifecycle_service._get_active_client_ride",
                new=AsyncMock(return_value=None),
            ),
            patch(
                "app.services.ride_lifecycle_service.calculate_ride_price",
                new=AsyncMock(return_value={"final_estimated_price": 2800}),
            ),
            patch(
                "app.services.ride_lifecycle_service.get_route_payload",
                new=AsyncMock(
                    return_value={
                        "polyline": [[13.5116, 2.1254], [13.5340, 2.1090]],
                        "distance_km": 3.97,
                        "duration_min": 8,
                    }
                ),
            ),
            patch(
                "app.services.ride_lifecycle_service._notify_matching_drivers_for_ride",
                new=AsyncMock(),
            ),
        ):
            await ride_lifecycle_service.create_ride(
                session=session,
                ride_request_in=ride_in,
                current_user=current_user,
            )

        self.assertEqual(captured["ride"].distance_km, 3.97)
        self.assertEqual(captured["ride"].duration_minutes, 8)


class DriverWalletAccumulatorTest(unittest.TestCase):
    def test_apply_completed_ride_to_wallet_accumulates_totals(self) -> None:
        wallet = wallet_service.DriverWallet(
            driver_id=9,
            total_completed_rides=2,
            total_gross_earnings=Decimal("7000.00"),
            total_commission=Decimal("1050.00"),
            total_net_earnings=Decimal("5950.00"),
        )
        completed_ride = RideRequest(
            id=18,
            driver_id=9,
            status=RideRequestStatus.COMPLETED,
            final_price=Decimal("5000.00"),
            platform_commission=Decimal("750.00"),
            driver_net_earnings=Decimal("4250.00"),
        )

        wallet_service.apply_completed_ride_to_wallet(wallet, completed_ride)

        self.assertEqual(wallet.total_completed_rides, 3)
        self.assertEqual(wallet.total_gross_earnings, Decimal("12000.00"))
        self.assertEqual(wallet.total_commission, Decimal("1800.00"))
        self.assertEqual(wallet.total_net_earnings, Decimal("10200.00"))


class DriverWalletEndpointsTest(unittest.IsolatedAsyncioTestCase):
    async def test_driver_wallet_endpoint_returns_service_summary(self) -> None:
        current_user = User(
            id=9,
            phone_number="+22790000009",
            role=UserRole.DRIVER,
        )
        summary = DriverWalletSummaryRead(
            driver_id=9,
            today=EarningsWindowRead(
                rides_count=1,
                gross_amount=2800,
                commission_amount=420,
                net_amount=2380,
            ),
            week=EarningsWindowRead(
                rides_count=4,
                gross_amount=12500,
                commission_amount=1875,
                net_amount=10625,
            ),
            total=EarningsWindowRead(
                rides_count=28,
                gross_amount=80500,
                commission_amount=12075,
                net_amount=68425,
            ),
        )

        with patch(
            "app.api.driver.get_driver_wallet_summary",
            new=AsyncMock(return_value=summary),
        ):
            payload = await driver.get_driver_wallet_summary_endpoint(
                current_user=current_user,
                session=object(),
            )

        self.assertEqual(payload, summary)

    async def test_admin_commission_ledger_endpoint_forwards_filters(self) -> None:
        ledger = CommissionLedgerRead(
            total_count=1,
            total_gross_amount=2800,
            total_commission_amount=420,
            total_net_amount=2380,
            items=[],
        )

        with patch(
            "app.api.admin.get_admin_commission_ledger",
            new=AsyncMock(return_value=ledger),
        ) as mocked_service:
            payload = await admin.admin_commission_ledger_endpoint(
                _admin={},
                session=object(),
                driver_id=9,
                date_from=None,
                date_to=None,
                limit=50,
                offset=10,
            )

        self.assertEqual(payload, ledger)
        mocked_service.assert_awaited_once()

    async def test_driver_dashboard_stats_endpoint_returns_service_payload(
        self,
    ) -> None:
        current_user = User(
            id=19,
            phone_number="+22790000019",
            role=UserRole.DRIVER,
        )
        dashboard = DriverDashboardStatsRead(
            driver_id=19,
            revenue=DriverRevenueStatsRead(
                today=2400.0,
                week=8900.0,
                month=30200.0,
                total=78400.0,
            ),
            rides=DriverRideStatusStatsRead(
                completed=22,
                cancelled=3,
                refused=5,
            ),
            peak_hours=[
                DriverPeakHourStatsRead(
                    hour=hour,
                    completed_rides=0,
                    average_revenue=0.0,
                )
                for hour in range(24)
            ],
            profitable_zones=[
                DriverZoneProfitabilityRead(
                    zone_name="Plateau",
                    rides_count=7,
                    average_revenue=2900.0,
                )
            ],
            reputation=DriverReputationStatsRead(
                last_30_days=4.6,
                global_average=4.4,
            ),
        )

        with patch(
            "app.api.driver.get_driver_dashboard_stats",
            new=AsyncMock(return_value=dashboard),
        ) as mocked_service:
            payload = await driver.get_driver_dashboard_stats_endpoint(
                current_user=current_user,
                session=object(),
            )

        self.assertEqual(payload, dashboard)
        mocked_service.assert_awaited_once()


class RideEstimateEndpointsTest(unittest.IsolatedAsyncioTestCase):
    async def test_pricing_estimate_endpoint_keeps_compatibility_with_enriched_payload(
        self,
    ) -> None:
        estimate = {
            "estimated_price": 2500.0,
            "distance_km": 6.4,
            "duration_min": 18,
            "pickup_zone": "Plateau",
            "dropoff_zone": "Aeroport",
            "base_price": 1500.0,
            "price_per_km": 300.0,
            "applied_mode": "mixed_distance",
            "applied_zone_rule": None,
            "applied_time_rule": None,
            "platform_commission_preview": 375.0,
            "min_price": 2200.0,
            "max_price": 2800.0,
            "available_drivers_count": 2,
            "search_radius_km": 10.0,
        }

        with patch(
            "app.api.pricing.estimate_ride_preview",
            new=AsyncMock(return_value=estimate),
        ):
            payload = await pricing.estimate_price_endpoint(
                pickup_lat=13.5116,
                pickup_lng=2.1254,
                dropoff_lat=13.5340,
                dropoff_lng=2.1090,
                session=object(),
            )

        self.assertIsInstance(payload, PriceEstimateRead)
        self.assertEqual(payload.min_price, 2200.0)
        self.assertEqual(payload.max_price, 2800.0)
        self.assertEqual(payload.available_drivers_count, 2)

    async def test_rides_estimate_endpoint_uses_the_same_service_contract(
        self,
    ) -> None:
        estimate = {
            "estimated_price": 2200.0,
            "distance_km": 5.2,
            "duration_min": 14,
            "pickup_zone": "Grand Marche",
            "dropoff_zone": "Aeroport",
            "base_price": 1500.0,
            "price_per_km": 300.0,
            "applied_mode": "zone",
            "applied_zone_rule": {"id": 1},
            "applied_time_rule": None,
            "platform_commission_preview": 330.0,
            "min_price": 1900.0,
            "max_price": 2500.0,
            "available_drivers_count": 0,
            "search_radius_km": 10.0,
        }

        with patch(
            "app.api.ride_request.estimate_ride_preview",
            new=AsyncMock(return_value=estimate),
        ):
            payload = await ride_request.estimate_ride_request_endpoint(
                pickup_lat=13.5000,
                pickup_lng=2.1000,
                dropoff_lat=13.4800,
                dropoff_lng=2.1700,
                session=object(),
            )

        self.assertIsInstance(payload, PriceEstimateRead)
        self.assertEqual(payload.available_drivers_count, 0)
        self.assertEqual(payload.duration_min, 14)


class RideMessageSchemasTest(unittest.TestCase):
    def test_ride_message_create_trims_content_and_rejects_oversized_payloads(
        self,
    ) -> None:
        schema_module = importlib.import_module("app.schemas.ride_request")
        ride_message_create = getattr(schema_module, "RideMessageCreate", None)

        self.assertIsNotNone(ride_message_create)
        if ride_message_create is None:
            return

        payload = ride_message_create(content="  Je suis devant la porte bleue  ")
        self.assertEqual(payload.content, "Je suis devant la porte bleue")

        with self.assertRaises(ValidationError):
            ride_message_create(content="x" * 501)


class RideMessageServiceRulesTest(unittest.IsolatedAsyncioTestCase):
    async def test_create_ride_message_rejects_completed_rides(self) -> None:
        service_spec = importlib.util.find_spec("app.services.ride_message_service")
        self.assertIsNotNone(service_spec)
        if service_spec is None:
            return

        schema_module = importlib.import_module("app.schemas.ride_request")
        ride_message_create = getattr(schema_module, "RideMessageCreate", None)
        self.assertIsNotNone(ride_message_create)
        if ride_message_create is None:
            return

        ride_message_service = importlib.import_module(
            "app.services.ride_message_service"
        )
        create_ride_message = getattr(ride_message_service, "create_ride_message", None)

        self.assertIsNotNone(create_ride_message)
        if create_ride_message is None:
            return

        ride = RideRequest(
            id=31,
            client_id=45,
            driver_id=12,
            pickup_location="Rond-point Kennedy",
            dropoff_location="Plateau",
            estimated_price=Decimal("2500.00"),
            status=RideRequestStatus.COMPLETED,
        )
        session = SimpleNamespace(
            get=AsyncMock(return_value=ride),
            add=Mock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )
        current_user = User(
            id=45,
            phone_number="+22790000045",
            role=UserRole.CLIENT,
        )

        with self.assertRaises(ApiError) as context:
            await create_ride_message(
                session=session,
                ride_request_id=ride.id,
                current_user=current_user,
                message_in=ride_message_create(content="Je descends"),
            )

        self.assertEqual(context.exception.status_code, 409)


class RideMessageEndpointsTest(unittest.IsolatedAsyncioTestCase):
    async def test_create_ride_message_endpoint_returns_service_payload(self) -> None:
        schema_module = importlib.import_module("app.schemas.ride_request")
        ride_message_create = getattr(schema_module, "RideMessageCreate", None)
        ride_message_read = getattr(schema_module, "RideMessageRead", None)

        self.assertIsNotNone(ride_message_create)
        self.assertIsNotNone(ride_message_read)
        endpoint = getattr(ride_request, "create_ride_message_endpoint", None)
        self.assertIsNotNone(endpoint)
        if ride_message_create is None or ride_message_read is None or endpoint is None:
            return

        current_user = User(
            id=45,
            phone_number="+22790000045",
            role=UserRole.CLIENT,
        )
        message = ride_message_read(
            id=1,
            ride_id=8,
            sender_id=45,
            sender_role=UserRole.CLIENT,
            content="Je suis devant la pharmacie",
            is_read=False,
            created_at="2026-05-01T08:30:00Z",
        )

        with patch(
            "app.api.ride_request.create_ride_message",
            new=AsyncMock(return_value=message),
            create=True,
        ) as mocked_service:
            payload = await endpoint(
                ride_request_id=8,
                message_in=ride_message_create(content="Je suis devant la pharmacie"),
                current_user=current_user,
                session=object(),
            )

        self.assertEqual(payload, message)
        mocked_service.assert_awaited_once()

    async def test_list_ride_messages_endpoint_returns_unread_count(self) -> None:
        schema_module = importlib.import_module("app.schemas.ride_request")
        ride_message_page_read = getattr(schema_module, "RideMessagePageRead", None)

        self.assertIsNotNone(ride_message_page_read)
        endpoint = getattr(ride_request, "list_ride_messages_endpoint", None)
        self.assertIsNotNone(endpoint)
        if ride_message_page_read is None or endpoint is None:
            return

        current_user = User(
            id=12,
            phone_number="+22790000012",
            role=UserRole.DRIVER,
        )
        page = ride_message_page_read(
            items=[],
            unread_count=2,
            limit=20,
            offset=0,
        )

        with patch(
            "app.api.ride_request.list_ride_messages",
            new=AsyncMock(return_value=page),
            create=True,
        ) as mocked_service:
            payload = await endpoint(
                ride_request_id=8,
                current_user=current_user,
                session=object(),
                limit=20,
                offset=0,
            )

        self.assertEqual(payload.unread_count, 2)
        mocked_service.assert_awaited_once()


class RideMessageRealtimeContractTest(unittest.TestCase):
    def test_ride_message_notification_uses_expected_payload_shape(self) -> None:
        realtime_module = importlib.import_module("app.realtime.schemas")
        notification_class = getattr(realtime_module, "RideMessageNotification", None)

        self.assertIsNotNone(notification_class)
        if notification_class is None:
            return

        payload = notification_class(
            ride_request_id=8,
            message={
                "id": 1,
                "ride_id": 8,
                "sender_id": 45,
                "sender_role": "client",
                "content": "Je suis devant la porte bleue",
                "is_read": False,
                "created_at": "2026-05-01T08:30:00Z",
            },
        )

        self.assertEqual(payload.type, "ride_message")
        self.assertEqual(payload.ride_request_id, 8)


class SavedAddressSchemaValidationTest(unittest.TestCase):
    def test_saved_address_create_rejects_missing_coordinates(self) -> None:
        with self.assertRaises(ValidationError):
            SavedAddressCreate(
                label="Maison",
                lon=2.1098,
                address_display="Rond-point Kennedy",
            )

        with self.assertRaises(ValidationError):
            SavedAddressCreate(
                label="Maison",
                lat=13.5137,
                address_display="Rond-point Kennedy",
            )


class SavedAddressServiceRulesTest(unittest.IsolatedAsyncioTestCase):
    async def test_create_saved_address_rejects_eleven_favorite(self) -> None:
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarResult(10)),
            add=Mock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with self.assertRaises(ApiError) as context:
            await user_service.create_saved_address(
                session=session,
                user_id=45,
                address_in=SavedAddressCreate(
                    label="Maison",
                    lat=13.5137,
                    lon=2.1098,
                    address_display="Rond-point Kennedy",
                ),
            )

        self.assertEqual(context.exception.status_code, 400)
        self.assertEqual(context.exception.code, "saved_address_limit_reached")
        session.add.assert_not_called()

    async def test_update_saved_address_rejects_other_user_address(self) -> None:
        session = SimpleNamespace(
            get=AsyncMock(
                return_value=SavedAddress(
                    id=9,
                    user_id=77,
                    label="Maison",
                    lat=13.5137,
                    lon=2.1098,
                    address_display="Rond-point Kennedy",
                )
            ),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        with self.assertRaises(ApiError) as context:
            await user_service.update_saved_address(
                session=session,
                user_id=45,
                saved_address_id=9,
                address_in=SavedAddressUpdate(
                    label="Bureau",
                    lat=13.521,
                    lon=2.101,
                    address_display="Plateau",
                ),
            )

        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(context.exception.code, "saved_address_forbidden")
        session.commit.assert_not_awaited()

    async def test_delete_saved_address_rejects_other_user_address(self) -> None:
        session = SimpleNamespace(
            get=AsyncMock(
                return_value=SavedAddress(
                    id=11,
                    user_id=88,
                    label="Maison",
                    lat=13.51,
                    lon=2.11,
                    address_display="Yantala",
                )
            ),
            delete=AsyncMock(),
            commit=AsyncMock(),
        )

        with self.assertRaises(ApiError) as context:
            await user_service.delete_saved_address(
                session=session,
                user_id=45,
                saved_address_id=11,
            )

        self.assertEqual(context.exception.status_code, 403)
        self.assertEqual(context.exception.code, "saved_address_forbidden")
        session.delete.assert_not_awaited()
        session.commit.assert_not_awaited()


class RideShareSchemaValidationTest(unittest.TestCase):
    def test_ride_share_link_read_validates_uuid_token(self) -> None:
        payload = ride_request.RideShareLinkRead(
            token="f4f53f92-905f-44db-b40f-0e88785b3676",
            tracking_url="https://example.com/track/f4f53f92-905f-44db-b40f-0e88785b3676/map",
        )

        UUID(payload.token)
        self.assertTrue(payload.tracking_url.startswith("https://"))

        with self.assertRaises(ValidationError):
            ride_request.RideShareLinkRead(
                token="invalid-token",
                tracking_url="https://example.com/track/invalid/map",
            )


class RideShareServiceRulesTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        ride_request_service.reset_track_rate_limit_cache()

    async def test_non_passenger_cannot_generate_share_link(self) -> None:
        ride = RideRequest(
            id=70,
            client_id=101,
            driver_id=202,
            pickup_location="Hopital National",
            dropoff_location="Plateau",
            estimated_price=Decimal("2300.00"),
            status=RideRequestStatus.ACCEPTED,
        )
        session = SimpleNamespace(get=AsyncMock(return_value=ride))
        other_user = User(
            id=999,
            phone_number="+22790000999",
            role=UserRole.CLIENT,
        )

        with self.assertRaises(ApiError) as context:
            await ride_request_service.create_ride_share_link(
                session=session,
                ride_id=ride.id,
                current_user=other_user,
            )

        self.assertEqual(context.exception.status_code, 403)

    async def test_completed_ride_token_is_invalidated_for_public_tracking(
        self,
    ) -> None:
        completed_ride = RideRequest(
            id=71,
            client_id=101,
            driver_id=202,
            pickup_location="Hopital National",
            dropoff_location="Plateau",
            estimated_price=Decimal("2500.00"),
            status=RideRequestStatus.COMPLETED,
            share_token="f4f53f92-905f-44db-b40f-0e88785b3676",
        )
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarOneOrNoneResult(completed_ride)),
        )

        with self.assertRaises(ApiError) as context:
            await ride_request_service.get_public_ride_tracking(
                session=session,
                token=completed_ride.share_token,
            )

        self.assertEqual(context.exception.status_code, 404)

    async def test_unknown_token_returns_not_found(self) -> None:
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarOneOrNoneResult(None)),
        )

        with self.assertRaises(ApiError) as context:
            await ride_request_service.get_public_ride_tracking(
                session=session,
                token="f4f53f92-905f-44db-b40f-0e88785b3676",
            )

        self.assertEqual(context.exception.status_code, 404)

    async def test_rate_limit_blocks_second_request_within_five_seconds(self) -> None:
        active_ride = RideRequest(
            id=72,
            client_id=101,
            driver_id=202,
            pickup_location="Hopital National",
            dropoff_location="Plateau",
            estimated_price=Decimal("2600.00"),
            status=RideRequestStatus.STARTED,
            share_token="f4f53f92-905f-44db-b40f-0e88785b3676",
        )
        driver = User(
            id=202,
            phone_number="+22790000202",
            role=UserRole.DRIVER,
            name="Issa Mahamadou",
            vehicle_model="Toyota Corolla",
            plate_number="NE-1234",
        )
        session = SimpleNamespace(
            execute=AsyncMock(return_value=_ScalarOneOrNoneResult(active_ride)),
            get=AsyncMock(return_value=driver),
        )

        with patch(
            "app.services.ride_request_service.driver_locator.get_connected_drivers",
            new=AsyncMock(
                return_value=[
                    SimpleNamespace(
                        driver_id=202,
                        latitude=13.5116,
                        longitude=2.1254,
                    )
                ]
            ),
        ):
            first_payload = await ride_request_service.get_public_ride_tracking(
                session=session,
                token=active_ride.share_token,
            )
            with self.assertRaises(ApiError) as context:
                await ride_request_service.get_public_ride_tracking(
                    session=session,
                    token=active_ride.share_token,
                )

        self.assertEqual(first_payload["ride_id"], 72)
        self.assertEqual(context.exception.status_code, 429)


class DriverDashboardStatsServiceTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        wallet_service.reset_driver_dashboard_stats_cache()

    async def test_driver_revenue_windows_are_mapped_correctly(self) -> None:
        session = AsyncMock()

        with patch(
            "app.services.wallet_service._sum_driver_completed_revenue",
            new=AsyncMock(side_effect=[1250.0, 5400.0, 9800.0, 24500.0]),
        ):
            revenue = await wallet_service._build_driver_revenue_stats(
                session,
                driver_id=15,
            )

        self.assertEqual(revenue.today, 1250.0)
        self.assertEqual(revenue.week, 5400.0)
        self.assertEqual(revenue.month, 9800.0)
        self.assertEqual(revenue.total, 24500.0)

    async def test_peak_hours_without_completed_rides_returns_full_zero_grid(
        self,
    ) -> None:
        peak_hours = wallet_service._build_driver_peak_hours([])

        self.assertEqual(len(peak_hours), 24)
        self.assertEqual(peak_hours[0].hour, 0)
        self.assertEqual(peak_hours[-1].hour, 23)
        self.assertTrue(
            all(
                item.completed_rides == 0 and item.average_revenue == 0.0
                for item in peak_hours
            )
        )

    async def test_driver_stats_cache_is_rebuilt_after_invalidation(self) -> None:
        session = AsyncMock()
        first_payload = DriverDashboardStatsRead(
            driver_id=22,
            revenue=DriverRevenueStatsRead(
                today=1100.0,
                week=5100.0,
                month=12300.0,
                total=55000.0,
            ),
            rides=DriverRideStatusStatsRead(completed=9, cancelled=1, refused=2),
            peak_hours=[
                DriverPeakHourStatsRead(
                    hour=hour,
                    completed_rides=0,
                    average_revenue=0.0,
                )
                for hour in range(24)
            ],
            profitable_zones=[
                DriverZoneProfitabilityRead(
                    zone_name="Plateau",
                    rides_count=4,
                    average_revenue=2750.0,
                )
            ],
            reputation=DriverReputationStatsRead(
                last_30_days=4.7,
                global_average=4.5,
            ),
        )
        second_payload = first_payload.model_copy(
            update={
                "revenue": DriverRevenueStatsRead(
                    today=2100.0,
                    week=6100.0,
                    month=13300.0,
                    total=56000.0,
                )
            }
        )

        with patch(
            "app.services.wallet_service._build_driver_dashboard_stats",
            new=AsyncMock(side_effect=[first_payload, second_payload]),
        ) as mocked_builder:
            cached = await wallet_service.get_driver_dashboard_stats(session, 22)
            cached_again = await wallet_service.get_driver_dashboard_stats(session, 22)
            wallet_service.invalidate_driver_dashboard_stats_cache(22)
            rebuilt = await wallet_service.get_driver_dashboard_stats(session, 22)

        self.assertEqual(mocked_builder.await_count, 2)
        self.assertEqual(cached.revenue.today, 1100.0)
        self.assertEqual(cached_again.revenue.today, 1100.0)
        self.assertEqual(rebuilt.revenue.today, 2100.0)


class _ScalarResult:
    def __init__(self, value: int) -> None:
        self._value = value

    def scalar_one(self) -> int:
        return self._value


class _ScalarOneOrNoneResult:
    def __init__(self, value: object) -> None:
        self._value = value

    def scalar_one_or_none(self) -> object:
        return self._value


if __name__ == "__main__":
    unittest.main()
