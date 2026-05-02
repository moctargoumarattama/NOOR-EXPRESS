from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import ApiError, conflict, forbidden, not_found
from app.core.firebase import notify_user, notify_users
from app.models.driver_profile import DriverProfile, DriverVerificationStatus
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_report import RideReport, RideReportReason
from app.models.ride_request import (
    RideCancelledByRole,
    RideRequest,
    RideRequestStatus,
)
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
    round_price_step_down,
    round_price_step_up,
)
from app.services.routing_service import get_route_payload
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
from app.services.user_service import (
    ensure_user_not_suspended,
    get_drivers_by_status,
    update_driver_status,
)
from app.services.wallet_service import (
    invalidate_driver_dashboard_stats_cache,
    sync_completed_ride_to_wallet,
)

MATCHING_RADIUS_STEPS_KM = (3.0, 5.0, 10.0)
MATCHING_MIN_DRIVER_COUNT = 3
MATCHING_MAX_DISTANCE_KM = MATCHING_RADIUS_STEPS_KM[-1]
MATCHING_MAX_DRIVERS = 5
NEGOTIATION_TIMEOUT_SECONDS = 300
ESTIMATE_CACHE_TTL_SECONDS = 60
CANCELLATION_WINDOW_DURATION = timedelta(hours=24)
PASSENGER_BLOCK_DURATION = timedelta(hours=2)
CANCELLATION_WARNING_THRESHOLD = 3
CANCELLATION_BLOCK_THRESHOLD = 5
PASSENGER_BLOCK_ERROR_CODE = "ride_request_temporarily_blocked"
DEFAULT_DRIVER_MAX_RADIUS_KM = 5
MIN_DRIVER_MAX_RADIUS_KM = 1
MAX_DRIVER_MAX_RADIUS_KM = 10
DRIVER_PAUSE_TIMEOUT = timedelta(minutes=30)

PASSENGER_CANCELLATION_REASON_LABELS = {
    "other_transport": "J'ai trouve un autre moyen de transport",
    "driver_too_slow": "Le chauffeur met trop de temps",
    "wrong_destination": "J'ai fait une erreur de destination",
    "other": "Autre",
}
DRIVER_CANCELLATION_REASON_LABELS = {
    "passenger_no_answer": "Le passager ne repond pas",
    "passenger_not_found": "Le passager est introuvable",
    "vehicle_issue": "Probleme avec mon vehicule",
    "other": "Autre",
}

_estimate_cache: dict[str, tuple[datetime, dict]] = {}


async def create_ride(
    session: AsyncSession,
    ride_request_in: RideRequestCreate,
    current_user: User,
) -> RideRequest:
    if current_user.role != UserRole.CLIENT:
        raise forbidden("Client access required")
    await ensure_user_not_suspended(session, current_user)
    _ensure_passenger_not_temporarily_blocked(current_user, now=datetime.utcnow())

    active_ride = await _get_active_client_ride(session, current_user.id)
    if active_ride is not None:
        if not await _expire_ride_if_needed(session, active_ride):
            raise conflict(
                "client_already_has_active_ride",
                "Client already has an active ride.",
            )

    route_payload = await get_route_payload(
        ride_request_in.client_latitude,
        ride_request_in.client_longitude,
        ride_request_in.dropoff_latitude,
        ride_request_in.dropoff_longitude,
    )
    estimated_price = ride_request_in.estimated_price
    if estimated_price is None:
        pricing_estimate = await calculate_ride_price(
            session,
            pickup_latitude=ride_request_in.client_latitude,
            pickup_longitude=ride_request_in.client_longitude,
            dropoff_latitude=ride_request_in.dropoff_latitude,
            dropoff_longitude=ride_request_in.dropoff_longitude,
            distance_km=route_payload["distance_km"],
            estimated_duration_minutes=route_payload["duration_min"],
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
        distance_km=route_payload["distance_km"],
        duration_minutes=route_payload["duration_min"],
        estimated_price=money(estimated_price),
        status=RideRequestStatus.PENDING,
    )
    session.add(ride_request)
    await session.commit()
    await session.refresh(ride_request)

    await _notify_matching_drivers_for_ride(session, ride_request)
    return ride_request


async def estimate_ride_preview(
    session: AsyncSession,
    *,
    pickup_latitude: float,
    pickup_longitude: float,
    dropoff_latitude: float,
    dropoff_longitude: float,
) -> dict:
    cache_key = _estimate_cache_key(
        pickup_latitude,
        pickup_longitude,
        dropoff_latitude,
        dropoff_longitude,
    )
    cached_payload = _read_estimate_cache(cache_key)
    if cached_payload is not None:
        return cached_payload

    route_payload = await get_route_payload(
        pickup_latitude,
        pickup_longitude,
        dropoff_latitude,
        dropoff_longitude,
    )
    pricing_estimate = await calculate_ride_price(
        session,
        pickup_latitude=pickup_latitude,
        pickup_longitude=pickup_longitude,
        dropoff_latitude=dropoff_latitude,
        dropoff_longitude=dropoff_longitude,
        distance_km=route_payload["distance_km"],
        estimated_duration_minutes=route_payload["duration_min"],
    )
    available_drivers, search_radius_km = await _get_progressive_available_nearby_drivers(
        session,
        latitude=pickup_latitude,
        longitude=pickup_longitude,
    )
    payload = _build_estimate_preview_payload(
        pricing_estimate,
        route_payload,
        available_drivers_count=len(available_drivers),
        search_radius_km=search_radius_km,
    )
    _write_estimate_cache(cache_key, payload)
    return payload


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
    await ensure_user_not_suspended(session, current_user)

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

    await update_driver_status(
        session,
        selected_offer.driver_id,
        DriverStatus.ONLINE,
        is_available=False,
    )
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
    ride_request = await _get_driver_assigned_ride(
        session, ride_request_id, current_user
    )
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
    ride_request = await _get_driver_assigned_ride(
        session, ride_request_id, current_user
    )
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
    ride_request = await _get_driver_assigned_ride(
        session, ride_request_id, current_user
    )
    if ride_request.status != RideRequestStatus.STARTED:
        raise conflict("ride_transition_not_allowed", "Ride is not started.")

    if (
        ride_request_complete_in is not None
        and ride_request_complete_in.model_fields_set
    ):
        raise conflict("price_locked", "Ride price is locked after offer acceptance.")

    apply_ride_completion(
        ride_request,
        commission_percent=await get_platform_commission_percent(session),
    )
    ride_request.completed_at = datetime.utcnow()
    _invalidate_share_token(ride_request)
    await sync_completed_ride_to_wallet(session, ride_request)
    await session.commit()
    await session.refresh(ride_request)
    invalidate_driver_dashboard_stats_cache(current_user.id)

    await update_driver_status(
        session,
        current_user.id,
        DriverStatus.ONLINE,
        is_available=True,
    )
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

    now = datetime.utcnow()
    cancellation_reason = _build_passenger_cancellation_reason(
        ride_request_cancel_in,
        cancellations_today=max(0, int(current_user.cancellations_today or 0)),
    )
    locked_offers = await _get_ride_offers_for_update(session, ride_request.id)
    invalidated_driver_ids = _invalidate_pending_offers(locked_offers)
    _, cancellations_last_24h = _register_user_cancellation_event(
        current_user,
        now=now,
    )
    if cancellations_last_24h >= CANCELLATION_BLOCK_THRESHOLD:
        block_until = now + PASSENGER_BLOCK_DURATION
        current_block = current_user.ride_request_blocked_until
        if current_block is None or current_block < block_until:
            current_user.ride_request_blocked_until = block_until

    ride_request.status = RideRequestStatus.CANCELLED
    ride_request.cancellation_reason = cancellation_reason
    ride_request.cancelled_by_role = RideCancelledByRole.PASSENGER
    _invalidate_share_token(ride_request)
    await session.commit()
    await session.refresh(ride_request)

    if ride_request.driver_id is not None:
        await update_driver_status(
            session,
            ride_request.driver_id,
            DriverStatus.ONLINE,
            is_available=True,
        )
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
    await _notify_passenger_cancellation_policy(
        session,
        current_user,
        cancellations_last_24h=cancellations_last_24h,
    )
    return ride_request


async def cancel_by_driver(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    ride_request_cancel_in: RideRequestCancel,
) -> RideRequest:
    ride_request = await _get_driver_assigned_ride(
        session, ride_request_id, current_user
    )

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
            if item.driver_id == current_user.id
            and item.status == RideOfferStatus.ACCEPTED
        ),
        None,
    )
    cancellation_reason = _build_driver_cancellation_reason(ride_request_cancel_in)
    now = datetime.utcnow()
    _, cancellations_last_24h = _register_user_cancellation_event(
        current_user,
        now=now,
    )
    if cancellations_last_24h == CANCELLATION_BLOCK_THRESHOLD:
        session.add(
            RideReport(
                ride_request_id=ride_request.id,
                reported_by_id=current_user.id,
                reason=RideReportReason.AUTRE,
                description=(
                    "Signalement automatique: 5 annulations chauffeur en 24h. "
                    f"Derniere raison: {cancellation_reason}."
                ),
            )
        )

    apply_driver_cancellation_reset(ride_request, accepted_offer=accepted_offer)
    await session.commit()
    await session.refresh(ride_request)

    await update_driver_status(
        session,
        current_user.id,
        DriverStatus.ONLINE,
        is_available=True,
    )
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
    await _notify_driver_cancellation_policy(
        session,
        current_user,
        cancellations_last_24h=cancellations_last_24h,
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
    _invalidate_share_token(ride_request)
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
        select(RideRequest).where(RideRequest.id == ride_request_id).with_for_update()
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
    ensure_verified_driver(
        is_verified=await _is_driver_verified(session, current_user.id)
    )

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
        select(DriverProfile.verification_status).where(
            DriverProfile.user_id == driver_id
        )
    )
    status_value = result.scalar_one_or_none()
    return status_value == DriverVerificationStatus.VERIFIED


async def _count_pending_offers(
    session: AsyncSession,
    ride_request_id: int,
) -> int:
    result = await session.execute(
        select(RideOffer).where(
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

    nearby_drivers, _ = await _get_progressive_available_nearby_drivers(
        session,
        latitude=latitude,
        longitude=longitude,
    )
    rejected_driver_ids = await _get_rejected_driver_ids(session, ride_request.id)
    existing_offer_driver_ids = await _get_offer_driver_ids(session, ride_request.id)

    return [
        driver
        for driver in nearby_drivers
        if driver.driver_id not in rejected_driver_ids
        and driver.driver_id not in existing_offer_driver_ids
    ][:MATCHING_MAX_DRIVERS]


def _ensure_passenger_not_temporarily_blocked(user: User, *, now: datetime) -> None:
    blocked_until = user.ride_request_blocked_until
    if blocked_until is None:
        return
    if blocked_until <= now:
        user.ride_request_blocked_until = None
        return

    remaining_seconds = int((blocked_until - now).total_seconds())
    raise ApiError(
        status_code=403,
        code=PASSENGER_BLOCK_ERROR_CODE,
        message=(
            "Blocage temporaire actif. Nouvelle demande possible dans "
            f"{_format_wait_duration(remaining_seconds)}."
        ),
    )


def _build_passenger_cancellation_reason(
    payload: RideRequestCancel,
    *,
    cancellations_today: int,
) -> str | None:
    return _build_cancellation_reason(
        payload=payload,
        reason_labels=PASSENGER_CANCELLATION_REASON_LABELS,
        reason_required=cancellations_today >= 1,
        required_error_code="passenger_cancellation_reason_required",
        required_error_message=(
            "A partir de la deuxieme annulation quotidienne, une raison est obligatoire."
        ),
        invalid_error_code="passenger_cancellation_reason_invalid",
        invalid_error_message="Code de raison passager invalide.",
        other_requires_text=True,
    )


def _build_driver_cancellation_reason(payload: RideRequestCancel) -> str:
    reason = _build_cancellation_reason(
        payload=payload,
        reason_labels=DRIVER_CANCELLATION_REASON_LABELS,
        reason_required=True,
        required_error_code="driver_cancellation_reason_required",
        required_error_message="Le chauffeur doit indiquer une raison d'annulation.",
        invalid_error_code="driver_cancellation_reason_invalid",
        invalid_error_message="Code de raison chauffeur invalide.",
        other_requires_text=True,
    )
    if reason is None:
        raise ApiError(
            status_code=422,
            code="driver_cancellation_reason_required",
            message="Le chauffeur doit indiquer une raison d'annulation.",
        )
    return reason


def _build_cancellation_reason(
    *,
    payload: RideRequestCancel,
    reason_labels: dict[str, str],
    reason_required: bool,
    required_error_code: str,
    required_error_message: str,
    invalid_error_code: str,
    invalid_error_message: str,
    other_requires_text: bool,
) -> str | None:
    reason_code = (payload.reason_code or "").strip().lower() or None
    reason_detail = (payload.reason or "").strip() or None

    if reason_required and reason_code is None:
        raise ApiError(
            status_code=422,
            code=required_error_code,
            message=required_error_message,
        )

    if reason_code is None:
        return reason_detail

    reason_label = reason_labels.get(reason_code)
    if reason_label is None:
        raise ApiError(
            status_code=422,
            code=invalid_error_code,
            message=invalid_error_message,
        )

    if reason_code == "other":
        if other_requires_text and reason_detail is None:
            raise ApiError(
                status_code=422,
                code=required_error_code,
                message="Le motif 'Autre' exige un commentaire.",
            )
        return reason_detail or reason_label

    if reason_detail is None:
        return reason_label
    return f"{reason_label}: {reason_detail}"


def _register_user_cancellation_event(
    user: User,
    *,
    now: datetime,
) -> tuple[int, int]:
    _sync_cancellation_window(user, now=now)
    user.cancellations_today = max(0, int(user.cancellations_today or 0)) + 1
    user.cancellations_last_24h = max(0, int(user.cancellations_last_24h or 0)) + 1
    return user.cancellations_today, user.cancellations_last_24h


def _sync_cancellation_window(user: User, *, now: datetime) -> None:
    started_at = user.cancellation_window_started_at
    if started_at is None or now - started_at >= CANCELLATION_WINDOW_DURATION:
        user.cancellations_last_24h = 0
        user.cancellation_window_started_at = now

    if (
        user.ride_request_blocked_until is not None
        and user.ride_request_blocked_until <= now
    ):
        user.ride_request_blocked_until = None


def _format_wait_duration(total_seconds: int) -> str:
    minutes = max(1, (max(0, total_seconds) + 59) // 60)
    hours, remaining_minutes = divmod(minutes, 60)
    if hours > 0 and remaining_minutes > 0:
        return f"{hours} h {remaining_minutes:02d} min"
    if hours > 0:
        return f"{hours} h"
    return f"{remaining_minutes} min"


async def _notify_passenger_cancellation_policy(
    session: AsyncSession,
    user: User,
    *,
    cancellations_last_24h: int,
) -> None:
    if cancellations_last_24h < CANCELLATION_WARNING_THRESHOLD:
        return

    if cancellations_last_24h >= CANCELLATION_BLOCK_THRESHOLD:
        blocked_until = user.ride_request_blocked_until
        wait_message = ""
        if blocked_until is not None:
            wait_seconds = int((blocked_until - datetime.utcnow()).total_seconds())
            if wait_seconds > 0:
                wait_message = (
                    f" Nouvelle demande possible dans {_format_wait_duration(wait_seconds)}."
                )
        await notify_user(
            session,
            user.id,
            title="Blocage temporaire active",
            body=(
                "Vous avez effectue au moins 5 annulations en 24h. "
                f"Les nouvelles demandes sont temporairement bloquees.{wait_message}"
            ),
            data={
                "type": "ride_cancellation_policy_block",
                "target_role": UserRole.CLIENT.value,
                "cancellations_24h": cancellations_last_24h,
            },
        )
        return

    await notify_user(
        session,
        user.id,
        title="Avertissement annulations",
        body=(
            "Vous avez effectue plusieurs annulations en 24h. "
            "Merci de confirmer vos demandes avant de lancer une course."
        ),
        data={
            "type": "ride_cancellation_policy_warning",
            "target_role": UserRole.CLIENT.value,
            "cancellations_24h": cancellations_last_24h,
        },
    )


async def _notify_driver_cancellation_policy(
    session: AsyncSession,
    user: User,
    *,
    cancellations_last_24h: int,
) -> None:
    if cancellations_last_24h < CANCELLATION_WARNING_THRESHOLD:
        return

    if cancellations_last_24h >= CANCELLATION_BLOCK_THRESHOLD:
        await notify_user(
            session,
            user.id,
            title="Signalement automatique declenche",
            body=(
                "Vous avez atteint 5 annulations chauffeur en 24h. "
                "Un signalement admin a ete cree automatiquement."
            ),
            data={
                "type": "driver_cancellation_auto_report",
                "target_role": UserRole.DRIVER.value,
                "cancellations_24h": cancellations_last_24h,
            },
        )
        return

    await notify_user(
        session,
        user.id,
        title="Avertissement annulations",
        body=(
            "Vous avez effectue plusieurs annulations en 24h. "
            "Merci de confirmer la disponibilite avant d'accepter une course."
        ),
        data={
            "type": "driver_cancellation_warning",
            "target_role": UserRole.DRIVER.value,
            "cancellations_24h": cancellations_last_24h,
        },
    )


def _is_ride_negotiation_expired(ride_request: RideRequest) -> bool:
    return datetime.utcnow() >= ride_request.created_at + timedelta(
        seconds=NEGOTIATION_TIMEOUT_SECONDS
    )


def _build_estimate_preview_payload(
    pricing_estimate: dict,
    route_payload: dict,
    *,
    available_drivers_count: int,
    search_radius_km: float,
) -> dict:
    estimated_price = round(
        float(
            pricing_estimate.get(
                "final_estimated_price",
                pricing_estimate["estimated_price"],
            )
        ),
        2,
    )
    min_price, max_price = _price_range_from_estimate(estimated_price)
    payload = dict(pricing_estimate)
    payload.update(
        {
            "estimated_price": estimated_price,
            "distance_km": round(float(route_payload["distance_km"]), 3),
            "duration_min": int(route_payload["duration_min"]),
            "min_price": min_price,
            "max_price": max_price,
            "available_drivers_count": available_drivers_count,
            "search_radius_km": search_radius_km,
        }
    )
    return payload


async def _get_progressive_available_nearby_drivers(
    session: AsyncSession,
    *,
    latitude: float,
    longitude: float,
) -> tuple[list[NearbyDriverLocation], float]:
    selected_radius = MATCHING_MAX_DISTANCE_KM
    selected_drivers: list[NearbyDriverLocation] = []
    for radius_km in MATCHING_RADIUS_STEPS_KM:
        selected_radius = radius_km
        selected_drivers = await _get_available_verified_nearby_drivers(
            session,
            latitude=latitude,
            longitude=longitude,
            max_distance_km=radius_km,
        )
        if len(selected_drivers) >= MATCHING_MIN_DRIVER_COUNT:
            break
    return selected_drivers, selected_radius


async def _get_available_verified_nearby_drivers(
    session: AsyncSession,
    *,
    latitude: float,
    longitude: float,
    max_distance_km: float,
) -> list[NearbyDriverLocation]:
    nearby_drivers = await driver_locator.get_nearby_drivers(
        latitude=latitude,
        longitude=longitude,
        max_distance_km=max_distance_km,
    )
    if not nearby_drivers:
        return []

    nearby_driver_ids = [driver.driver_id for driver in nearby_drivers]
    online_drivers = await get_drivers_by_status(
        session,
        nearby_driver_ids,
        DriverStatus.ONLINE,
        is_available=True,
    )
    expired_paused_drivers = await _promote_expired_paused_drivers(
        session,
        driver_ids=nearby_driver_ids,
    )
    if expired_paused_drivers:
        online_drivers_by_id = {driver.id: driver for driver in online_drivers}
        for promoted_driver in expired_paused_drivers:
            online_drivers_by_id[promoted_driver.id] = promoted_driver
        online_drivers = list(online_drivers_by_id.values())
    if not online_drivers:
        return []

    online_drivers_by_id = {driver.id: driver for driver in online_drivers}
    verified_driver_ids = {
        driver.id
        for driver in online_drivers
        if await _is_driver_verified(session, driver.id)
    }
    filtered_drivers: list[NearbyDriverLocation] = []
    for driver in nearby_drivers:
        if driver.driver_id not in verified_driver_ids:
            continue
        online_driver = online_drivers_by_id.get(driver.driver_id)
        if online_driver is None:
            continue
        if driver.distance_km > _normalized_driver_max_radius_km(online_driver):
            continue
        filtered_drivers.append(driver)
    return filtered_drivers


def _normalized_driver_max_radius_km(driver: User) -> float:
    value = getattr(driver, "max_radius_km", None)
    if value is None:
        return float(DEFAULT_DRIVER_MAX_RADIUS_KM)
    radius = int(value)
    if radius < MIN_DRIVER_MAX_RADIUS_KM:
        return float(MIN_DRIVER_MAX_RADIUS_KM)
    if radius > MAX_DRIVER_MAX_RADIUS_KM:
        return float(MAX_DRIVER_MAX_RADIUS_KM)
    return float(radius)


async def _promote_expired_paused_drivers(
    session: AsyncSession,
    *,
    driver_ids: list[int],
) -> list[User]:
    if not driver_ids:
        return []

    paused_drivers = await get_drivers_by_status(
        session,
        driver_ids,
        DriverStatus.PAUSED,
    )
    if not paused_drivers:
        return []

    now = datetime.utcnow()
    promoted_drivers: list[User] = []
    for paused_driver in paused_drivers:
        if not _is_pause_expired(paused_driver, now=now):
            continue
        promoted = await update_driver_status(
            session,
            paused_driver.id,
            DriverStatus.ONLINE,
            is_available=True,
        )
        if promoted is not None:
            promoted_drivers.append(promoted)
    return promoted_drivers


def _is_pause_expired(driver: User, *, now: datetime) -> bool:
    pause_started_at = getattr(driver, "pause_started_at", None)
    if pause_started_at is None:
        return False
    return now - pause_started_at >= DRIVER_PAUSE_TIMEOUT


def _price_range_from_estimate(estimated_price: float) -> tuple[float, float]:
    return (
        round_price_step_down(estimated_price * 0.9),
        round_price_step_up(estimated_price * 1.1),
    )


def _estimate_cache_key(
    pickup_latitude: float,
    pickup_longitude: float,
    dropoff_latitude: float,
    dropoff_longitude: float,
) -> str:
    return (
        f"{round(pickup_latitude, 5)},{round(pickup_longitude, 5)}:"
        f"{round(dropoff_latitude, 5)},{round(dropoff_longitude, 5)}"
    )


def _invalidate_share_token(ride_request: RideRequest) -> None:
    ride_request.share_token = None
    ride_request.share_token_created_at = None


def _read_estimate_cache(key: str) -> dict | None:
    cached_payload = _estimate_cache.get(key)
    if cached_payload is None:
        return None
    expires_at, payload = cached_payload
    if datetime.utcnow() >= expires_at:
        _estimate_cache.pop(key, None)
        return None
    return payload


def _write_estimate_cache(key: str, payload: dict) -> None:
    _estimate_cache[key] = (
        datetime.utcnow() + timedelta(seconds=ESTIMATE_CACHE_TTL_SECONDS),
        payload,
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
