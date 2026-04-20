from datetime import date, datetime, timedelta
from decimal import Decimal
from math import asin, cos, radians, sin, sqrt

from sqlalchemy import Select, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.firebase import notify_user
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.ride_request_rejection import RideRequestRejection
from app.models.user import DriverStatus, User, UserRole
from app.realtime.gateway import driver_locator, ride_notifier
from app.realtime.schemas import (
    NearbyDriverLocation,
    NewRideRequestNotification,
    RideStatusNotification,
)
from app.schemas.ride_request import (
    ClientRideRequestStatsRead,
    ClientRideRatingCreate,
    DriverRideRatingCreate,
    RideRequestCancel,
    RideRequestComplete,
    RideRequestCreate,
    RideRequestReject,
    DriverRideRequestStatsRead,
    RevenueStatsRead,
    RideRequestStatsRead,
    TopDriverStatsRead,
)
from app.services.pricing_service import (
    calculate_ride_price,
    get_platform_commission_percent,
    money,
)
from app.services.user_service import get_drivers_by_status, update_driver_status


class RideRequestNotFoundError(Exception):
    pass


class RideRequestInvalidClientError(Exception):
    pass


class RideRequestDriverNotFoundError(Exception):
    pass


class RideRequestInvalidDriverError(Exception):
    pass


class RideRequestNotPendingError(Exception):
    pass


class RideRequestNotAcceptedError(Exception):
    pass


class RideRequestNotArrivedError(Exception):
    pass


class RideRequestNotStartedError(Exception):
    pass


class RideRequestNotCompletedError(Exception):
    pass


class RideRequestDriverMismatchError(Exception):
    pass


class RideRequestCancellationNotAllowedError(Exception):
    pass


class RideRequestExpiredError(Exception):
    pass


class RideRequestDriverNotConnectedError(Exception):
    pass


class RideRequestRatingNotAllowedError(Exception):
    pass


class RideRequestAlreadyRatedError(Exception):
    pass


MATCHING_MAX_DISTANCE_KM = 10.0
MATCHING_MAX_DRIVERS = 5
RIDE_REQUEST_EXPIRATION_SECONDS = 300
CLIENT_ACTIVE_STATUSES = (
    RideRequestStatus.PENDING,
    RideRequestStatus.ACCEPTED,
    RideRequestStatus.ARRIVED,
    RideRequestStatus.STARTED,
)
DRIVER_ACTIVE_STATUSES = (
    RideRequestStatus.ACCEPTED,
    RideRequestStatus.ARRIVED,
    RideRequestStatus.STARTED,
)


def _calculate_distance_km(
    latitude_1: float,
    longitude_1: float,
    latitude_2: float,
    longitude_2: float,
) -> float:
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
    arc = 2 * asin(sqrt(haversine))
    return earth_radius_km * arc


def _calculate_estimated_price(ride_request_in: RideRequestCreate) -> float:
    distance_km = _calculate_distance_km(
        latitude_1=ride_request_in.client_latitude,
        longitude_1=ride_request_in.client_longitude,
        latitude_2=ride_request_in.dropoff_latitude,
        longitude_2=ride_request_in.dropoff_longitude,
    )
    return round(max(2.0, 2 + (distance_km * 1.5)), 2)


def _round_currency(value: float | Decimal) -> float:
    return round(float(value), 2)


async def _calculate_ride_financials(
    session: AsyncSession,
    final_price: float | Decimal,
) -> tuple[Decimal, Decimal, Decimal]:
    normalized_final_price = money(final_price)
    commission_percent = await get_platform_commission_percent(session)
    platform_commission = money(
        normalized_final_price * commission_percent / Decimal("100")
    )
    driver_net_earnings = money(normalized_final_price - platform_commission)
    return normalized_final_price, platform_commission, driver_net_earnings


async def _get_rejected_driver_ids(
    session: AsyncSession,
    ride_request_id: int,
) -> set[int]:
    result = await session.execute(
        select(RideRequestRejection.driver_id).where(
            RideRequestRejection.ride_request_id == ride_request_id
        )
    )
    return set(result.scalars().all())


async def _get_matching_drivers_for_ride(
    session: AsyncSession,
    ride_request: RideRequest,
    latitude: float,
    longitude: float,
) -> list[NearbyDriverLocation]:
    nearby_drivers = driver_locator.get_nearby_drivers(
        latitude=latitude,
        longitude=longitude,
        max_distance_km=MATCHING_MAX_DISTANCE_KM,
    )
    online_drivers = await get_drivers_by_status(
        session,
        [driver.driver_id for driver in nearby_drivers],
        DriverStatus.ONLINE,
        is_available=True,
    )
    online_driver_ids = {driver.id for driver in online_drivers}
    rejected_driver_ids = await _get_rejected_driver_ids(session, ride_request.id)

    return [
        driver
        for driver in nearby_drivers
        if driver.driver_id in online_driver_ids
        and driver.driver_id not in rejected_driver_ids
    ][:MATCHING_MAX_DRIVERS]


async def create_ride_request(
    session: AsyncSession,
    ride_request_in: RideRequestCreate,
    current_user: User,
) -> RideRequest:
    if current_user.role != UserRole.CLIENT:
        raise RideRequestInvalidClientError("User must have client role")

    estimated_price = ride_request_in.estimated_price
    if estimated_price is None:
        pricing_estimate = await calculate_ride_price(
            session,
            pickup_latitude=ride_request_in.client_latitude,
            pickup_longitude=ride_request_in.client_longitude,
            dropoff_latitude=ride_request_in.dropoff_latitude,
            dropoff_longitude=ride_request_in.dropoff_longitude,
        )
        estimated_price = pricing_estimate["final_estimated_price"]

    ride_request = RideRequest(
        client_id=current_user.id,
        pickup_location=ride_request_in.pickup_location,
        dropoff_location=ride_request_in.dropoff_location,
        pickup_latitude=ride_request_in.client_latitude,
        pickup_longitude=ride_request_in.client_longitude,
        dropoff_latitude=ride_request_in.dropoff_latitude,
        dropoff_longitude=ride_request_in.dropoff_longitude,
        estimated_price=money(estimated_price),
        status=RideRequestStatus.PENDING,
    )
    session.add(ride_request)
    await session.commit()
    await session.refresh(ride_request)

    matching_drivers = await _get_matching_drivers_for_ride(
        session,
        ride_request,
        ride_request_in.client_latitude,
        ride_request_in.client_longitude,
    )
    for nearby_driver in matching_drivers:
        await ride_notifier.send_new_ride_request_notification(
            driver_id=nearby_driver.driver_id,
            notification=NewRideRequestNotification(
                ride_id=ride_request.id,
                ride_request_id=ride_request.id,
                pickup=ride_request.pickup_location,
                pickup_location=ride_request.pickup_location,
                dropoff=ride_request.dropoff_location,
                dropoff_location=ride_request.dropoff_location,
                client_price=ride_request.estimated_price,
                distance_km=nearby_driver.distance_km,
            ),
        )
        await notify_user(
            session,
            nearby_driver.driver_id,
            title="Nouvelle course",
            body=(
                f"{ride_request.pickup_location} -> "
                f"{ride_request.dropoff_location} - "
                f"{ride_request.estimated_price:.0f} FCFA"
            ),
            data={
                "type": "new_ride_request",
                "ride_id": ride_request.id,
            },
        )

    return ride_request


async def get_ride_request_by_id(
    session: AsyncSession, ride_request_id: int
) -> RideRequest | None:
    return await session.get(RideRequest, ride_request_id)


def _is_ride_request_expired(ride_request: RideRequest) -> bool:
    expires_at = ride_request.created_at + timedelta(seconds=RIDE_REQUEST_EXPIRATION_SECONDS)
    return datetime.now() >= expires_at


async def _expire_ride_request_if_needed(
    session: AsyncSession,
    ride_request: RideRequest,
) -> bool:
    if ride_request.status != RideRequestStatus.PENDING:
        return False

    if not _is_ride_request_expired(ride_request):
        return False

    ride_request.status = RideRequestStatus.EXPIRED
    await session.commit()
    await session.refresh(ride_request)
    return True


async def list_ride_requests(
    session: AsyncSession,
    client_id: int | None = None,
    driver_id: int | None = None,
    status: RideRequestStatus | None = None,
    limit: int = 100,
    offset: int = 0,
) -> list[RideRequest]:
    query: Select[tuple[RideRequest]] = select(RideRequest).order_by(RideRequest.id.desc())

    if client_id is not None:
        query = query.where(RideRequest.client_id == client_id)

    if driver_id is not None:
        query = query.where(RideRequest.driver_id == driver_id)

    if status is not None:
        query = query.where(RideRequest.status == status)

    query = query.offset(offset).limit(limit)

    result = await session.execute(query)
    return list(result.scalars().all())


async def get_client_ride_history(
    session: AsyncSession,
    client_id: int,
    limit: int = 100,
    offset: int = 0,
) -> list[RideRequest]:
    query: Select[tuple[RideRequest]] = (
        select(RideRequest)
        .where(RideRequest.client_id == client_id)
        .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_driver_ride_history(
    session: AsyncSession,
    driver_id: int,
    limit: int = 100,
    offset: int = 0,
) -> list[RideRequest]:
    query: Select[tuple[RideRequest]] = (
        select(RideRequest)
        .where(RideRequest.driver_id == driver_id)
        .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_active_ride_request(
    session: AsyncSession,
    current_user: User,
) -> RideRequest | None:
    if current_user.role == UserRole.CLIENT:
        query = (
            select(RideRequest)
            .where(
                RideRequest.client_id == current_user.id,
                RideRequest.status.in_(CLIENT_ACTIVE_STATUSES),
            )
            .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
            .limit(1)
        )
    elif current_user.role == UserRole.DRIVER:
        query = (
            select(RideRequest)
            .where(
                RideRequest.driver_id == current_user.id,
                RideRequest.status.in_(DRIVER_ACTIVE_STATUSES),
            )
            .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
            .limit(1)
        )
    else:
        return None

    result = await session.execute(query)
    ride_request = result.scalar_one_or_none()
    if ride_request is not None:
        await _expire_ride_request_if_needed(session, ride_request)
    return ride_request


async def get_available_ride_requests(
    session: AsyncSession,
    current_user: User,
    limit: int = 50,
    offset: int = 0,
) -> list[RideRequest]:
    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")

    rejected_ride_ids_query = select(RideRequestRejection.ride_request_id).where(
        RideRequestRejection.driver_id == current_user.id
    )
    query: Select[tuple[RideRequest]] = (
        select(RideRequest)
        .where(
            RideRequest.status == RideRequestStatus.PENDING,
            RideRequest.driver_id.is_(None),
            RideRequest.id.not_in(rejected_ride_ids_query),
        )
        .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await session.execute(query)

    available_ride_requests: list[RideRequest] = []
    for ride_request in result.scalars().all():
        if await _expire_ride_request_if_needed(session, ride_request):
            continue
        available_ride_requests.append(ride_request)

    return available_ride_requests


async def get_ride_request_stats(session: AsyncSession) -> RideRequestStatsRead:
    total_result = await session.execute(select(func.count(RideRequest.id)))
    total_rides = total_result.scalar_one()

    grouped_result = await session.execute(
        select(RideRequest.status, func.count(RideRequest.id)).group_by(RideRequest.status)
    )
    grouped_counts = {status: count for status, count in grouped_result.all()}
    aggregates_result = await session.execute(
        select(
            func.avg(RideRequest.estimated_price),
            func.sum(RideRequest.estimated_price).filter(
                RideRequest.status == RideRequestStatus.COMPLETED
            ),
        )
    )
    average_estimated_price, total_estimated_revenue_completed = (
        aggregates_result.one()
    )

    return RideRequestStatsRead(
        total_rides=total_rides,
        pending=grouped_counts.get(RideRequestStatus.PENDING, 0),
        accepted=grouped_counts.get(RideRequestStatus.ACCEPTED, 0),
        started=grouped_counts.get(RideRequestStatus.STARTED, 0),
        completed=grouped_counts.get(RideRequestStatus.COMPLETED, 0),
        cancelled=grouped_counts.get(RideRequestStatus.CANCELLED, 0),
        expired=grouped_counts.get(RideRequestStatus.EXPIRED, 0),
        average_estimated_price=round(float(average_estimated_price or 0.0), 2),
        total_estimated_revenue_completed=round(
            float(total_estimated_revenue_completed or 0.0), 2
        ),
        total_cancelled=grouped_counts.get(RideRequestStatus.CANCELLED, 0),
        total_expired=grouped_counts.get(RideRequestStatus.EXPIRED, 0),
    )


async def get_driver_ride_request_stats(
    session: AsyncSession,
    driver_id: int,
) -> DriverRideRequestStatsRead:
    total_result = await session.execute(
        select(func.count(RideRequest.id)).where(RideRequest.driver_id == driver_id)
    )
    total_rides = total_result.scalar_one()

    grouped_result = await session.execute(
        select(RideRequest.status, func.count(RideRequest.id))
        .where(RideRequest.driver_id == driver_id)
        .group_by(RideRequest.status)
    )
    grouped_counts = {status: count for status, count in grouped_result.all()}
    total_earnings = await get_driver_earnings(session, driver_id)
    total_net_earnings = await get_driver_net_earnings(session, driver_id)
    average_completed_price = await get_driver_average_completed_price(session, driver_id)
    average_rating_from_clients = await get_driver_average_rating(session, driver_id)
    total_ratings_from_clients = await get_driver_total_ratings(session, driver_id)

    return DriverRideRequestStatsRead(
        total_rides=total_rides,
        completed=grouped_counts.get(RideRequestStatus.COMPLETED, 0),
        started=grouped_counts.get(RideRequestStatus.STARTED, 0),
        cancelled=grouped_counts.get(RideRequestStatus.CANCELLED, 0),
        total_earnings=total_earnings,
        total_net_earnings=total_net_earnings,
        average_completed_price=average_completed_price,
        average_rating_from_clients=average_rating_from_clients,
        total_ratings_from_clients=total_ratings_from_clients,
    )


async def get_client_ride_request_stats(
    session: AsyncSession,
    client_id: int,
) -> ClientRideRequestStatsRead:
    total_result = await session.execute(
        select(func.count(RideRequest.id)).where(RideRequest.client_id == client_id)
    )
    total_rides = total_result.scalar_one()

    grouped_result = await session.execute(
        select(RideRequest.status, func.count(RideRequest.id))
        .where(RideRequest.client_id == client_id)
        .group_by(RideRequest.status)
    )
    grouped_counts = {status: count for status, count in grouped_result.all()}
    average_rating_from_drivers = await get_client_average_rating(session, client_id)
    total_ratings_from_drivers = await get_client_total_ratings(session, client_id)

    return ClientRideRequestStatsRead(
        total_rides=total_rides,
        completed=grouped_counts.get(RideRequestStatus.COMPLETED, 0),
        cancelled=grouped_counts.get(RideRequestStatus.CANCELLED, 0),
        average_rating_from_drivers=average_rating_from_drivers,
        total_ratings_from_drivers=total_ratings_from_drivers,
    )


async def get_driver_earnings(
    session: AsyncSession,
    driver_id: int,
) -> float:
    result = await session.execute(
        select(func.sum(func.coalesce(RideRequest.final_price, RideRequest.estimated_price))).where(
            RideRequest.driver_id == driver_id,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
    )
    total_earnings = result.scalar_one()
    return round(float(total_earnings or 0.0), 2)


async def get_driver_net_earnings(
    session: AsyncSession,
    driver_id: int,
) -> float:
    result = await session.execute(
        select(func.sum(RideRequest.driver_net_earnings)).where(
            RideRequest.driver_id == driver_id,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
    )
    total_net_earnings = result.scalar_one()
    return round(float(total_net_earnings or 0.0), 2)


async def get_driver_average_completed_price(
    session: AsyncSession,
    driver_id: int,
) -> float:
    result = await session.execute(
        select(func.avg(func.coalesce(RideRequest.final_price, RideRequest.estimated_price))).where(
            RideRequest.driver_id == driver_id,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
    )
    average_completed_price = result.scalar_one()
    return round(float(average_completed_price or 0.0), 2)


async def get_driver_average_rating(
    session: AsyncSession,
    driver_id: int,
) -> float:
    result = await session.execute(
        select(func.avg(RideRequest.client_rating_for_driver)).where(
            RideRequest.driver_id == driver_id,
            RideRequest.client_rating_for_driver.is_not(None),
        )
    )
    average_rating = result.scalar_one()
    return round(float(average_rating or 0.0), 2)


async def get_driver_total_ratings(
    session: AsyncSession,
    driver_id: int,
) -> int:
    result = await session.execute(
        select(func.count(RideRequest.id)).where(
            RideRequest.driver_id == driver_id,
            RideRequest.client_rating_for_driver.is_not(None),
        )
    )
    return result.scalar_one()


async def get_client_average_rating(
    session: AsyncSession,
    client_id: int,
) -> float:
    result = await session.execute(
        select(func.avg(RideRequest.driver_rating_for_client)).where(
            RideRequest.client_id == client_id,
            RideRequest.driver_rating_for_client.is_not(None),
        )
    )
    average_rating = result.scalar_one()
    return round(float(average_rating or 0.0), 2)


async def get_client_total_ratings(
    session: AsyncSession,
    client_id: int,
) -> int:
    result = await session.execute(
        select(func.count(RideRequest.id)).where(
            RideRequest.client_id == client_id,
            RideRequest.driver_rating_for_client.is_not(None),
        )
    )
    return result.scalar_one()


async def get_top_drivers(
    session: AsyncSession,
    limit: int = 5,
) -> list[TopDriverStatsRead]:
    result = await session.execute(
        select(
            User.id,
            User.phone_number,
            func.count(RideRequest.id).label("completed_rides"),
            func.coalesce(
                func.sum(func.coalesce(RideRequest.final_price, RideRequest.estimated_price)),
                0.0,
            ).label("total_earnings"),
        )
        .join(RideRequest, RideRequest.driver_id == User.id)
        .where(
            User.role == UserRole.DRIVER,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
        .group_by(User.id, User.phone_number)
        .order_by(
            func.count(RideRequest.id).desc(),
            func.sum(func.coalesce(RideRequest.final_price, RideRequest.estimated_price)).desc(),
            User.id.asc(),
        )
        .limit(limit)
    )
    rows = result.all()
    return [
        TopDriverStatsRead(
            driver_id=driver_id,
            phone_number=phone_number,
            completed_rides=completed_rides,
            total_earnings=round(float(total_earnings or 0.0), 2),
        )
        for driver_id, phone_number, completed_rides, total_earnings in rows
    ]


async def get_revenue_stats(
    session: AsyncSession,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    filter_date_from: date | None = None,
    filter_date_to: date | None = None,
) -> RevenueStatsRead:
    query = select(
        func.count(RideRequest.id),
        func.coalesce(
            func.sum(func.coalesce(RideRequest.final_price, RideRequest.estimated_price)),
            0.0,
        ),
    ).where(RideRequest.status == RideRequestStatus.COMPLETED)

    if date_from is not None:
        query = query.where(RideRequest.created_at >= date_from)

    if date_to is not None:
        query = query.where(RideRequest.created_at <= date_to)

    result = await session.execute(query)
    completed_rides, total_revenue = result.one()
    return RevenueStatsRead(
        date_from=filter_date_from,
        date_to=filter_date_to,
        completed_rides=completed_rides,
        total_revenue=round(float(total_revenue or 0.0), 2),
    )


async def accept_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if await _expire_ride_request_if_needed(session, ride_request):
        raise RideRequestExpiredError("Ride request is expired")

    if ride_request.status != RideRequestStatus.PENDING:
        raise RideRequestNotPendingError("Ride request is not pending")

    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")

    ride_request.driver_id = current_user.id
    ride_request.status = RideRequestStatus.ACCEPTED
    await session.commit()
    await session.refresh(ride_request)
    await update_driver_status(session, current_user.id, DriverStatus.BUSY)
    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )
    driver_name = current_user.name or current_user.phone_number
    await notify_user(
        session,
        ride_request.client_id,
        title="Driver en route",
        body=f"{driver_name} arrive vers vous.",
        data={"type": "driver_en_route", "ride_id": ride_request.id},
    )
    return ride_request


async def reject_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_reject_in: RideRequestReject,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if await _expire_ride_request_if_needed(session, ride_request):
        raise RideRequestExpiredError("Ride request is expired")

    if ride_request.status != RideRequestStatus.PENDING:
        raise RideRequestNotPendingError("Ride request is not pending")

    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")

    existing_rejection = await session.execute(
        select(RideRequestRejection).where(
            RideRequestRejection.ride_request_id == ride_request.id,
            RideRequestRejection.driver_id == current_user.id,
        )
    )
    if existing_rejection.scalar_one_or_none() is None:
        session.add(
            RideRequestRejection(
                ride_request_id=ride_request.id,
                driver_id=current_user.id,
                reason=ride_request_reject_in.reason,
            )
        )
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()

    return ride_request


async def cancel_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_cancel_in: RideRequestCancel,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    await _expire_ride_request_if_needed(session, ride_request)

    if current_user.role == UserRole.CLIENT:
        if ride_request.client_id != current_user.id:
            raise RideRequestCancellationNotAllowedError("Client cannot cancel this ride request")
        if ride_request.status not in {RideRequestStatus.PENDING, RideRequestStatus.ACCEPTED}:
            raise RideRequestCancellationNotAllowedError("Ride request cannot be cancelled by client")
    elif current_user.role == UserRole.DRIVER:
        if ride_request.driver_id != current_user.id:
            raise RideRequestCancellationNotAllowedError("Driver cannot cancel this ride request")
        if ride_request.status != RideRequestStatus.ACCEPTED:
            raise RideRequestCancellationNotAllowedError("Ride request cannot be cancelled by driver")
    else:
        raise RideRequestCancellationNotAllowedError("User cannot cancel this ride request")

    ride_request.status = RideRequestStatus.CANCELLED
    ride_request.cancellation_reason = ride_request_cancel_in.reason
    ride_request.cancelled_by_role = current_user.role
    await session.commit()
    await session.refresh(ride_request)

    notification = RideStatusNotification(
        ride_request_id=ride_request.id,
        status=ride_request.status.value,
    )
    if current_user.role == UserRole.CLIENT and ride_request.driver_id is not None:
        await update_driver_status(session, ride_request.driver_id, DriverStatus.ONLINE)
        await ride_notifier.send_ride_status_notification_to_driver(
            driver_id=ride_request.driver_id,
            notification=notification,
        )
    elif current_user.role == UserRole.DRIVER:
        await update_driver_status(session, current_user.id, DriverStatus.ONLINE)
        await ride_notifier.send_ride_status_notification(
            client_id=ride_request.client_id,
            notification=notification,
        )

    return ride_request


async def start_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if ride_request.status not in {
        RideRequestStatus.ACCEPTED,
        RideRequestStatus.ARRIVED,
    }:
        raise RideRequestNotArrivedError("Ride request is not ready to start")

    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")

    if ride_request.driver_id != current_user.id:
        raise RideRequestDriverMismatchError("Driver is not assigned to this ride request")

    ride_request.status = RideRequestStatus.STARTED
    await session.commit()
    await session.refresh(ride_request)
    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )
    await notify_user(
        session,
        ride_request.client_id,
        title="Course demarree",
        body="Bonne route !",
        data={"type": "ride_started", "ride_id": ride_request.id},
    )
    return ride_request


async def arrive_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if ride_request.status != RideRequestStatus.ACCEPTED:
        raise RideRequestNotAcceptedError("Ride request is not accepted")

    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")

    if ride_request.driver_id != current_user.id:
        raise RideRequestDriverMismatchError("Driver is not assigned to this ride request")

    ride_request.status = RideRequestStatus.ARRIVED
    await session.commit()
    await session.refresh(ride_request)
    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )
    await notify_user(
        session,
        ride_request.client_id,
        title="Driver arrive",
        body="Votre driver vous attend.",
        data={"type": "driver_arrived", "ride_id": ride_request.id},
    )
    return ride_request


async def complete_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_complete_in: RideRequestComplete | None = None,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if ride_request.status != RideRequestStatus.STARTED:
        raise RideRequestNotStartedError("Ride request is not started")

    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")

    if ride_request.driver_id != current_user.id:
        raise RideRequestDriverMismatchError("Driver is not assigned to this ride request")

    final_price_input = (
        ride_request_complete_in.final_price
        if ride_request_complete_in is not None
        else None
    )
    final_price_base = (
        final_price_input if final_price_input is not None else ride_request.estimated_price
    )
    final_price, platform_commission, driver_net_earnings = (
        await _calculate_ride_financials(session, final_price_base)
    )

    ride_request.status = RideRequestStatus.COMPLETED
    ride_request.final_price = final_price
    ride_request.platform_commission = platform_commission
    ride_request.driver_net_earnings = driver_net_earnings
    await session.commit()
    await session.refresh(ride_request)
    await update_driver_status(session, current_user.id, DriverStatus.ONLINE)
    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )
    await notify_user(
        session,
        ride_request.client_id,
        title="Course terminee",
        body="Merci d'avoir utilise Noor Express.",
        data={"type": "ride_completed", "ride_id": ride_request.id},
    )
    await notify_user(
        session,
        current_user.id,
        title="Course terminee",
        body="Merci d'avoir utilise Noor Express.",
        data={"type": "ride_completed", "ride_id": ride_request.id},
    )
    return ride_request


async def rate_driver_for_ride(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    rating_in: ClientRideRatingCreate,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if ride_request.status != RideRequestStatus.COMPLETED:
        raise RideRequestNotCompletedError("Ride request is not completed")

    if current_user.role != UserRole.CLIENT or ride_request.client_id != current_user.id:
        raise RideRequestRatingNotAllowedError("Client cannot rate this ride")

    if ride_request.client_rating_for_driver is not None:
        raise RideRequestAlreadyRatedError("Driver has already been rated for this ride")

    ride_request.client_rating_for_driver = rating_in.rating
    ride_request.client_rating_comment = rating_in.comment
    await session.commit()
    await session.refresh(ride_request)
    return ride_request


async def rate_client_for_ride(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    rating_in: DriverRideRatingCreate,
) -> RideRequest:
    ride_request = await session.get(RideRequest, ride_request_id)
    if ride_request is None:
        raise RideRequestNotFoundError("Ride request not found")

    if ride_request.status != RideRequestStatus.COMPLETED:
        raise RideRequestNotCompletedError("Ride request is not completed")

    if current_user.role != UserRole.DRIVER or ride_request.driver_id != current_user.id:
        raise RideRequestRatingNotAllowedError("Driver cannot rate this ride")

    if ride_request.driver_rating_for_client is not None:
        raise RideRequestAlreadyRatedError("Client has already been rated for this ride")

    ride_request.driver_rating_for_client = rating_in.rating
    ride_request.driver_rating_comment = rating_in.comment
    await session.commit()
    await session.refresh(ride_request)
    return ride_request
