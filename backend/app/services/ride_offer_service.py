import asyncio
from datetime import datetime, timedelta
from decimal import Decimal
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.database import AsyncSessionLocal
from app.core.firebase import notify_user, notify_users
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.user import DriverStatus, User, UserRole
from app.realtime.gateway import driver_locator, ride_notifier
from app.realtime.schemas import (NewOfferDriverPayload, NewOfferNotification,
                                  OfferAcceptedClientPayload,
                                  OfferAcceptedNotification,
                                  OfferRejectedNotification,
                                  RideStatusNotification)
from app.schemas.ride_offer import RideOfferDriverRead
from app.services.user_service import update_driver_status
NEGOTIATION_TIMEOUT_SECONDS = 300
class RideOfferError(Exception): pass
class RideOfferNotFoundError(RideOfferError): pass
class RideOfferForbiddenError(RideOfferError): pass
class RideOfferConflictError(RideOfferError): pass
def _calculate_distance_km(
    latitude_1: float | None,
    longitude_1: float | None,
    latitude_2: float | None,
    longitude_2: float | None,
) -> float | None:
    if None in {latitude_1, longitude_1, latitude_2, longitude_2}:
        return None
    return round(
        driver_locator._calculate_distance_km(  # noqa: SLF001 - reuse local math helper
            latitude_1=latitude_1,
            longitude_1=longitude_1,
            latitude_2=latitude_2,
            longitude_2=longitude_2,
        ),
        2,
    )
async def _get_driver_rating(session: AsyncSession, driver_id: int) -> float:
    result = await session.execute(
        select(func.avg(RideRequest.client_rating_for_driver)).where(
            RideRequest.driver_id == driver_id,
            RideRequest.client_rating_for_driver.is_not(None),
        )
    )
    return round(float(result.scalar_one() or 0.0), 2)
def _is_ride_negotiation_expired(ride_request: RideRequest) -> bool:
    return datetime.now() >= ride_request.created_at + timedelta(seconds=NEGOTIATION_TIMEOUT_SECONDS)
async def _build_offer_read(
    session: AsyncSession,
    offer: RideOffer,
    ride_request: RideRequest,
    driver: User,
) -> RideOfferDriverRead:
    connected_driver = next(
        (
            item
            for item in driver_locator.get_connected_drivers()
            if item.driver_id == driver.id
        ),
        None,
    )
    distance_km = _calculate_distance_km(
        ride_request.pickup_latitude,
        ride_request.pickup_longitude,
        connected_driver.latitude if connected_driver is not None else None,
        connected_driver.longitude if connected_driver is not None else None,
    )
    return RideOfferDriverRead(
        offer_id=offer.id,
        driver_id=driver.id,
        driver_name=driver.phone_number,
        driver_rating=await _get_driver_rating(session, driver.id),
        vehicle_brand=driver.vehicle_brand,
        vehicle_model=driver.vehicle_model,
        vehicle_color=driver.vehicle_color,
        plate_number=driver.plate_number,
        proposed_price=offer.proposed_price,
        driver_distance_km=distance_km,
        status=offer.status,
        created_at=offer.created_at,
    )
async def _expire_ride_if_needed(session: AsyncSession, ride_request: RideRequest) -> bool:
    if ride_request.status != RideRequestStatus.PENDING:
        return False
    if not _is_ride_negotiation_expired(ride_request):
        return False

    now = datetime.now()
    pending_offers = await session.execute(
        select(RideOffer).where(
            RideOffer.ride_request_id == ride_request.id,
            RideOffer.status == RideOfferStatus.PENDING,
        )
    )
    rejected_driver_ids: list[int] = []
    for offer in pending_offers.scalars().all():
        offer.status = RideOfferStatus.REJECTED
        offer.responded_at = now
        rejected_driver_ids.append(offer.driver_id)

    ride_request.status = RideRequestStatus.EXPIRED
    await session.commit()
    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )
    for driver_id in rejected_driver_ids:
        await ride_notifier.send_offer_rejected_notification(
            driver_id=driver_id,
            notification=OfferRejectedNotification(ride_id=ride_request.id),
        )
    return True

async def create_offer(
    session: AsyncSession,
    ride_id: int,
    driver_id: int,
    proposed_price: Decimal,
) -> RideOfferDriverRead:
    ride_request = await session.get(RideRequest, ride_id)
    driver = await session.get(User, driver_id)
    if ride_request is None or driver is None:
        raise RideOfferNotFoundError("Ride ou driver introuvable.")
    if driver.role != UserRole.DRIVER:
        raise RideOfferForbiddenError("Seul un driver peut proposer une offre.")
    if await _expire_ride_if_needed(session, ride_request):
        raise RideOfferConflictError("La ride a expire.")
    if ride_request.status != RideRequestStatus.PENDING:
        raise RideOfferConflictError("La ride n est plus ouverte a la negociation.")

    existing_offer = await session.execute(
        select(RideOffer).where(
            RideOffer.ride_request_id == ride_id,
            RideOffer.driver_id == driver_id,
        )
    )
    if existing_offer.scalar_one_or_none() is not None:
        raise RideOfferConflictError("Tu as deja propose un prix pour cette ride.")

    offer = RideOffer(
        ride_request_id=ride_id,
        driver_id=driver_id,
        proposed_price=proposed_price,
    )
    session.add(offer)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise RideOfferConflictError("Cette offre existe deja.") from exc
    await session.refresh(offer)

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
            )
        ),
    )
    driver_name = driver.name or driver.phone_number
    await notify_user(
        session,
        ride_request.client_id,
        title="Nouvelle offre",
        body=f"{driver_name} propose {float(offer.proposed_price):.0f} FCFA",
        data={
            "type": "new_offer",
            "ride_id": ride_request.id,
            "offer_id": offer.id,
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
        raise RideOfferNotFoundError("Ride introuvable.")
    if ride_request.client_id != client_id:
        raise RideOfferForbiddenError("Acces refuse a cette ride.")
    if await _expire_ride_if_needed(session, ride_request):
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

async def accept_offer(
    session: AsyncSession,
    offer_id: int,
    client_id: int,
) -> RideOffer:
    offer = await session.get(RideOffer, offer_id)
    if offer is None:
        raise RideOfferNotFoundError("Offre introuvable.")

    ride_request = await session.get(RideRequest, offer.ride_request_id)
    if ride_request is None:
        raise RideOfferNotFoundError("Ride introuvable.")
    if ride_request.client_id != client_id:
        raise RideOfferForbiddenError("Cette ride n appartient pas a ce client.")
    if await _expire_ride_if_needed(session, ride_request):
        raise RideOfferConflictError("La negociation a expire.")
    if ride_request.status != RideRequestStatus.PENDING:
        raise RideOfferConflictError("La ride n est plus negociable.")

    now = datetime.now()
    other_offers = await session.execute(
        select(RideOffer).where(RideOffer.ride_request_id == ride_request.id)
    )
    rejected_driver_ids: list[int] = []
    for item in other_offers.scalars().all():
        item.status = RideOfferStatus.ACCEPTED if item.id == offer.id else RideOfferStatus.REJECTED
        item.responded_at = now
        if item.id != offer.id:
            rejected_driver_ids.append(item.driver_id)

    ride_request.driver_id = offer.driver_id
    ride_request.estimated_price = float(offer.proposed_price)
    ride_request.status = RideRequestStatus.ACCEPTED
    await session.commit()
    await session.refresh(offer)
    await update_driver_status(session, offer.driver_id, DriverStatus.BUSY)
    client = await session.get(User, ride_request.client_id)

    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )
    selected_driver = await session.get(User, offer.driver_id)
    selected_driver_name = (
        selected_driver.name or selected_driver.phone_number
        if selected_driver is not None
        else "Votre driver"
    )
    await notify_user(
        session,
        ride_request.client_id,
        title="Driver en route",
        body=f"{selected_driver_name} arrive vers vous.",
        data={"type": "driver_en_route", "ride_id": ride_request.id},
    )
    await ride_notifier.send_offer_accepted_notification(
        driver_id=offer.driver_id,
        notification=OfferAcceptedNotification(
            ride_id=ride_request.id,
            client=OfferAcceptedClientPayload(
                name=client.phone_number if client is not None else "Client",
                pickup=ride_request.pickup_location,
            ),
        ),
    )
    await notify_user(
        session,
        offer.driver_id,
        title="Offre acceptee",
        body=f"{client.phone_number if client is not None else 'Le client'} vous a choisi !",
        data={"type": "offer_accepted", "ride_id": ride_request.id},
    )
    for driver_id in rejected_driver_ids:
        await ride_notifier.send_offer_rejected_notification(
            driver_id=driver_id,
            notification=OfferRejectedNotification(ride_id=ride_request.id),
        )
    await notify_users(
        session,
        rejected_driver_ids,
        title="Non retenu",
        body="Le client a choisi un autre driver",
        data={"type": "offer_rejected", "ride_id": ride_request.id},
    )
    return offer

async def reject_offer(
    session: AsyncSession,
    offer_id: int,
    client_id: int,
) -> RideOffer:
    offer = await session.get(RideOffer, offer_id)
    if offer is None:
        raise RideOfferNotFoundError("Offre introuvable.")
    ride_request = await session.get(RideRequest, offer.ride_request_id)
    if ride_request is None:
        raise RideOfferNotFoundError("Ride introuvable.")
    if ride_request.client_id != client_id:
        raise RideOfferForbiddenError("Cette ride n appartient pas a ce client.")
    if offer.status != RideOfferStatus.PENDING:
        raise RideOfferConflictError("Cette offre a deja ete traitee.")

    offer.status = RideOfferStatus.REJECTED
    offer.responded_at = datetime.now()
    await session.commit()
    await session.refresh(offer)
    await ride_notifier.send_offer_rejected_notification(
        driver_id=offer.driver_id,
        notification=OfferRejectedNotification(ride_id=ride_request.id),
    )
    return offer

async def expire_ride_after_offer_timeout(ride_id: int) -> None:
    await asyncio.sleep(NEGOTIATION_TIMEOUT_SECONDS)
    async with AsyncSessionLocal() as session:
        ride_request = await session.get(RideRequest, ride_id)
        if ride_request is None or ride_request.status != RideRequestStatus.PENDING:
            return
        if not _is_ride_negotiation_expired(ride_request):
            return
        await _expire_ride_if_needed(session, ride_request)
