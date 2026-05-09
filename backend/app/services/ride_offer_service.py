import asyncio
from datetime import datetime
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import conflict, forbidden, not_found
from app.core.messages import Messages
from app.core.firebase import notify_user
from app.db.database import AsyncSessionLocal
from app.models.driver_profile import DriverProfile, all_driver_documents_valid
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import User, UserRole
from app.realtime.gateway import driver_locator, ride_notifier
from app.realtime.schemas import (
    NewOfferDriverPayload,
    NewOfferNotification,
    OfferRejectedNotification,
)
from app.schemas.ride_offer import RideOfferDriverRead
from app.services.routing_service import fetch_osrm_route
from app.services.ride_lifecycle_service import (
    NEGOTIATION_TIMEOUT_SECONDS,
    expire_ride,
    mark_ride_as_offered,
)
from app.services.ride_policy import (
    DRIVER_ACTIVE_RIDE_STATUSES,
    NEGOTIABLE_RIDE_STATUSES,
    ensure_verified_driver,
)
from app.services.user_service import ensure_user_not_suspended, is_driver_verified


async def create_offer(
    session: AsyncSession,
    ride_id: int,
    driver_id: int,
    proposed_price: Decimal,
) -> RideOfferDriverRead:
    ride_request = await session.get(RideRequest, ride_id)
    if ride_request is None:
        raise not_found(Messages.RIDE_NOT_FOUND)

    driver = await session.get(User, driver_id)
    if driver is None:
        raise not_found(Messages.DRIVER_NOT_FOUND)
    if driver.role != UserRole.DRIVER:
        raise forbidden(Messages.DRIVER_ACCESS_REQUIRED)
    await ensure_user_not_suspended(session, driver)

    ensure_verified_driver(is_verified=await is_driver_verified(session, driver_id))

    ride_request = await expire_ride(session, ride_id) or ride_request
    if ride_request.status == RideRequestStatus.EXPIRED:
        raise conflict("offer_expired", Messages.OFFER_EXPIRED)
    if ride_request.status not in NEGOTIABLE_RIDE_STATUSES:
        raise conflict("ride_not_negotiable", Messages.RIDE_NOT_NEGOTIABLE)
    if await _driver_has_active_ride(session, driver_id):
        raise conflict(
            "driver_already_has_active_ride",
            Messages.RIDE_ALREADY_ACTIVE,
        )

    existing_offer = await session.execute(
        select(RideOffer).where(
            RideOffer.ride_request_id == ride_id,
            RideOffer.driver_id == driver_id,
        )
    )
    if existing_offer.scalar_one_or_none() is not None:
        raise conflict(
            "offer_already_exists",
            Messages.OFFER_ALREADY_EXISTS,
        )

    offer = RideOffer(
        ride_request_id=ride_id,
        driver_id=driver_id,
        proposed_price=proposed_price,
        status=RideOfferStatus.PENDING,
    )
    session.add(offer)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise conflict(
            "offer_already_exists",
            Messages.OFFER_ALREADY_EXISTS,
        ) from exc

    await session.refresh(offer)
    ride_request = await mark_ride_as_offered(session, ride_id)
    offer_read = await _build_offer_read(session, offer, ride_request, driver)

    await ride_notifier.send_new_offer_notification(
        client_id=ride_request.client_id,
        notification=NewOfferNotification(
            offer=NewOfferDriverPayload(
                ride_id=ride_request.id,
                offer_id=offer_read.offer_id,
                driver_id=offer_read.driver_id,
                driver_name=offer_read.driver_name,
                driver_rating=offer_read.driver_rating,
                proposed_price=float(offer_read.proposed_price),
                driver_distance_km=offer_read.driver_distance_km,
                driver_eta_minutes=offer_read.driver_eta_minutes,
                driver_completed_rides=offer_read.driver_completed_rides,
                driver_verified=offer_read.driver_verified,
                vehicle_brand=offer_read.vehicle_brand,
                vehicle_model=offer_read.vehicle_model,
                vehicle_color=offer_read.vehicle_color,
                plate_number=offer_read.plate_number,
                vehicle_photo=offer_read.vehicle_photo,
            )
        ),
    )
    await notify_user(
        session,
        ride_request.client_id,
        title="Nouvelle offre",
        body=f"{driver.name or driver.phone_number} propose {float(offer.proposed_price):.0f} FCFA",
        data={
            "type": "new_offer",
            "ride_id": ride_request.id,
            "offer_id": offer.id,
            "target_role": UserRole.CLIENT.value,
        },
    )
    return offer_read


async def get_offers_for_ride(
    session: AsyncSession,
    ride_id: int,
    client_id: int,
) -> list[RideOfferDriverRead]:
    ride_request = await session.get(RideRequest, ride_id)
    if ride_request is None:
        raise not_found(Messages.RIDE_NOT_FOUND)
    if ride_request.client_id != client_id:
        raise forbidden(Messages.FORBIDDEN)

    ride_request = await expire_ride(session, ride_id) or ride_request
    if ride_request.status == RideRequestStatus.EXPIRED:
        return []

    result = await session.execute(
        select(RideOffer, User)
        .join(User, User.id == RideOffer.driver_id)
        .where(
            RideOffer.ride_request_id == ride_id,
            RideOffer.status == RideOfferStatus.PENDING,
        )
        .order_by(RideOffer.created_at.desc(), RideOffer.id.desc())
    )
    return [
        await _build_offer_read(session, offer, ride_request, driver)
        for offer, driver in result.all()
    ]


async def reject_offer(
    session: AsyncSession,
    offer_id: int,
    client_id: int,
) -> RideOffer:
    offer = await session.get(RideOffer, offer_id)
    if offer is None:
        raise not_found(Messages.OFFER_NOT_FOUND)

    ride_request = await session.get(RideRequest, offer.ride_request_id)
    if ride_request is None:
        raise not_found(Messages.RIDE_NOT_FOUND)
    if ride_request.client_id != client_id:
        raise forbidden(Messages.FORBIDDEN)

    ride_request = await expire_ride(session, ride_request.id) or ride_request
    if (
        offer.status == RideOfferStatus.EXPIRED
        or ride_request.status == RideRequestStatus.EXPIRED
    ):
        raise conflict("offer_expired", Messages.OFFER_EXPIRED)
    if offer.status != RideOfferStatus.PENDING:
        raise conflict("offer_already_resolved", Messages.OFFER_ALREADY_RESOLVED)

    offer.status = RideOfferStatus.REJECTED
    offer.responded_at = datetime.utcnow()
    await session.commit()
    await session.refresh(offer)

    await mark_ride_as_offered(session, ride_request.id)
    await ride_notifier.send_offer_rejected_notification(
        driver_id=offer.driver_id,
        notification=OfferRejectedNotification(ride_id=ride_request.id),
    )
    await notify_user(
        session,
        offer.driver_id,
        title="Offre refusee",
        body="Le client a refuse votre proposition.",
        data={
            "type": "offer_rejected",
            "ride_id": ride_request.id,
            "target_role": UserRole.DRIVER.value,
        },
    )
    return offer


async def expire_ride_after_offer_timeout(ride_id: int) -> None:
    await asyncio.sleep(NEGOTIATION_TIMEOUT_SECONDS)
    async with AsyncSessionLocal() as session:
        await expire_ride(session, ride_id)


async def _build_offer_read(
    session: AsyncSession,
    offer: RideOffer,
    ride_request: RideRequest,
    driver: User,
) -> RideOfferDriverRead:
    connected_driver = next(
        (
            item
            for item in await driver_locator.get_connected_drivers()
            if item.driver_id == driver.id
        ),
        None,
    )
    distance_km, eta_minutes = await _get_driver_route_metrics(
        ride_request,
        connected_driver,
    )
    return RideOfferDriverRead(
        offer_id=offer.id,
        driver_id=driver.id,
        driver_name=driver.name or driver.phone_number,
        driver_rating=await _get_driver_rating(session, driver.id),
        vehicle_brand=driver.vehicle_brand,
        vehicle_model=driver.vehicle_model,
        vehicle_color=driver.vehicle_color,
        plate_number=driver.plate_number,
        vehicle_photo=getattr(driver, "vehicle_photo", None),
        proposed_price=offer.proposed_price,
        driver_distance_km=distance_km,
        driver_eta_minutes=eta_minutes,
        driver_completed_rides=await _get_driver_completed_rides(session, driver.id),
        driver_verified=await _driver_has_valid_documents(session, driver.id),
        status=offer.status,
        created_at=offer.created_at,
    )


async def _get_driver_rating(session: AsyncSession, driver_id: int) -> float:
    result = await session.execute(
        select(func.avg(RideRequest.client_rating_for_driver)).where(
            RideRequest.driver_id == driver_id,
            RideRequest.client_rating_for_driver.is_not(None),
        )
    )
    return round(float(result.scalar_one() or 0.0), 2)


async def _get_driver_completed_rides(session: AsyncSession, driver_id: int) -> int:
    result = await session.execute(
        select(func.count(RideRequest.id)).where(
            RideRequest.driver_id == driver_id,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
    )
    return int(result.scalar_one() or 0)


async def _driver_has_valid_documents(session: AsyncSession, driver_id: int) -> bool:
    result = await session.execute(
        select(DriverProfile).where(DriverProfile.user_id == driver_id)
    )
    profile = result.scalar_one_or_none()
    if profile is None:
        return False
    return all_driver_documents_valid(profile)


async def _get_driver_route_metrics(
    ride_request: RideRequest,
    connected_driver: object | None,
) -> tuple[float | None, int | None]:
    if connected_driver is None:
        return None, None
    origin_lat = getattr(connected_driver, "latitude", None)
    origin_lng = getattr(connected_driver, "longitude", None)
    route = await _fetch_driver_route(ride_request, origin_lat, origin_lng)
    if route is not None:
        return route["distance_km"], route["duration_min"]
    return (
        _calculate_distance_km(
            ride_request.pickup_latitude,
            ride_request.pickup_longitude,
            origin_lat,
            origin_lng,
        ),
        None,
    )


async def _fetch_driver_route(
    ride_request: RideRequest,
    origin_lat: float | None,
    origin_lng: float | None,
) -> dict | None:
    if None in {
        origin_lat,
        origin_lng,
        ride_request.pickup_latitude,
        ride_request.pickup_longitude,
    }:
        return None
    return await fetch_osrm_route(
        origin_lat,
        origin_lng,
        ride_request.pickup_latitude,
        ride_request.pickup_longitude,
    )


async def _driver_has_active_ride(
    session: AsyncSession,
    driver_id: int,
) -> bool:
    result = await session.execute(
        select(RideRequest.id)
        .where(
            RideRequest.driver_id == driver_id,
            RideRequest.status.in_(DRIVER_ACTIVE_RIDE_STATUSES),
        )
        .limit(1)
    )
    return result.scalar_one_or_none() is not None


def _calculate_distance_km(
    latitude_1: float | None,
    longitude_1: float | None,
    latitude_2: float | None,
    longitude_2: float | None,
) -> float | None:
    if None in {latitude_1, longitude_1, latitude_2, longitude_2}:
        return None
    return round(
        driver_locator._calculate_distance_km(  # noqa: SLF001 - shared local helper
            latitude_1=latitude_1,
            longitude_1=longitude_1,
            latitude_2=latitude_2,
            longitude_2=longitude_2,
        ),
        2,
    )
