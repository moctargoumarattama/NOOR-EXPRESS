import base64
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import admin_simulation_service as simulations
from app.api import admin_simulations


class AdminSimulationSafetyTest(unittest.TestCase):
    def test_guard_blocks_production_even_when_flag_enabled(self) -> None:
        self.assertFalse(
            simulations.dev_simulations_allowed(
                env="production",
                enable_dev_simulations=True,
            )
        )

    def test_guard_is_disabled_by_default_outside_production(self) -> None:
        self.assertFalse(
            simulations.dev_simulations_allowed(
                env="development",
                enable_dev_simulations=False,
            )
        )

    def test_guard_allows_dev_when_flag_is_enabled(self) -> None:
        self.assertTrue(
            simulations.dev_simulations_allowed(
                env="development",
                enable_dev_simulations=True,
            )
        )


class AdminSimulationDataTest(unittest.TestCase):
    def test_rabat_agdal_points_are_valid_and_around_four_km(self) -> None:
        route = simulations.build_rabat_agdal_route()

        self.assertGreater(route.pickup.latitude, 33.8)
        self.assertLess(route.pickup.latitude, 34.2)
        self.assertGreater(route.pickup.longitude, -7.1)
        self.assertLess(route.pickup.longitude, -6.6)

        self.assertGreater(route.dropoff.latitude, 33.8)
        self.assertLess(route.dropoff.latitude, 34.2)
        self.assertGreater(route.dropoff.longitude, -7.1)
        self.assertLess(route.dropoff.longitude, -6.6)

        self.assertGreaterEqual(route.distance_km, 3.0)
        self.assertLessEqual(route.distance_km, 5.5)

    def test_generated_prices_are_bounded_and_never_absurd(self) -> None:
        prices = simulations.build_simulation_prices()

        self.assertGreater(prices.client_price, 0)
        self.assertLessEqual(prices.client_price, simulations.MAX_SIMULATION_PRICE_FCFA)
        self.assertGreaterEqual(len(prices.offer_prices), 2)
        self.assertLessEqual(len(prices.offer_prices), 3)
        for price in prices.offer_prices:
            self.assertGreater(price, 0)
            self.assertLessEqual(price, simulations.MAX_SIMULATION_PRICE_FCFA)
            self.assertNotEqual(price, 800000)

    def test_simulation_driver_profile_payload_uses_valid_base64_documents(self) -> None:
        profile = simulations._build_simulation_driver_profile("Amine El Idrissi")

        self.assertEqual(profile.first_name, "Amine")
        self.assertEqual(profile.last_name, "El Idrissi")
        self.assertEqual(
            base64.b64decode(profile.vehicle_photo).decode("utf-8"),
            "simulation-vehicle-photo",
        )
        self.assertEqual(
            base64.b64decode(profile.driver_license_file).decode("utf-8"),
            "simulation-license",
        )


class AdminSimulationStateTest(unittest.IsolatedAsyncioTestCase):
    async def test_stop_cancels_registered_tasks_and_keeps_logs(self) -> None:
        state = simulations.SimulationState()
        task = simulations.create_completed_task()
        state.register_task(task)
        state.add_log("ride created")

        await state.stop()

        snapshot = state.snapshot()
        self.assertFalse(snapshot["active"])
        self.assertIn("ride created", snapshot["logs"])
        self.assertIn("Simulation stoppee", snapshot["logs"][-1])


class AdminSimulationFlowTest(unittest.IsolatedAsyncioTestCase):
    async def test_client_acceptance_runs_full_tracking_flow(self) -> None:
        state = simulations.SimulationState()
        state.begin("client")
        ride = SimpleNamespace(
            id=44,
            driver_id=12,
            status=simulations.RideRequestStatus.ACCEPTED,
            pickup_location="Agdal",
            dropoff_location="Tour Hassan",
            pickup_latitude=34.0,
            pickup_longitude=-6.84,
            dropoff_latitude=34.02,
            dropoff_longitude=-6.82,
        )

        class SessionContext:
            async def __aenter__(self):
                return SimpleNamespace(get=AsyncMock(return_value=ride))

            async def __aexit__(self, exc_type, exc, traceback):
                return False

        with patch.object(simulations, "AsyncSessionLocal", return_value=SessionContext()):
            with patch.object(
                simulations,
                "_run_driver_tracking_flow",
                new=AsyncMock(),
            ) as tracking_flow_mock:
                await simulations._watch_acceptance_and_simulate_pickup(
                    ride.id,
                    state,
                )

        tracking_flow_mock.assert_awaited_once()
        args = tracking_flow_mock.await_args.args
        self.assertEqual(args[0], ride.id)
        self.assertEqual(args[1], ride.driver_id)

    async def test_driver_simulation_waits_for_real_driver_offer(self) -> None:
        state = simulations.SimulationState()
        session = object()

        with patch.object(simulations, "ensure_dev_simulations_enabled"):
            with patch.object(
                simulations,
                "_assert_no_unapproved_real_nearby_drivers",
                new=AsyncMock(),
            ):
                with patch.object(
                    simulations,
                    "_create_fake_client",
                    new=AsyncMock(return_value=SimpleNamespace(id=901)),
                ):
                    with patch.object(
                        simulations,
                        "create_ride",
                        new=AsyncMock(return_value=SimpleNamespace(id=77)),
                    ):
                        with patch.object(
                            simulations,
                            "_watch_driver_offer_and_run_tracking",
                            new=AsyncMock(),
                        ):
                            with patch.object(
                                simulations,
                                "create_offer",
                                new=AsyncMock(),
                            ) as create_offer_mock:
                                with patch.object(
                                    simulations,
                                    "accept_offer",
                                    new=AsyncMock(),
                                ) as accept_offer_mock:
                                    snapshot = await simulations.start_driver_simulation(
                                        session,
                                        state=state,
                                    )

        create_offer_mock.assert_not_awaited()
        accept_offer_mock.assert_not_awaited()
        self.assertEqual(snapshot["mode"], "driver")
        self.assertEqual(snapshot["ride_id"], 77)
        self.assertEqual(snapshot["driver_ids"], [])
        self.assertEqual(snapshot["offer_ids"], [])
        self.assertTrue(any("chauffeur reel" in log for log in snapshot["logs"]))

    async def test_client_simulation_uses_latest_real_pending_ride_when_present(self) -> None:
        state = simulations.SimulationState()
        real_ride = SimpleNamespace(
            id=88,
            pickup_location="Agdal",
            dropoff_location="Tour Hassan",
            pickup_latitude=34.0,
            pickup_longitude=-6.84,
            dropoff_latitude=34.02,
            dropoff_longitude=-6.82,
        )
        fake_driver = SimpleNamespace(id=701)
        fake_offer = SimpleNamespace(offer_id=55)

        with patch.object(simulations, "ensure_dev_simulations_enabled"):
            with patch.object(
                simulations,
                "_get_latest_real_negotiable_ride",
                new=AsyncMock(return_value=real_ride),
            ):
                with patch.object(
                    simulations,
                    "_create_fake_client",
                    new=AsyncMock(),
                ) as create_fake_client_mock:
                    with patch.object(
                        simulations,
                        "_create_fake_drivers_around_pickup",
                        new=AsyncMock(return_value=[fake_driver]),
                    ):
                        with patch.object(
                            simulations,
                            "create_offer",
                            new=AsyncMock(return_value=fake_offer),
                        ):
                            with patch.object(
                                simulations,
                                "_watch_acceptance_and_simulate_pickup",
                                new=AsyncMock(),
                            ):
                                snapshot = await simulations.start_client_simulation(
                                    object(),
                                    state=state,
                                )

        create_fake_client_mock.assert_not_awaited()
        self.assertEqual(snapshot["mode"], "client")
        self.assertEqual(snapshot["ride_id"], 88)
        self.assertEqual(snapshot["driver_ids"], [701])
        self.assertEqual(snapshot["offer_ids"], [55])


class AdminSimulationRoutesTest(unittest.IsolatedAsyncioTestCase):
    def test_admin_simulation_routes_are_registered(self) -> None:
        paths = {route.path for route in admin_simulations.router.routes}

        self.assertIn("/admin/simulations/client", paths)
        self.assertIn("/admin/simulations/driver", paths)
        self.assertIn("/admin/simulations/stop", paths)
        self.assertIn("/admin/simulations/status", paths)

    async def test_client_route_maps_disabled_simulation_to_403(self) -> None:
        with patch(
            "app.api.admin_simulations.start_client_simulation",
            new=AsyncMock(side_effect=simulations.SimulationDisabledError("disabled")),
        ):
            with self.assertRaises(admin_simulations.HTTPException) as context:
                await admin_simulations.admin_client_simulation_endpoint(
                    payload=None,
                    _admin={},
                    session=object(),
                )

        self.assertEqual(context.exception.status_code, 403)

    async def test_driver_route_allows_real_dev_drivers_by_default(self) -> None:
        with patch(
            "app.api.admin_simulations.start_driver_simulation",
            new=AsyncMock(return_value={"active": True}),
        ) as start_driver_simulation_mock:
            await admin_simulations.admin_driver_simulation_endpoint(
                payload=None,
                _admin={},
                session=object(),
            )

        start_driver_simulation_mock.assert_awaited_once()
        self.assertTrue(
            start_driver_simulation_mock.await_args.kwargs["allow_real_users"]
        )

    async def test_driver_route_allows_real_dev_drivers_with_empty_payload(self) -> None:
        with patch(
            "app.api.admin_simulations.start_driver_simulation",
            new=AsyncMock(return_value={"active": True}),
        ) as start_driver_simulation_mock:
            await admin_simulations.admin_driver_simulation_endpoint(
                payload=admin_simulations.AdminSimulationRequest(),
                _admin={},
                session=object(),
            )

        start_driver_simulation_mock.assert_awaited_once()
        self.assertTrue(
            start_driver_simulation_mock.await_args.kwargs["allow_real_users"]
        )

    async def test_stop_route_maps_disabled_simulation_to_403(self) -> None:
        with patch(
            "app.api.admin_simulations.stop_simulation",
            new=AsyncMock(side_effect=simulations.SimulationDisabledError("disabled")),
        ):
            with self.assertRaises(admin_simulations.HTTPException) as context:
                await admin_simulations.admin_stop_simulation_endpoint(_admin={})

        self.assertEqual(context.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
