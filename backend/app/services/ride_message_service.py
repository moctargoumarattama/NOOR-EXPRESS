from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import ApiError, conflict, forbidden, not_found
from app.models.ride_message import RideMessage
from app.models.ride_request import RideRequest
from app.models.user import User
from app.realtime.gateway import realtime_gateway
from app.realtime.schemas import RideMessageNotification
from app.schemas.ride_request import (
    RideMessageCreate,
    RideMessagePageRead,
    RideMessageRead,
)
from app.services.ride_policy import DRIVER_ACTIVE_RIDE_STATUSES


CHAT_ENABLED_RIDE_STATUSES = DRIVER_ACTIVE_RIDE_STATUSES
DEFAULT_MESSAGE_LIMIT = 50
MAX_MESSAGE_LIMIT = 100


async def create_ride_message(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    message_in: RideMessageCreate,
) -> RideMessageRead:
    ride = await _get_accessible_chat_ride(session, ride_request_id, current_user)
    message = RideMessage(
        ride_id=ride.id,
        sender_id=current_user.id,
        sender_role=current_user.role,
        content=message_in.content,
        is_read=False,
        # Keep a backend-side fallback in case a local DB schema is missing
        # the server default for created_at.
        created_at=datetime.utcnow(),
    )
    session.add(message)
    await session.commit()
    await session.refresh(message)

    payload = _serialize_ride_message(message)
    await _notify_ride_chat_participants(ride, payload)
    return payload


async def list_ride_messages(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
    *,
    limit: int = DEFAULT_MESSAGE_LIMIT,
    offset: int = 0,
    mark_read: bool = True,
) -> RideMessagePageRead:
    ride = await _get_accessible_chat_ride(session, ride_request_id, current_user)
    bounded_limit = max(1, min(limit, MAX_MESSAGE_LIMIT))

    if mark_read:
        await _mark_messages_as_read(session, ride.id, current_user)

    result = await session.execute(
        select(RideMessage)
        .where(RideMessage.ride_id == ride.id)
        .order_by(RideMessage.created_at.desc(), RideMessage.id.desc())
        .offset(offset)
        .limit(bounded_limit)
    )
    items = [
        _serialize_ride_message(message)
        for message in result.scalars().all()
    ]
    unread_count = await get_unread_ride_message_count(
        session,
        ride_request_id=ride.id,
        current_user=current_user,
    )
    return RideMessagePageRead(
        items=items,
        unread_count=unread_count,
        limit=bounded_limit,
        offset=offset,
    )


def _serialize_ride_message(message: RideMessage) -> RideMessageRead:
    if message.created_at is None:
        # Defensive fallback for legacy rows that were inserted before the
        # created_at default existed.
        message.created_at = datetime.utcnow()
    return RideMessageRead.model_validate(message)


async def get_unread_ride_message_count(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> int:
    ride = await _get_accessible_chat_ride(session, ride_request_id, current_user)
    result = await session.execute(
        select(func.count(RideMessage.id)).where(
            RideMessage.ride_id == ride.id,
            RideMessage.sender_id != current_user.id,
            RideMessage.is_read.is_(False),
        )
    )
    return int(result.scalar_one() or 0)


async def _get_accessible_chat_ride(
    session: AsyncSession,
    ride_request_id: int,
    current_user: User,
) -> RideRequest:
    ride = await session.get(RideRequest, ride_request_id)
    if ride is None:
        raise not_found("Ride request not found")

    participant_ids = {ride.client_id}
    if ride.driver_id is not None:
        participant_ids.add(ride.driver_id)
    if current_user.id not in participant_ids:
        raise forbidden("Access denied")

    if ride.status not in CHAT_ENABLED_RIDE_STATUSES:
        raise conflict(
            "ride_chat_inactive",
            "Ride chat is only available while the ride is active.",
        )
    return ride


async def _mark_messages_as_read(
    session: AsyncSession,
    ride_id: int,
    current_user: User,
) -> None:
    await session.execute(
        update(RideMessage)
        .where(
            RideMessage.ride_id == ride_id,
            RideMessage.sender_id != current_user.id,
            RideMessage.is_read.is_(False),
        )
        .values(is_read=True)
    )
    await session.commit()


async def _notify_ride_chat_participants(
    ride: RideRequest,
    message: RideMessageRead,
) -> None:
    notification = RideMessageNotification(
        ride_request_id=ride.id,
        message=message.model_dump(mode="json"),
    )
    await realtime_gateway.send_ride_message_notification(
        ride.client_id,
        notification,
    )
    if ride.driver_id is not None:
        await realtime_gateway.send_ride_message_notification_to_driver(
            ride.driver_id,
            notification,
        )
