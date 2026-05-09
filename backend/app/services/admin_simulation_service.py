from __future__ import annotations

import asyncio
import base64
import time
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.messages import Messages
from app.db.database import AsyncSessionLocal
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import DriverStatus, User, UserRole
from app.realtime.gateway import realtime_gateway
from app.realtime.schemas import DriverLocationUpdate, DriverPositionNotification
from app.schemas.driver_profile import DriverProfileCreate
from app.schemas.ride_request import RideRequestCreate
from app.schemas.user import DriverProfileUpdate, UserCreate
from app.services.driver_profile_service import create_or_update_profile, verify_driver
from app.services.ride_lifecycle_service import (
    accept_offer,
    complete_ride,
    create_ride,
    mark_arrived,
    start_ride,
)
from app.services.ride_offer_service import create_offer
from app.services.user_service import (
    UserPhoneAlreadyExistsError,
    create_user,
    update_driver_profile,
    update_driver_status,
)


MAX_SIMULATION_PRICE_FCFA = Decimal("6000.00")
MIN_SIMULATION_PRICE_FCFA = Decimal("2500.00")
SIMULATION_USER_PHONE_PREFIX = "+212990"
SIMULATION_GPS_INTERVAL_SECONDS = 2.0
SIMULATION_PICKUP_STEPS = 6
SIMULATION_DROPOFF_STEPS = 8
SIMULATION_WATCH_SECONDS = 180
SIMULATION_DOCUMENT_VALIDITY_DAYS = 365
SIMULATION_DRIVER_ADDRESS = "Rabat Agdal"
SIMULATION_ID_CARD_SEED = "simulation-id-card"
SIMULATION_SELFIE_SEED = "simulation-selfie"
SIMULATION_VEHICLE_PHOTO_SEED = "simulation-vehicle-photo"
SIMULATION_LICENSE_SEED = "simulation-license"
SIMULATION_REGISTRATION_SEED = "simulation-registration"
SIMULATION_INSURANCE_SEED = "simulation-insurance"
SIMULATION_TECHNICAL_INSPECTION_SEED = "simulation-technical-inspection"


class SimulationDisabledError(Exception):
    pass


class SimulationUnsafeTargetError(Exception):
    pass


@dataclass(frozen=True)
class SimulationPoint:
    label: str
    latitude: float
    longitude: float


@dataclass(frozen=True)
class SimulationRoute:
    pickup: SimulationPoint
    dropoff: SimulationPoint
    distance_km: float


@dataclass(frozen=True)
class SimulationPrices:
    client_price: Decimal
    offer_prices: tuple[Decimal, ...]


class SimulationState:
    def __init__(self) -> None:
        self.active = False
        self.mode: str | None = None
        self.started_at: datetime | None = None
        self.ride_id: int | None = None
        self.driver_ids: list[int] = []
        self.offer_ids: list[int] = []
        self.logs: list[str] = []
        self._tasks: set[asyncio.Task] = set()

    def begin(self, mode: str) -> None:
        self.active = True
        self.mode = mode
        self.started_at = datetime.utcnow()
        self.ride_id = None
        self.driver_ids = []
        self.offer_ids = []
        self.logs = []
        self.add_log(f"Simulation {mode} demarree")

    def add_log(self, message: str) -> None:
        self.logs.append(message)
        if len(self.logs) > 80:
            self.logs = self.logs[-80:]

    def register_task(self, task: asyncio.Task) -> None:
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    def snapshot(self) -> dict[str, Any]:
        return {
            "active": self.active,
            "mode": self.mode,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "ride_id": self.ride_id,
            "driver_ids": list(self.driver_ids),
            "offer_ids": list(self.offer_ids),
            "logs": list(self.logs),
        }

    async def stop(self) -> None:
        tasks = list(self._tasks)
        for task in tasks:
            if not task.done():
                task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._tasks.clear()
        self.active = False
        self.add_log("Simulation stoppee")


simulation_state = SimulationState()


async def _completed_coroutine() -> None:
    return None


def create_completed_task() -> asyncio.Task:
    return asyncio.create_task(_completed_coroutine())


def dev_simulations_allowed(
    *,
    env: str | None = None,
    enable_dev_simulations: bool | None = None,
) -> bool:
    selected_env = (env if env is not None else settings.ENV).strip().lower()
    enabled = (
        enable_dev_simulations
        if enable_dev_simulations is not None
        else settings.ENABLE_DEV_SIMULATIONS
    )
    if selected_env in {"production", "prod"}:
        return False
    return bool(enabled)


def ensure_dev_simulations_enabled() -> None:
    if dev_simulations_allowed():
        return
    raise SimulationDisabledError(
        Messages.DEV_SIMULATIONS_DISABLED
    )


def build_rabat_agdal_route() -> SimulationRoute:
    pickup = SimulationPoint(
        label="Agdal, Rabat",
        latitude=34.0007,
        longitude=-6.8498,
    )
    dropoff = SimulationPoint(
        label="Tour Hassan, Rabat",
        latitude=34.0243,
        longitude=-6.8226,
    )
    return SimulationRoute(
        pickup=pickup,
        dropoff=dropoff,
        distance_km=round(
            _calculate_distance_km(
                pickup.latitude,
                pickup.longitude,
                dropoff.latitude,
                dropoff.longitude,
            ),
            2,
        ),
    )


def build_simulation_prices() -> SimulationPrices:
    client_price = Decimal("3500.00")
    offer_prices = (
        Decimal("3300.00"),
        Decimal("3700.00"),
        Decimal("4100.00"),
    )
    _assert_valid_price(client_price)
    for offer_price in offer_prices:
        _assert_valid_price(offer_price)
    return SimulationPrices(client_price=client_price, offer_prices=offer_prices)


async def start_client_simulation(
    session: AsyncSession,
    *,
    ride_id: int | None = None,
    allow_real_users: bool = False,
    state: SimulationState = simulation_state,
) -> dict[str, Any]:
    ensure_dev_simulations_enabled()
    if state.active:
        await state.stop()
    state.begin("client")

    route = build_rabat_agdal_route()
    prices = build_simulation_prices()
    if ride_id is None:
        ride = await _get_latest_real_negotiable_ride(session)
        if ride is None:
            await _assert_no_unapproved_real_nearby_drivers(
                session,
                route.pickup,
                allow_real_users=allow_real_users,
            )
            client = await _create_fake_client(session)
            ride = await create_ride(
                session,
                RideRequestCreate(
                    pickup_location=route.pickup.label,
                    dropoff_location=route.dropoff.label,
                    client_latitude=route.pickup.latitude,
                    client_longitude=route.pickup.longitude,
                    dropoff_latitude=route.dropoff.latitude,
                    dropoff_longitude=route.dropoff.longitude,
                    estimated_price=float(prices.client_price),
                ),
                client,
            )
            state.add_log("Aucune vraie course client trouvee; client fictif cree")
        else:
            route = _route_from_ride_or_default(ride, route)
            state.add_log(f"Course client reelle detectee: {ride.id}")
    else:
        ride = await _get_allowed_ride(
            session,
            ride_id,
            allow_real_users=allow_real_users,
        )
        route = _route_from_ride_or_default(ride, route)

    state.ride_id = ride.id
    state.add_log(f"Ride creee/utilisee: {ride.id}")

    drivers = await _create_fake_drivers_around_pickup(session, route.pickup, count=3)
    state.driver_ids = [driver.id for driver in drivers]
    state.add_log(f"Chauffeurs crees: {', '.join(str(driver.id) for driver in drivers)}")

    offer_ids: list[int] = []
    for driver, price in zip(drivers, prices.offer_prices, strict=False):
        offer = await create_offer(
            session,
            ride_id=ride.id,
            driver_id=driver.id,
            proposed_price=price,
        )
        offer_ids.append(offer.offer_id)
        state.add_log(f"Offre envoyee: driver {driver.id}, {price:.0f} FCFA")

    state.offer_ids = offer_ids
    state.register_task(
        asyncio.create_task(_watch_acceptance_and_simulate_pickup(ride.id, state))
    )
    state.add_log("En attente d'acceptation client")
    return state.snapshot()


async def start_driver_simulation(
    session: AsyncSession,
    *,
    allow_real_users: bool = False,
    state: SimulationState = simulation_state,
) -> dict[str, Any]:
    ensure_dev_simulations_enabled()
    if state.active:
        await state.stop()
    state.begin("driver")

    route = build_rabat_agdal_route()
    prices = build_simulation_prices()
    await _assert_no_unapproved_real_nearby_drivers(
        session,
        route.pickup,
        allow_real_users=allow_real_users,
    )

    client = await _create_fake_client(session)
    ride = await create_ride(
        session,
        RideRequestCreate(
            pickup_location=route.pickup.label,
            dropoff_location=route.dropoff.label,
            client_latitude=route.pickup.latitude,
            client_longitude=route.pickup.longitude,
            dropoff_latitude=route.dropoff.latitude,
            dropoff_longitude=route.dropoff.longitude,
            estimated_price=float(prices.client_price),
        ),
        client,
    )
    state.ride_id = ride.id
    state.add_log(f"Ride creee: {ride.id}")
    state.add_log("Demande visible: connecte-toi comme chauffeur reel et propose un prix")
    state.register_task(
        asyncio.create_task(_watch_driver_offer_and_run_tracking(ride.id, route, state))
    )
    return state.snapshot()


async def stop_simulation(
    *,
    state: SimulationState = simulation_state,
) -> dict[str, Any]:
    ensure_dev_simulations_enabled()
    driver_ids = list(state.driver_ids)
    await state.stop()
    await _disconnect_simulation_drivers(driver_ids)
    return state.snapshot()


def get_simulation_status(
    *,
    state: SimulationState = simulation_state,
) -> dict[str, Any]:
    ensure_dev_simulations_enabled()
    return state.snapshot()


async def _create_fake_client(session: AsyncSession) -> User:
    return await _create_unique_user(
        session,
        role=UserRole.CLIENT,
        name="Client Noor Test",
        index=90,
    )


async def _create_fake_drivers_around_pickup(
    session: AsyncSession,
    pickup: SimulationPoint,
    *,
    count: int,
) -> list[User]:
    seed_drivers = [
        ("Amine El Idrissi", "Dacia", "Logan", "Blanc", "DEV-2101", 1),
        ("Mehdi Alaoui", "Renault", "Clio", "Gris", "DEV-2102", 2),
        ("Samir Bennis", "Hyundai", "i10", "Noir", "DEV-2103", 3),
    ]
    points = _driver_offer_points(pickup)
    drivers: list[User] = []
    for index, (name, brand, model, color, plate, phone_index) in enumerate(
        seed_drivers[:count]
    ):
        drivers.append(
            await _create_fake_driver(
                session,
                name=name,
                point=points[index],
                vehicle_brand=brand,
                vehicle_model=model,
                vehicle_color=color,
                plate_number=plate,
                index=phone_index,
            )
        )
    return drivers


async def _create_fake_driver(
    session: AsyncSession,
    *,
    name: str,
    point: SimulationPoint,
    vehicle_brand: str,
    vehicle_model: str,
    vehicle_color: str,
    plate_number: str,
    index: int,
) -> User:
    driver = await _create_unique_user(
        session,
        role=UserRole.DRIVER,
        name=name,
        index=index,
    )
    await update_driver_profile(
        session,
        driver.id,
        DriverProfileUpdate(
            name=name,
            vehicle_brand=vehicle_brand,
            vehicle_model=vehicle_model,
            vehicle_color=vehicle_color,
            plate_number=plate_number,
        ),
    )
    await create_or_update_profile(
        session,
        driver.id,
        _build_simulation_driver_profile(name),
    )
    await verify_driver(session, driver.id)
    driver = await session.get(User, driver.id)
    if driver is None:
        raise SimulationUnsafeTargetError(Messages.SIMULATION_DRIVER_RELOAD_FAILED)
    driver.is_available = True
    driver.fcm_token = None
    driver.driver_status = DriverStatus.ONLINE
    await session.commit()
    await session.refresh(driver)
    await _push_driver_position(driver.id, point.latitude, point.longitude)
    return driver


async def _create_unique_user(
    session: AsyncSession,
    *,
    role: UserRole,
    name: str,
    index: int,
) -> User:
    for attempt in range(20):
        phone_number = _fake_phone(index=index + attempt)
        try:
            user = await create_user(
                session,
                UserCreate(
                    phone_number=phone_number,
                    role=role,
                    name=name,
                ),
            )
            user.fcm_token = None
            await session.commit()
            await session.refresh(user)
            return user
        except UserPhoneAlreadyExistsError:
            continue
    raise SimulationUnsafeTargetError(Messages.SIMULATION_USER_CREATE_FAILED)


async def _get_allowed_ride(
    session: AsyncSession,
    ride_id: int,
    *,
    allow_real_users: bool,
) -> RideRequest:
    ride = await session.get(RideRequest, ride_id)
    if ride is None:
        raise SimulationUnsafeTargetError(Messages.SIMULATION_RIDE_NOT_FOUND)
    if ride.status not in {RideRequestStatus.PENDING, RideRequestStatus.OFFERED}:
        raise SimulationUnsafeTargetError(Messages.SIMULATION_RIDE_STATUS_INVALID)

    client = await session.get(User, ride.client_id)
    if client is None:
        raise SimulationUnsafeTargetError(Messages.SIMULATION_RIDE_CLIENT_NOT_FOUND)
    if not allow_real_users and not _is_simulation_user(client):
        raise SimulationUnsafeTargetError(
            Messages.FORBIDDEN
        )
    return ride


async def _get_latest_real_negotiable_ride(session: AsyncSession) -> RideRequest | None:
    result = await session.execute(
        select(RideRequest)
        .join(User, RideRequest.client_id == User.id)
        .where(
            RideRequest.status.in_(
                {RideRequestStatus.PENDING, RideRequestStatus.OFFERED}
            ),
            User.role == UserRole.CLIENT,
            ~User.phone_number.startswith(SIMULATION_USER_PHONE_PREFIX),
        )
        .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _assert_no_unapproved_real_nearby_drivers(
    session: AsyncSession,
    pickup: SimulationPoint,
    *,
    allow_real_users: bool,
) -> None:
    if allow_real_users:
        return

    nearby_drivers = await realtime_gateway.get_nearby_drivers(
        latitude=pickup.latitude,
        longitude=pickup.longitude,
        max_distance_km=10.0,
    )
    driver_ids = [driver.driver_id for driver in nearby_drivers]
    if not driver_ids:
        return

    result = await session.execute(select(User).where(User.id.in_(driver_ids)))
    real_drivers = [
        user
        for user in result.scalars().all()
        if user.role == UserRole.DRIVER and not _is_simulation_user(user)
    ]
    if real_drivers:
        raise SimulationUnsafeTargetError(
            Messages.SIMULATION_REAL_DRIVER_NEARBY
        )


async def _watch_acceptance_and_simulate_pickup(
    ride_id: int,
    state: SimulationState,
) -> None:
    try:
        deadline = time.monotonic() + SIMULATION_WATCH_SECONDS
        while time.monotonic() < deadline:
            async with AsyncSessionLocal() as session:
                ride = await session.get(RideRequest, ride_id)
                if ride and ride.driver_id and ride.status == RideRequestStatus.ACCEPTED:
                    route = _route_from_ride_or_default(ride, build_rabat_agdal_route())
                    state.add_log(f"Offre acceptee, tracking driver {ride.driver_id}")
                    await _run_driver_tracking_flow(ride.id, ride.driver_id, route, state)
                    return
            await asyncio.sleep(SIMULATION_GPS_INTERVAL_SECONDS)
        state.add_log("Aucune acceptation client detectee avant timeout")
    except asyncio.CancelledError:
        state.add_log("Tracking client interrompu")
        raise


async def _watch_driver_offer_and_run_tracking(
    ride_id: int,
    route: SimulationRoute,
    state: SimulationState,
) -> None:
    try:
        deadline = time.monotonic() + SIMULATION_WATCH_SECONDS
        while time.monotonic() < deadline:
            async with AsyncSessionLocal() as session:
                offer = await _get_first_pending_offer(session, ride_id)
                if offer is not None:
                    ride = await session.get(RideRequest, ride_id)
                    if ride is None:
                        raise SimulationUnsafeTargetError(Messages.SIMULATION_RIDE_NOT_FOUND)
                    client = await session.get(User, ride.client_id)
                    if client is None:
                        raise SimulationUnsafeTargetError(Messages.SIMULATION_RIDE_CLIENT_NOT_FOUND)

                    await accept_offer(session, offer.id, client)
                    state.driver_ids = [offer.driver_id]
                    state.offer_ids = [offer.id]
                    state.add_log(f"Offre chauffeur reel acceptee: {offer.id}")
                    await _run_driver_tracking_flow(ride_id, offer.driver_id, route, state)
                    return
            await asyncio.sleep(SIMULATION_GPS_INTERVAL_SECONDS)
        state.add_log("Aucune offre chauffeur detectee avant timeout")
        state.active = False
    except asyncio.CancelledError:
        state.add_log("Attente offre chauffeur interrompue")
        raise
    except Exception as exc:
        state.add_log(f"Erreur simulation chauffeur: {exc}")
        state.active = False


async def _get_first_pending_offer(
    session: AsyncSession,
    ride_id: int,
) -> RideOffer | None:
    result = await session.execute(
        select(RideOffer)
        .where(
            RideOffer.ride_request_id == ride_id,
            RideOffer.status == RideOfferStatus.PENDING,
        )
        .order_by(RideOffer.created_at.asc(), RideOffer.id.asc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _run_driver_tracking_flow(
    ride_id: int,
    driver_id: int,
    route: SimulationRoute,
    state: SimulationState,
) -> None:
    try:
        await _simulate_driver_path(
            driver_id,
            _driver_start_point(route.pickup),
            route.pickup,
            steps=SIMULATION_PICKUP_STEPS,
        )
        async with AsyncSessionLocal() as session:
            driver = await session.get(User, driver_id)
            if driver is None:
                raise SimulationUnsafeTargetError(Messages.DRIVER_NOT_FOUND)
            await mark_arrived(session, ride_id, driver)
            state.add_log("Arrive au point de prise en charge")

            await asyncio.sleep(SIMULATION_GPS_INTERVAL_SECONDS)
            await start_ride(session, ride_id, driver)
            state.add_log("Course demarree")

        await _simulate_driver_path(
            driver_id,
            route.pickup,
            route.dropoff,
            steps=SIMULATION_DROPOFF_STEPS,
        )

        async with AsyncSessionLocal() as session:
            driver = await session.get(User, driver_id)
            if driver is None:
                raise SimulationUnsafeTargetError(Messages.DRIVER_NOT_FOUND)
            await complete_ride(session, ride_id, driver)
            state.add_log("Course terminee")
            state.active = False
    except asyncio.CancelledError:
        state.add_log("Tracking chauffeur interrompu")
        raise
    except Exception as exc:
        state.add_log(f"Erreur simulation: {exc}")
        state.active = False


async def _simulate_driver_path(
    driver_id: int,
    start: SimulationPoint,
    end: SimulationPoint,
    *,
    steps: int,
) -> None:
    for latitude, longitude in _interpolate_points(start, end, steps=steps):
        await _push_driver_position(driver_id, latitude, longitude)
        await asyncio.sleep(SIMULATION_GPS_INTERVAL_SECONDS)


async def _push_driver_position(driver_id: int, latitude: float, longitude: float) -> None:
    location = DriverLocationUpdate(latitude=latitude, longitude=longitude)
    await realtime_gateway.update_position(driver_id, location)
    await realtime_gateway.send_driver_position_notification_to_clients(
        DriverPositionNotification(
            driver_id=driver_id,
            latitude=latitude,
            longitude=longitude,
        )
    )


async def _disconnect_simulation_drivers(driver_ids: list[int]) -> None:
    for driver_id in driver_ids:
        await realtime_gateway.disconnect_driver(driver_id)
    async with AsyncSessionLocal() as session:
        for driver_id in driver_ids:
            driver = await session.get(User, driver_id)
            if driver is None or not _is_simulation_user(driver):
                continue
            driver.driver_status = DriverStatus.OFFLINE
            driver.is_available = False
        await session.commit()


def _interpolate_points(
    start: SimulationPoint,
    end: SimulationPoint,
    *,
    steps: int,
) -> list[tuple[float, float]]:
    return [
        (
            start.latitude + (end.latitude - start.latitude) * index / steps,
            start.longitude + (end.longitude - start.longitude) * index / steps,
        )
        for index in range(1, steps + 1)
    ]


def _driver_offer_points(pickup: SimulationPoint) -> tuple[SimulationPoint, ...]:
    return (
        SimulationPoint("Driver Agdal 1", pickup.latitude + 0.006, pickup.longitude - 0.004),
        SimulationPoint("Driver Agdal 2", pickup.latitude - 0.008, pickup.longitude + 0.010),
        SimulationPoint("Driver Agdal 3", pickup.latitude + 0.012, pickup.longitude + 0.006),
    )


def _driver_start_point(pickup: SimulationPoint) -> SimulationPoint:
    return SimulationPoint(
        "Chauffeur test proche Agdal",
        pickup.latitude + 0.010,
        pickup.longitude - 0.006,
    )


def _route_from_ride_or_default(
    ride: RideRequest,
    default_route: SimulationRoute,
) -> SimulationRoute:
    if None in {
        ride.pickup_latitude,
        ride.pickup_longitude,
        ride.dropoff_latitude,
        ride.dropoff_longitude,
    }:
        return default_route

    pickup = SimulationPoint(
        label=ride.pickup_location,
        latitude=float(ride.pickup_latitude),
        longitude=float(ride.pickup_longitude),
    )
    dropoff = SimulationPoint(
        label=ride.dropoff_location,
        latitude=float(ride.dropoff_latitude),
        longitude=float(ride.dropoff_longitude),
    )
    return SimulationRoute(
        pickup=pickup,
        dropoff=dropoff,
        distance_km=round(
            _calculate_distance_km(
                pickup.latitude,
                pickup.longitude,
                dropoff.latitude,
                dropoff.longitude,
            ),
            2,
        ),
    )


def _fake_phone(*, index: int) -> str:
    seed = int(time.time() * 1000) % 1_000_000
    return f"{SIMULATION_USER_PHONE_PREFIX}{seed:06d}{index:02d}"


def _build_simulation_driver_profile(name: str) -> DriverProfileCreate:
    first_name, last_name = _split_simulation_driver_name(name)
    return DriverProfileCreate(
        first_name=first_name,
        last_name=last_name,
        address=SIMULATION_DRIVER_ADDRESS,
        id_card_photo=_simulation_document_base64(SIMULATION_ID_CARD_SEED),
        selfie_photo=_simulation_document_base64(SIMULATION_SELFIE_SEED),
        vehicle_photo=_simulation_document_base64(SIMULATION_VEHICLE_PHOTO_SEED),
        driver_license_file=_simulation_document_base64(SIMULATION_LICENSE_SEED),
        driver_license_expires_at=_simulation_document_expiry(),
        vehicle_registration_file=_simulation_document_base64(
            SIMULATION_REGISTRATION_SEED
        ),
        vehicle_registration_expires_at=_simulation_document_expiry(),
        vehicle_insurance_file=_simulation_document_base64(SIMULATION_INSURANCE_SEED),
        vehicle_insurance_expires_at=_simulation_document_expiry(),
        technical_inspection_file=_simulation_document_base64(
            SIMULATION_TECHNICAL_INSPECTION_SEED
        ),
        technical_inspection_expires_at=_simulation_document_expiry(),
    )


def _split_simulation_driver_name(name: str) -> tuple[str, str]:
    first_name, _, remainder = name.partition(" ")
    return first_name, remainder or "Test"


def _simulation_document_base64(seed: str) -> str:
    return base64.b64encode(seed.encode("utf-8")).decode("ascii")


def _simulation_document_expiry() -> date:
    return datetime.utcnow().date() + timedelta(days=SIMULATION_DOCUMENT_VALIDITY_DAYS)


def _is_simulation_user(user: User) -> bool:
    return user.phone_number.startswith(SIMULATION_USER_PHONE_PREFIX)


def _assert_valid_price(price: Decimal) -> None:
    if price <= 0 or price > MAX_SIMULATION_PRICE_FCFA:
        raise SimulationUnsafeTargetError(Messages.SIMULATION_PRICE_INVALID)
    if price < MIN_SIMULATION_PRICE_FCFA:
        raise SimulationUnsafeTargetError(Messages.SIMULATION_PRICE_TOO_LOW)


def _calculate_distance_km(
    latitude_1: float,
    longitude_1: float,
    latitude_2: float,
    longitude_2: float,
) -> float:
    from math import asin, cos, radians, sin, sqrt

    earth_radius_km = 6371.0
    latitude_1_rad = radians(latitude_1)
    longitude_1_rad = radians(longitude_1)
    latitude_2_rad = radians(latitude_2)
    longitude_2_rad = radians(longitude_2)
    latitude_delta = latitude_2_rad - latitude_1_rad
    longitude_delta = longitude_2_rad - longitude_1_rad
    haversine = (
        sin(latitude_delta / 2) ** 2
        + cos(latitude_1_rad) * cos(latitude_2_rad) * sin(longitude_delta / 2) ** 2
    )
    return earth_radius_km * 2 * asin(sqrt(haversine))

