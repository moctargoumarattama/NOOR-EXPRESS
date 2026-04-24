from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import ApiError, conflict, forbidden, not_found
from app.core.firebase import notify_user, notify_users
from app.models.driver_profile import DriverProfile, DriverVerificationStatus
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.ride_request_rejection import RideRequestRejection
from app.models.user import DriverStatus, User, UserRole
from app.realtime.gateway import driver_locator, ride_notifier
from app.realtime.schemas import (
    NearbyDriverLocation,
    NewRideRequestNotification,
    OfferAcceptedClientPayload,
    OfferAcceptedNotification,
    OfferRejectedNotification,
    RideStatusNotification,
)
from app.schemas.ride_request import (
    RideRequestCancel,
    RideRequestComplete,
    RideRequestCreate,
)
from app.services.pricing_service import (
    calculate_ride_price,
    get_platform_commission_percent,
    money,
)
from app.services.ride_policy import (
    CLIENT_ACTIVE_RIDE_STATUSES,
    DRIVER_ACTIVE_RIDE_STATUSES,
    NEGOTIABLE_RIDE_STATUSES,
    ACTIVE_RIDE_STATUSES,
    apply_driver_cancellation_reset,
    apply_ride_completion,
    assert_transition_allowed,
    ensure_offer_acceptance_allowed,
    ensure_verified_driver,
    sync_ride_offer_state,
)
from app.services.user_service import get_drivers_by_status, update_driver_status


MATCHING_MAX_DISTANCE_KM = 10.0
MATCHING_MAX_DRIVERS = 5
NEGOTIATION_TIMEOUT_SECONDS = 300


async def create_ride(
    session: AsyncSession,
    ride_request_in: RideRequestCreate,
    current_user: User,
) -> RideRequest:
    if current_user.role != UserRole.CLIENT:
        raise forbidden("Client access required")

    active_ride = await _get_active_client_ride(session, current_user.id)
    if active_ride is not None:
        if not await _expire_ride_if_needed(session, active_ride):
            raise conflict(
                "client_already_has_active_ride",
                "Client already has an active ride.",
            )

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

    await _notify_matching_drivers_for_ride(session, ride_request)
    return ride_request


async def mark_ride_as_offered(
    session: AsyncSession,
    ride_request_id: int,
) -> RideRequest:
    ride_request = await _get_ride_for_update(session, ride_request_id)
    if ride_request is None:
        raise not_found("Ride request not found")

    if await _expire_ride_if_needed(session, ride_request):
        return ride_request

    pending_offer_count = await _count_pending_offers(session, ride_request.id)
    if not sync_ride_offer_state(
        ride_request,
        pending_offer_count=pending_offer_count,
    ):
        return ride_request

    await session.commit()
    await session.refresh(ride_request)
    await _notify_client_status(ride_request)
    return ride_request


async def accept_offer(
    session: AsyncSession,
    offer_id: int,
    current_user: User,
) -> RideOffer:
    if current_user.role != UserRole.CLIENT:
        raise forbidden("Client access required")

    offer = await _get_offer_for_update(session, offer_id)
    if offer is None:
        raise not_found("Offer not found")

    ride_request = await _get_ride_for_update(session, offer.ride_request_id)
    if ride_request is None:
        raise not_found("Ride request not found")

    if ride_request.client_id != current_user.id:
        raise forbidden("Access denied")

    if await _expire_ride_if_needed(session, ride_request):
        raise conflict("offer_expired", "Offer has expired.")

    locked_offers = await _get_ride_offers_for_update(session, ride_request.id)
    selected_offer = next((item for item in locked_offers if item.id == offer_id), None)
    if selected_offer is None:
        raise not_found("Offer not found")
    if any(
        item.id != selected_offer.id and item.status == RideOfferStatus.ACCEPTED
        for item in locked_offers
    ):
        raise conflict("ride_already_assigned", "Ride already has a winning offer.")

    ensure_offer_acceptance_allowed(
        ride=ride_request,
        offer=selected_offer,
        driver_has_active_ride=await _driver_has_active_ride(
            session,
            selected_offer.driver_id,
            exclude_ride_id=ride_request.id,
        ),
        driver_is_verified=await _is_driver_verified(session, selected_offer.driver_id),
    )

    assert_transition_allowed(
        current_status=ride_request.status,
        target_status=RideRequestStatus.ACCEPTED,
    )

    now = datetime.utcnow()
    invalidated_driver_ids: list[int] = []
    for item in locked_offers:
        if item.id == selected_offer.id:
            item.status = RideOfferStatus.ACCEPTED
            item.responded_at = now
            continue
        if item.status == RideOfferStatus.PENDING:
            item.status = RideOfferStatus.INVALIDATED
            item.responded_at = now
            invalidated_driver_ids.append(item.driver_id)

    ride_request.driver_id = selected_offer.driver_id
    ride_request.agreed_price = money(selected_offer.proposed_price)
    ride_request.status = RideRequestStatus.ACCEPTED
    ride_request.final_price = None
    ride_request.platform_commission = None
    ride_request.driver_net_earnings = None
    await session.commit()
    await session.refresh(selected_offer)
    await session.refresh(ride_request)

    await update_driver_status(session, selected_offer.driver_id, DriverStatus.BUSY)
    selected_driver = await session.get(User, selected_offer.driver_id)
    client = await session.get(User, ride_request.client_id)

    await _notify_client_status(ride_request)
    await ride_notifier.send_offer_accepted_notification(
        driver_id=selected_offer.driver_id,
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
        selected_offer.driver_id,
        title="Offre acceptee",
        body=f"{client.phone_number if client is not None else 'Le client'} vous a choisi.",
        data={
            "type": "offer_accepted",
            "ride_id": ride_request.id,
            "target_role": UserRole.DRIVER.value,
        },
    )
    await notify_user(
        session,
        ride_request.client_id,
        title="Chauffeur confirme",
        body=(
            f"{selected_driver.name or selected_driver.phone_number} arrive vers vous."
            if selected_driver is not None
            else "Votre chauffeur arrive vers vous."
        ),
        data={
            "type": "ride_accepted",
            "ride_id": ride_request.id,
            "target_role": UserRole.CLIENT.value,
        },
    )
    for driver_id in invalidated_driver_ids:
        await ride_notifier.send_offer_rejected_notification(
            driver_id=driver_id,
            notification=OfferRejectedNotification(ride_id=ride_request.id),
        )
    await notify_users(
        session,
        invalidated_driver_ids,
        title="Offre non retenue",
        body="Le client a choisi une autre offre.",
        data={
            "type": "offer_invalidated",
            "ride_id": ride_request.id,
            "target_role": UserRole.DRIVER.value,
        },
    )
    return selected_offer


async def mark_arrived(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    ride_request = await _get_driver_assigned_ride(session, ride_request_id, current_user)
    assert_transition_allowed(
        current_status=ride_request.status,
        target_status=RideRequestStatus.ARRIVED,
    )

    ride_request.status = RideRequestStatus.ARRIVED
    await session.commit()
    await session.refresh(ride_request)
    await _notify_client_status(ride_request)
    await notify_user(
        session,
        ride_request.client_id,
        title="Chauffeur arrive",
        body="Votre chauffeur vous attend.",
        data={
            "type": "driver_arrived",
            "ride_id": ride_request.id,
            "target_role": UserRole.CLIENT.value,
        },
    )
    return ride_request


async def start_ride(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    ride_request = await _get_driver_assigned_ride(session, ride_request_id, current_user)
    assert_transition_allowed(
        current_status=ride_request.status,
        target_status=RideRequestStatus.STARTED,
    )

    ride_request.status = RideRequestStatus.STARTED
    await session.commit()
    await session.refresh(ride_request)
    await _notify_client_status(ride_request)
    await notify_user(
        session,
        ride_request.client_id,
        title="Course demarree",
        body="Bonne route.",
        data={
            "type": "ride_started",
            "ride_id": ride_request.id,
            "target_role": UserRole.CLIENT.value,
        },
    )
    return ride_request


async def complete_ride(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_complete_in: RideRequestComplete | None = None,
) -> RideRequest:
    ride_request = await _get_driver_assigned_ride(session, ride_request_id, current_user)
    if ride_request.status != RideRequestStatus.STARTED:
        raise conflict("ride_transition_not_allowed", "Ride is not started.")

    if ride_request_complete_in is not None and ride_request_complete_in.model_fields_set:
        raise conflict("price_locked", "Ride price is locked after offer acceptance.")

    apply_ride_completion(
        ride_request,
        commission_percent=await get_platform_commission_percent(session),
    )
    await session.commit()
    await session.refresh(ride_request)

    await update_driver_status(session, current_user.id, DriverStatus.ONLINE)
    await _notify_client_status(ride_request)
    await notify_user(
        session,
        ride_request.client_id,
        title="Course terminee",
        body="Merci d'avoir utilise Noor Express.",
        data={
            "type": "ride_completed",
            "ride_id": ride_request.id,
            "target_role": UserRole.CLIENT.value,
        },
    )
    await notify_user(
        session,
        current_user.id,
        title="Course terminee",
        body="Course terminee avec succes.",
        data={
            "type": "ride_completed",
            "ride_id": ride_request.id,
            "target_role": UserRole.DRIVER.value,
        },
    )
    return ride_request


async def cancel_by_client(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_cancel_in: RideRequestCancel,
) -> RideRequest:
    if current_user.role != UserRole.CLIENT:
        raise forbidden("Client access required")

    ride_request = await _get_ride_for_update(session, ride_request_id)
    if ride_request is None:
        raise not_found("Ride request not found")
    if ride_request.client_id != current_user.id:
        raise forbidden("Access denied")

    if await _expire_ride_if_needed(session, ride_request):
        raise conflict("ride_already_expired", "Ride has already expired.")

    if ride_request.status not in {
        RideRequestStatus.PENDING,
        RideRequestStatus.OFFERED,
        RideRequestStatus.ACCEPTED,
    }:
        raise conflict(
            "ride_cancellation_not_allowed",
            "Client cannot cancel this ride at the current status.",
        )

    locked_offers = await _get_ride_offers_for_update(session, ride_request.id)
    invalidated_driver_ids = _invalidate_pending_offers(locked_offers)

    ride_request.status = RideRequestStatus.CANCELLED
    ride_request.cancellation_reason = ride_request_cancel_in.reason
    ride_request.cancelled_by_role = current_user.role
    await session.commit()
    await session.refresh(ride_request)

    if ride_request.driver_id is not None:
        await update_driver_status(session, ride_request.driver_id, DriverStatus.ONLINE)
        await ride_notifier.send_ride_status_notification_to_driver(
            driver_id=ride_request.driver_id,
            notification=RideStatusNotification(
                ride_request_id=ride_request.id,
                status=ride_request.status.value,
            ),
        )
        await notify_user(
            session,
            ride_request.driver_id,
            title="Course annulee",
            body="Le client a annule la course.",
            data={
                "type": "ride_cancelled",
                "ride_id": ride_request.id,
                "target_role": UserRole.DRIVER.value,
            },
        )

    for driver_id in invalidated_driver_ids:
        await ride_notifier.send_offer_rejected_notification(
            driver_id=driver_id,
            notification=OfferRejectedNotification(ride_id=ride_request.id),
        )
    return ride_request


async def cancel_by_driver(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    _ride_request_cancel_in: RideRequestCancel,
) -> RideRequest:
    ride_request = await _get_driver_assigned_ride(session, ride_request_id, current_user)

    if ride_request.status == RideRequestStatus.STARTED:
        raise conflict(
            "driver_cannot_cancel_started_ride",
            "Driver cannot cancel a started ride.",
        )
    if ride_request.status not in {
        RideRequestStatus.ACCEPTED,
        RideRequestStatus.ARRIVED,
    }:
        raise conflict(
            "ride_cancellation_not_allowed",
            "Driver cancellation is not allowed at the current status.",
        )

    locked_offers = await _get_ride_offers_for_update(session, ride_request.id)
    accepted_offer = next(
        (
            item
            for item in locked_offers
            if item.driver_id == current_user.id and item.status == RideOfferStatus.ACCEPTED
        ),
        None,
    )
    apply_driver_cancellation_reset(ride_request, accepted_offer=accepted_offer)
    await session.commit()
    await session.refresh(ride_request)

    await update_driver_status(session, current_user.id, DriverStatus.ONLINE)
    await _notify_client_status(ride_request)
    await notify_user(
        session,
        ride_request.client_id,
        title="Chauffeur indisponible",
        body="Le chauffeur a annule. La course redevient negociable.",
        data={
            "type": "ride_reopened",
            "ride_id": ride_request.id,
            "target_role": UserRole.CLIENT.value,
        },
    )
    await _notify_matching_drivers_for_ride(session, ride_request)
    return ride_request


async def expire_ride(
    session: AsyncSession,
    ride_request_id: int,
) -> RideRequest | None:
    ride_request = await _get_ride_for_update(session, ride_request_id)
    if ride_request is None:
        return None

    await _expire_ride_if_needed(session, ride_request)
    return ride_request


async def _expire_ride_if_needed(
    session: AsyncSession,
    ride_request: RideRequest,
) -> bool:
    if ride_request.status not in NEGOTIABLE_RIDE_STATUSES:
        return False
    if not _is_ride_negotiation_expired(ride_request):
        return False

    locked_offers = await _get_ride_offers_for_update(session, ride_request.id)
    expired_driver_ids = _expire_pending_offers(locked_offers)
    assert_transition_allowed(
        current_status=ride_request.status,
        target_status=RideRequestStatus.EXPIRED,
    )
    ride_request.status = RideRequestStatus.EXPIRED
    await session.commit()
    await session.refresh(ride_request)

    await _notify_client_status(ride_request)
    for driver_id in expired_driver_ids:
        await ride_notifier.send_offer_rejected_notification(
            driver_id=driver_id,
            notification=OfferRejectedNotification(ride_id=ride_request.id),
        )
    return True


async def _notify_matching_drivers_for_ride(
    session: AsyncSession,
    ride_request: RideRequest,
) -> None:
    matching_drivers = await _get_matching_drivers_for_ride(
        session,
        ride_request,
        ride_request.pickup_latitude,
        ride_request.pickup_longitude,
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
                client_price=float(ride_request.estimated_price),
                distance_km=nearby_driver.distance_km,
            ),
        )
        await notify_user(
            session,
            nearby_driver.driver_id,
            title="Nouvelle course",
            body=(
                f"{ride_request.pickup_location} -> {ride_request.dropoff_location} - "
                f"{float(ride_request.estimated_price):.0f} FCFA"
            ),
            data={
                "type": "new_ride_request",
                "ride_id": ride_request.id,
                "target_role": UserRole.DRIVER.value,
            },
        )


async def _notify_client_status(ride_request: RideRequest) -> None:
    await ride_notifier.send_ride_status_notification(
        client_id=ride_request.client_id,
        notification=RideStatusNotification(
            ride_request_id=ride_request.id,
            status=ride_request.status.value,
        ),
    )


async def _get_active_client_ride(
    session: AsyncSession,
    client_id: int,
) -> RideRequest | None:
    result = await session.execute(
        select(RideRequest)
        .where(
            RideRequest.client_id == client_id,
            RideRequest.status.in_(CLIENT_ACTIVE_RIDE_STATUSES),
        )
        .order_by(RideRequest.created_at.desc(), RideRequest.id.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _driver_has_active_ride(
    session: AsyncSession,
    driver_id: int,
    *,
    exclude_ride_id: int | None = None,
) -> bool:
    query = select(RideRequest.id).where(
        RideRequest.driver_id == driver_id,
        RideRequest.status.in_(DRIVER_ACTIVE_RIDE_STATUSES),
    )
    if exclude_ride_id is not None:
        query = query.where(RideRequest.id != exclude_ride_id)

    result = await session.execute(query.limit(1))
    return result.scalar_one_or_none() is not None


async def _get_ride_for_update(
    session: AsyncSession,
    ride_request_id: int,
) -> RideRequest | None:
    result = await session.execute(
        select(RideRequest)
        .where(RideRequest.id == ride_request_id)
        .with_for_update()
    )
    return result.scalar_one_or_none()


async def _get_offer_for_update(
    session: AsyncSession,
    offer_id: int,
) -> RideOffer | None:
    result = await session.execute(
        select(RideOffer).where(RideOffer.id == offer_id).with_for_update()
    )
    return result.scalar_one_or_none()


async def _get_ride_offers_for_update(
    session: AsyncSession,
    ride_request_id: int,
) -> list[RideOffer]:
    result = await session.execute(
        select(RideOffer)
        .where(RideOffer.ride_request_id == ride_request_id)
        .order_by(RideOffer.created_at.asc(), RideOffer.id.asc())
        .with_for_update()
    )
    return list(result.scalars().all())


async def _get_driver_assigned_ride(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    if current_user.role != UserRole.DRIVER:
        raise forbidden("Driver access required")
    ensure_verified_driver(is_verified=await _is_driver_verified(session, current_user.id))

    ride_request = await _get_ride_for_update(session, ride_request_id)
    if ride_request is None:
        raise not_found("Ride request not found")
    if ride_request.driver_id != current_user.id:
        raise forbidden("Driver is not assigned to this ride.")
    return ride_request


async def _is_driver_verified(
    session: AsyncSession,
    driver_id: int,
) -> bool:
    result = await session.execute(
        select(DriverProfile.verification_status).where(DriverProfile.user_id == driver_id)
    )
    status_value = result.scalar_one_or_none()
    return status_value == DriverVerificationStatus.VERIFIED


async def _count_pending_offers(
    session: AsyncSession,
    ride_request_id: int,
) -> int:
    result = await session.execute(
        select(RideOffer)
        .where(
            RideOffer.ride_request_id == ride_request_id,
            RideOffer.status == RideOfferStatus.PENDING,
        )
    )
    return len(list(result.scalars().all()))


async def _get_offer_driver_ids(
    session: AsyncSession,
    ride_request_id: int,
) -> set[int]:
    result = await session.execute(
        select(RideOffer.driver_id).where(RideOffer.ride_request_id == ride_request_id)
    )
    return set(result.scalars().all())


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
    latitude: float | None,
    longitude: float | None,
) -> list[NearbyDriverLocation]:
    if latitude is None or longitude is None:
        return []

    nearby_drivers = await driver_locator.get_nearby_drivers(
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
    verified_driver_ids = {
        driver.id
        for driver in online_drivers
        if await _is_driver_verified(session, driver.id)
    }
    rejected_driver_ids = await _get_rejected_driver_ids(session, ride_request.id)
    existing_offer_driver_ids = await _get_offer_driver_ids(session, ride_request.id)

    return [
        driver
        for driver in nearby_drivers
        if driver.driver_id in verified_driver_ids
        and driver.driver_id not in rejected_driver_ids
        and driver.driver_id not in existing_offer_driver_ids
    ][:MATCHING_MAX_DRIVERS]


def _is_ride_negotiation_expired(ride_request: RideRequest) -> bool:
    return datetime.utcnow() >= ride_request.created_at + timedelta(
        seconds=NEGOTIATION_TIMEOUT_SECONDS
    )


def _invalidate_pending_offers(offers: list[RideOffer]) -> list[int]:
    now = datetime.utcnow()
    invalidated_driver_ids: list[int] = []
    for offer in offers:
        if offer.status != RideOfferStatus.PENDING:
            continue
        offer.status = RideOfferStatus.INVALIDATED
        offer.responded_at = now
        invalidated_driver_ids.append(offer.driver_id)
    return invalidated_driver_ids


def _expire_pending_offers(offers: list[RideOffer]) -> list[int]:
    now = datetime.utcnow()
    expired_driver_ids: list[int] = []
    for offer in offers:
        if offer.status != RideOfferStatus.PENDING:
            continue
        offer.status = RideOfferStatus.EXPIRED
        offer.responded_at = now
        expired_driver_ids.append(offer.driver_id)
    return expired_driver_ids
