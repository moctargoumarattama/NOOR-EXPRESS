from datetime import date, datetime, timedelta

from sqlalchemy import Select, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import ApiError
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.ride_offer import RideOffer
from app.models.ride_request_rejection import RideRequestRejection
from app.models.user import User, UserRole
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
from app.services.ride_policy import (
    CLIENT_ACTIVE_RIDE_STATUSES,
    DRIVER_ACTIVE_RIDE_STATUSES,
    NEGOTIABLE_RIDE_STATUSES,
)
from app.services.user_service import is_driver_verified


class RideRequestNotFoundError(Exception):
    pass


class RideRequestInvalidDriverError(Exception):
    pass


class RideRequestNotPendingError(Exception):
    pass


class RideRequestNotCompletedError(Exception):
    pass


class RideRequestExpiredError(Exception):
    pass


class RideRequestRatingNotAllowedError(Exception):
    pass


class RideRequestAlreadyRatedError(Exception):
    pass

RIDE_REQUEST_EXPIRATION_SECONDS = 300
CLIENT_ACTIVE_STATUSES = (
    *CLIENT_ACTIVE_RIDE_STATUSES,
)
DRIVER_ACTIVE_STATUSES = (
    *DRIVER_ACTIVE_RIDE_STATUSES,
)


async def create_ride_request(
    session: AsyncSession,
    ride_request_in: RideRequestCreate,
    current_user: User,
) -> RideRequest:
    from app.services.ride_lifecycle_service import create_ride

    return await create_ride(session, ride_request_in, current_user)


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
        from app.services.ride_lifecycle_service import expire_ride

        ride_request = await expire_ride(session, ride_request.id) or ride_request
        if ride_request.status not in ACTIVE_RIDE_STATUSES:
            return None
    return ride_request


async def get_available_ride_requests(
    session: AsyncSession,
    current_user: User,
    limit: int = 50,
    offset: int = 0,
) -> list[RideRequest]:
    if current_user.role != UserRole.DRIVER:
        raise RideRequestInvalidDriverError("User must have driver role")
    if not await is_driver_verified(session, current_user.id):
        raise ApiError(
            status_code=403,
            code="driver_not_verified",
            message="Driver verification is required.",
        )

    rejected_ride_ids_query = select(RideRequestRejection.ride_request_id).where(
        RideRequestRejection.driver_id == current_user.id
    )
    existing_offer_ride_ids_query = select(RideOffer.ride_request_id).where(
        RideOffer.driver_id == current_user.id
    )
    query: Select[tuple[RideRequest]] = (
        select(RideRequest)
        .where(
            RideRequest.status.in_(NEGOTIABLE_RIDE_STATUSES),
            RideRequest.driver_id.is_(None),
            RideRequest.id.not_in(rejected_ride_ids_query),
            RideRequest.id.not_in(existing_offer_ride_ids_query),
        )
        .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
        .offset(offset)
        .limit(limit)
    )
    result = await session.execute(query)

    available_ride_requests: list[RideRequest] = []
    for ride_request in result.scalars().all():
        from app.services.ride_lifecycle_service import expire_ride

        ride_request = await expire_ride(session, ride_request.id) or ride_request
        if ride_request.status not in NEGOTIABLE_RIDE_STATUSES:
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
        offered=grouped_counts.get(RideRequestStatus.OFFERED, 0),
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
        select(
            func.sum(
                func.coalesce(
                    RideRequest.final_price,
                    RideRequest.agreed_price,
                    RideRequest.estimated_price,
                )
            )
        ).where(
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
        select(
            func.avg(
                func.coalesce(
                    RideRequest.final_price,
                    RideRequest.agreed_price,
                    RideRequest.estimated_price,
                )
            )
        ).where(
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
                func.sum(
                    func.coalesce(
                        RideRequest.final_price,
                        RideRequest.agreed_price,
                        RideRequest.estimated_price,
                    )
                ),
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
            func.sum(
                func.coalesce(
                    RideRequest.final_price,
                    RideRequest.agreed_price,
                    RideRequest.estimated_price,
                )
            ).desc(),
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
            func.sum(
                func.coalesce(
                    RideRequest.final_price,
                    RideRequest.agreed_price,
                    RideRequest.estimated_price,
                )
            ),
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

    if ride_request.status not in NEGOTIABLE_RIDE_STATUSES:
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
    from app.services.ride_lifecycle_service import cancel_by_client, cancel_by_driver

    if current_user.role == UserRole.CLIENT:
        return await cancel_by_client(
            session,
            ride_request_id,
            current_user,
            ride_request_cancel_in,
        )
    if current_user.role == UserRole.DRIVER:
        return await cancel_by_driver(
            session,
            ride_request_id,
            current_user,
            ride_request_cancel_in,
        )
    raise ApiError(
        status_code=403,
        code="ride_cancellation_not_allowed",
        message="User cannot cancel this ride request",
    )


async def start_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    from app.services.ride_lifecycle_service import start_ride

    return await start_ride(session, ride_request_id, current_user)


async def arrive_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    from app.services.ride_lifecycle_service import mark_arrived

    return await mark_arrived(session, ride_request_id, current_user)


async def complete_ride_request(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_complete_in: RideRequestComplete | None = None,
) -> RideRequest:
    from app.services.ride_lifecycle_service import complete_ride

    return await complete_ride(
        session,
        ride_request_id,
        current_user,
        ride_request_complete_in,
    )


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
