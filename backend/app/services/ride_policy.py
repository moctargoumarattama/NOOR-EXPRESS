from __future__ import annotations

from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP

from app.core.api_errors import ApiError, conflict
from app.core.messages import Messages
from app.models.ride_offer import RideOffer, RideOfferStatus
from app.models.ride_request import RideRequest, RideRequestStatus


ACTIVE_RIDE_STATUSES = (
    RideRequestStatus.PENDING,
    RideRequestStatus.OFFERED,
    RideRequestStatus.ACCEPTED,
    RideRequestStatus.ARRIVED,
    RideRequestStatus.STARTED,
)
CORE_RIDE_FLOW_STATUSES = (
    RideRequestStatus.PENDING,
    RideRequestStatus.OFFERED,
    RideRequestStatus.ACCEPTED,
    RideRequestStatus.ARRIVED,
    RideRequestStatus.STARTED,
    RideRequestStatus.COMPLETED,
)
CLIENT_ACTIVE_RIDE_STATUSES = ACTIVE_RIDE_STATUSES
DRIVER_ACTIVE_RIDE_STATUSES = (
    RideRequestStatus.ACCEPTED,
    RideRequestStatus.ARRIVED,
    RideRequestStatus.STARTED,
)
NEGOTIABLE_RIDE_STATUSES = (
    RideRequestStatus.PENDING,
    RideRequestStatus.OFFERED,
)
TERMINAL_RIDE_STATUSES = (
    RideRequestStatus.COMPLETED,
    RideRequestStatus.CANCELLED,
    RideRequestStatus.EXPIRED,
)
PENDING_OFFER_STATUSES = (RideOfferStatus.PENDING,)
RESOLVED_OFFER_STATUSES = (
    RideOfferStatus.ACCEPTED,
    RideOfferStatus.REJECTED,
    RideOfferStatus.INVALIDATED,
    RideOfferStatus.EXPIRED,
)

# Keep the primary ride journey linear and predictable:
# client request -> offers -> accepted -> arrived -> started -> completed.
# Limited exceptions such as cancellation or expiration must stay explicit.
_ALLOWED_TRANSITIONS: dict[RideRequestStatus, set[RideRequestStatus]] = {
    RideRequestStatus.PENDING: {
        RideRequestStatus.OFFERED,
        RideRequestStatus.CANCELLED,
        RideRequestStatus.EXPIRED,
    },
    RideRequestStatus.OFFERED: {
        RideRequestStatus.ACCEPTED,
        RideRequestStatus.PENDING,
        RideRequestStatus.CANCELLED,
        RideRequestStatus.EXPIRED,
    },
    RideRequestStatus.ACCEPTED: {
        RideRequestStatus.ARRIVED,
        RideRequestStatus.CANCELLED,
    },
    RideRequestStatus.ARRIVED: {
        RideRequestStatus.STARTED,
    },
    RideRequestStatus.STARTED: {
        RideRequestStatus.COMPLETED,
    },
    RideRequestStatus.COMPLETED: set(),
    RideRequestStatus.CANCELLED: set(),
    RideRequestStatus.EXPIRED: set(),
}


def assert_transition_allowed(
    *,
    current_status: RideRequestStatus,
    target_status: RideRequestStatus,
) -> None:
    if target_status not in _ALLOWED_TRANSITIONS.get(current_status, set()):
        raise conflict(
            "ride_transition_not_allowed",
            Messages.RIDE_TRANSITION_NOT_ALLOWED,
        )


def ensure_verified_driver(*, is_verified: bool) -> None:
    if is_verified:
        return

    raise ApiError(
        status_code=403,
        code="driver_not_verified",
        message=Messages.DRIVER_NOT_VERIFIED,
    )


def ensure_offer_acceptance_allowed(
    *,
    ride: RideRequest,
    offer: RideOffer,
    driver_has_active_ride: bool,
    driver_is_verified: bool,
) -> None:
    ensure_verified_driver(is_verified=driver_is_verified)

    if offer.status == RideOfferStatus.EXPIRED:
        raise conflict("offer_expired", Messages.OFFER_EXPIRED)

    if offer.status != RideOfferStatus.PENDING:
        raise conflict("offer_already_resolved", Messages.OFFER_ALREADY_RESOLVED)

    if ride.status in {
        RideRequestStatus.ACCEPTED,
        RideRequestStatus.ARRIVED,
        RideRequestStatus.STARTED,
    }:
        raise conflict("ride_already_assigned", Messages.RIDE_ALREADY_ASSIGNED)

    if ride.status not in NEGOTIABLE_RIDE_STATUSES:
        raise conflict("ride_not_negotiable", Messages.RIDE_NOT_NEGOTIABLE)

    if driver_has_active_ride:
        raise conflict(
            "driver_already_has_active_ride",
            Messages.RIDE_ALREADY_ACTIVE,
        )


def sync_ride_offer_state(
    ride: RideRequest,
    *,
    pending_offer_count: int,
) -> bool:
    if ride.status not in NEGOTIABLE_RIDE_STATUSES:
        return False

    target_status = (
        RideRequestStatus.OFFERED
        if pending_offer_count > 0
        else RideRequestStatus.PENDING
    )
    if ride.status == target_status:
        return False

    assert_transition_allowed(
        current_status=ride.status,
        target_status=target_status,
    )
    ride.status = target_status
    return True


def apply_driver_cancellation_reset(
    ride: RideRequest,
    *,
    accepted_offer: RideOffer | None,
) -> None:
    if ride.status not in {
        RideRequestStatus.ACCEPTED,
        RideRequestStatus.ARRIVED,
    }:
        raise conflict(
            "ride_transition_not_allowed",
            Messages.DRIVER_CANCELLATION_NOT_ALLOWED,
        )

    ride.status = RideRequestStatus.PENDING
    ride.driver_id = None
    ride.agreed_price = None
    ride.final_price = None
    ride.platform_commission = None
    ride.driver_net_earnings = None
    ride.cancellation_reason = None
    ride.cancelled_by_role = None

    if accepted_offer is not None:
        accepted_offer.status = RideOfferStatus.INVALIDATED
        accepted_offer.responded_at = datetime.utcnow()


def apply_ride_completion(
    ride: RideRequest,
    *,
    commission_percent: Decimal,
) -> None:
    if ride.agreed_price is None:
        raise conflict(
            "ride_price_missing",
            Messages.PRICE_LOCKED,
        )

    assert_transition_allowed(
        current_status=ride.status,
        target_status=RideRequestStatus.COMPLETED,
    )

    ride.status = RideRequestStatus.COMPLETED
    ride.final_price = _money(ride.agreed_price)
    ride.platform_commission = _money(
        ride.final_price * commission_percent / Decimal("100")
    )
    ride.driver_net_earnings = _money(ride.final_price - ride.platform_commission)


def _money(value: Decimal | float) -> Decimal:
    amount = value if isinstance(value, Decimal) else Decimal(str(value))
    return amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
