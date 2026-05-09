from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.messages import Messages
from app.core.firebase import notify_user
from app.models.driver_profile import DriverProfile
from app.models.driver_wallet import DriverWallet
from app.models.pricing_zone import PricingZone
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.ride_request_rejection import RideRequestRejection
from app.models.user import User
from app.models.withdrawal_request import WithdrawalRequest, WithdrawalRequestStatus
from app.schemas.driver_wallet import (
    CommissionLedgerItemRead,
    CommissionLedgerRead,
    DriverDashboardStatsRead,
    DriverPeakHourStatsRead,
    DriverReputationStatsRead,
    DriverRevenueStatsRead,
    DriverRideStatusStatsRead,
    DriverZoneProfitabilityRead,
    DriverWalletSummaryRead,
    EarningsWindowRead,
)
from app.services.pricing_service import (
    detect_pricing_zone,
    get_all_zones,
    get_platform_commission_percent,
    money,
)

DRIVER_STATS_CACHE_TTL_SECONDS = 600
_driver_dashboard_stats_cache: dict[str, tuple[datetime, DriverDashboardStatsRead]] = {}
MIN_WITHDRAWAL_AMOUNT = Decimal("500.00")


class WithdrawalRequestPendingConflictError(Exception):
    pass


class WithdrawalRequestNotFoundError(Exception):
    pass


class WithdrawalRequestStateConflictError(Exception):
    pass


class WithdrawalRequestAmountTooLowError(Exception):
    pass


class WithdrawalRequestValidationError(Exception):
    pass


async def get_or_create_driver_wallet(
    session: AsyncSession,
    driver_id: int,
) -> DriverWallet:
    result = await session.execute(
        select(DriverWallet).where(DriverWallet.driver_id == driver_id)
    )
    wallet = result.scalar_one_or_none()
    if wallet is not None:
        return wallet

    wallet = DriverWallet(driver_id=driver_id)
    session.add(wallet)
    return wallet


def apply_completed_ride_to_wallet(
    wallet: DriverWallet,
    ride: RideRequest,
) -> None:
    gross_amount = money(ride.final_price or 0)
    commission_amount = money(ride.platform_commission or 0)
    net_amount = money(ride.driver_net_earnings or 0)

    wallet.total_completed_rides = int(wallet.total_completed_rides or 0) + 1
    wallet.total_gross_earnings = money(
        Decimal(str(wallet.total_gross_earnings or 0)) + gross_amount
    )
    wallet.total_commission = money(
        Decimal(str(wallet.total_commission or 0)) + commission_amount
    )
    wallet.total_net_earnings = money(
        Decimal(str(wallet.total_net_earnings or 0)) + net_amount
    )


async def sync_completed_ride_to_wallet(
    session: AsyncSession,
    ride: RideRequest,
) -> DriverWallet | None:
    if ride.driver_id is None:
        return None
    wallet = await get_or_create_driver_wallet(session, ride.driver_id)
    apply_completed_ride_to_wallet(wallet, ride)
    return wallet


async def get_driver_wallet_summary(
    session: AsyncSession,
    driver_id: int,
) -> dict[str, object]:
    wallet_result = await session.execute(
        select(DriverWallet).where(DriverWallet.driver_id == driver_id)
    )
    wallet = wallet_result.scalar_one_or_none()
    summary = await _build_driver_wallet_summary_payload(session, driver_id, wallet)
    commission_percent = round(float(await get_platform_commission_percent(session)), 2)
    return {
        **summary.model_dump(),
        "platform_commission_percent": commission_percent,
        "commission_due_amount": _wallet_commission_due_amount(wallet),
    }


async def _build_driver_wallet_summary_payload(
    session: AsyncSession,
    driver_id: int,
    wallet: DriverWallet | None,
) -> DriverWalletSummaryRead:
    now = datetime.utcnow()
    today_start = datetime(now.year, now.month, now.day)
    week_start = today_start - timedelta(days=today_start.weekday())
    today = await _earnings_window(
        session,
        driver_id,
        date_from=today_start,
        date_to=None,
    )
    week = await _earnings_window(
        session,
        driver_id,
        date_from=week_start,
        date_to=None,
    )
    total = await _earnings_window(
        session,
        driver_id,
        date_from=None,
        date_to=None,
    )
    return DriverWalletSummaryRead(
        driver_id=driver_id,
        today=today,
        week=week,
        total=total,
        updated_at=wallet.updated_at if wallet is not None else None,
    )


async def get_driver_dashboard_stats(
    session: AsyncSession,
    driver_id: int,
) -> DriverDashboardStatsRead:
    cached_payload = _read_driver_dashboard_stats_cache(driver_id)
    if cached_payload is not None:
        return cached_payload

    payload = await _build_driver_dashboard_stats(session, driver_id)
    _write_driver_dashboard_stats_cache(driver_id, payload)
    return payload


def invalidate_driver_dashboard_stats_cache(driver_id: int) -> None:
    _driver_dashboard_stats_cache.pop(_driver_stats_cache_key(driver_id), None)


def reset_driver_dashboard_stats_cache() -> None:
    _driver_dashboard_stats_cache.clear()


async def _build_driver_dashboard_stats(
    session: AsyncSession,
    driver_id: int,
) -> DriverDashboardStatsRead:
    completed_rides = await _list_completed_driver_rides(session, driver_id)
    return DriverDashboardStatsRead(
        driver_id=driver_id,
        revenue=await _build_driver_revenue_stats(session, driver_id),
        rides=await _build_driver_ride_status_stats(session, driver_id),
        peak_hours=_build_driver_peak_hours(completed_rides),
        profitable_zones=await _build_driver_profitable_zones(session, completed_rides),
        reputation=await _build_driver_reputation_stats(session, driver_id),
    )


async def _build_driver_revenue_stats(
    session: AsyncSession,
    driver_id: int,
) -> DriverRevenueStatsRead:
    now = datetime.utcnow()
    today_start = datetime(now.year, now.month, now.day)
    week_start = today_start - timedelta(days=today_start.weekday())
    month_start = datetime(now.year, now.month, 1)
    return DriverRevenueStatsRead(
        today=await _sum_driver_completed_revenue(session, driver_id, today_start),
        week=await _sum_driver_completed_revenue(session, driver_id, week_start),
        month=await _sum_driver_completed_revenue(session, driver_id, month_start),
        total=await _sum_driver_completed_revenue(session, driver_id, None),
    )


async def _sum_driver_completed_revenue(
    session: AsyncSession,
    driver_id: int,
    date_from: datetime | None,
) -> float:
    filters = [
        RideRequest.driver_id == driver_id,
        RideRequest.status == RideRequestStatus.COMPLETED,
    ]
    if date_from is not None:
        filters.append(_ride_event_time() >= date_from)

    result = await session.execute(
        select(func.coalesce(func.sum(_driver_revenue_expression()), 0.0)).where(
            *filters
        )
    )
    return round(float(result.scalar_one() or 0.0), 2)


async def _build_driver_ride_status_stats(
    session: AsyncSession,
    driver_id: int,
) -> DriverRideStatusStatsRead:
    grouped_result = await session.execute(
        select(RideRequest.status, func.count(RideRequest.id))
        .where(
            RideRequest.driver_id == driver_id,
            RideRequest.status.in_(
                [RideRequestStatus.COMPLETED, RideRequestStatus.CANCELLED],
            ),
        )
        .group_by(RideRequest.status)
    )
    grouped_counts = {status: count for status, count in grouped_result.all()}
    refused_count_result = await session.execute(
        select(func.count(RideRequestRejection.id)).where(
            RideRequestRejection.driver_id == driver_id
        )
    )
    return DriverRideStatusStatsRead(
        completed=int(grouped_counts.get(RideRequestStatus.COMPLETED, 0)),
        cancelled=int(grouped_counts.get(RideRequestStatus.CANCELLED, 0)),
        refused=int(refused_count_result.scalar_one() or 0),
    )


def _build_driver_peak_hours(
    completed_rides: list[RideRequest],
) -> list[DriverPeakHourStatsRead]:
    rides_per_hour = [0] * 24
    revenue_per_hour = [0.0] * 24
    for ride in completed_rides:
        hour = _ride_event_datetime(ride).hour
        rides_per_hour[hour] += 1
        revenue_per_hour[hour] += _ride_revenue_value(ride)

    return [
        DriverPeakHourStatsRead(
            hour=hour,
            completed_rides=rides_per_hour[hour],
            average_revenue=(
                round(
                    revenue_per_hour[hour] / rides_per_hour[hour],
                    2,
                )
                if rides_per_hour[hour] > 0
                else 0.0
            ),
        )
        for hour in range(24)
    ]


async def _build_driver_profitable_zones(
    session: AsyncSession,
    completed_rides: list[RideRequest],
) -> list[DriverZoneProfitabilityRead]:
    zones = await get_all_zones(session)
    zone_totals: dict[str, tuple[float, int]] = {}
    for ride in completed_rides:
        zone_name = _pickup_zone_name(zones, ride)
        if zone_name is None:
            continue
        current_revenue, current_rides = zone_totals.get(zone_name, (0.0, 0))
        zone_totals[zone_name] = (
            current_revenue + _ride_revenue_value(ride),
            current_rides + 1,
        )

    profitable_zones = [
        DriverZoneProfitabilityRead(
            zone_name=zone_name,
            rides_count=rides_count,
            average_revenue=round(total_revenue / rides_count, 2),
        )
        for zone_name, (total_revenue, rides_count) in zone_totals.items()
        if rides_count > 0
    ]
    profitable_zones.sort(
        key=lambda item: (-item.average_revenue, -item.rides_count, item.zone_name)
    )
    return profitable_zones[:5]


async def _build_driver_reputation_stats(
    session: AsyncSession,
    driver_id: int,
) -> DriverReputationStatsRead:
    global_average = await _average_driver_rating(
        session,
        driver_id,
        date_from=None,
    )
    last_30_days_average = await _average_driver_rating(
        session,
        driver_id,
        date_from=datetime.utcnow() - timedelta(days=30),
    )
    return DriverReputationStatsRead(
        last_30_days=last_30_days_average,
        global_average=global_average,
    )


async def _average_driver_rating(
    session: AsyncSession,
    driver_id: int,
    date_from: datetime | None,
) -> float:
    filters = [
        RideRequest.driver_id == driver_id,
        RideRequest.client_rating_for_driver.is_not(None),
    ]
    if date_from is not None:
        filters.append(_ride_event_time() >= date_from)

    result = await session.execute(
        select(func.avg(RideRequest.client_rating_for_driver)).where(*filters)
    )
    return round(float(result.scalar_one() or 0.0), 2)


async def _list_completed_driver_rides(
    session: AsyncSession,
    driver_id: int,
) -> list[RideRequest]:
    result = await session.execute(
        select(RideRequest).where(
            RideRequest.driver_id == driver_id,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
    )
    return list(result.scalars().all())


def _pickup_zone_name(zones: list[PricingZone], ride: RideRequest) -> str | None:
    if ride.pickup_latitude is None or ride.pickup_longitude is None:
        return None
    zone = detect_pricing_zone(
        zones,
        ride.pickup_latitude,
        ride.pickup_longitude,
    )
    return None if zone is None else zone.name


def _ride_revenue_value(ride: RideRequest) -> float:
    return float(
        ride.driver_net_earnings
        or ride.final_price
        or ride.agreed_price
        or ride.estimated_price
        or 0.0
    )


def _ride_event_datetime(ride: RideRequest) -> datetime:
    return ride.completed_at or ride.created_at


def _driver_revenue_expression():
    return func.coalesce(
        RideRequest.driver_net_earnings,
        RideRequest.final_price,
        RideRequest.agreed_price,
        RideRequest.estimated_price,
        0.0,
    )


def _ride_event_time():
    return func.coalesce(RideRequest.completed_at, RideRequest.created_at)


def _driver_stats_cache_key(driver_id: int) -> str:
    return f"{driver_id}:stats"


def _read_driver_dashboard_stats_cache(
    driver_id: int,
) -> DriverDashboardStatsRead | None:
    cache_key = _driver_stats_cache_key(driver_id)
    cached_payload = _driver_dashboard_stats_cache.get(cache_key)
    if cached_payload is None:
        return None

    expires_at, payload = cached_payload
    if datetime.utcnow() >= expires_at:
        _driver_dashboard_stats_cache.pop(cache_key, None)
        return None

    return payload


def _write_driver_dashboard_stats_cache(
    driver_id: int,
    payload: DriverDashboardStatsRead,
) -> None:
    _driver_dashboard_stats_cache[_driver_stats_cache_key(driver_id)] = (
        datetime.utcnow() + timedelta(seconds=DRIVER_STATS_CACHE_TTL_SECONDS),
        payload,
    )


def _wallet_commission_due_amount(wallet: DriverWallet | None) -> float:
    if wallet is None:
        return 0.0
    due_amount = money(wallet.total_commission or 0)
    if due_amount < Decimal("0.00"):
        return 0.0
    return round(float(due_amount), 2)


def _normalize_withdrawal_note(
    note: str | None,
    *,
    required: bool,
) -> str | None:
    if note is None:
        if required:
            raise WithdrawalRequestValidationError(Messages.ADMIN_NOTE_REQUIRED)
        return None
    cleaned = note.strip()
    if required and not cleaned:
        raise WithdrawalRequestValidationError(Messages.ADMIN_NOTE_REQUIRED)
    if not cleaned:
        return None
    if len(cleaned) > 200:
        raise WithdrawalRequestValidationError(Messages.NOTE_TOO_LONG)
    return cleaned


def _withdrawal_payload(
    withdrawal: WithdrawalRequest,
    *,
    driver_phone_number: str | None = None,
    driver_first_name: str | None = None,
    driver_plate_number: str | None = None,
) -> dict[str, object]:
    return {
        "id": withdrawal.id,
        "driver_id": withdrawal.driver_id,
        "amount_due": round(float(withdrawal.amount_due or 0), 2),
        "commission_rate_snapshot": round(
            float(withdrawal.commission_rate_snapshot or 0),
            2,
        ),
        "status": str(withdrawal.status),
        "driver_note": withdrawal.driver_note,
        "admin_note": withdrawal.admin_note,
        "created_at": withdrawal.created_at,
        "confirmed_at": withdrawal.confirmed_at,
        "confirmed_by": withdrawal.confirmed_by,
        "driver_phone_number": driver_phone_number,
        "driver_first_name": driver_first_name,
        "driver_plate_number": driver_plate_number,
    }


def _status_priority():
    return case(
        (WithdrawalRequest.status == WithdrawalRequestStatus.PENDING.value, 0),
        else_=1,
    )


async def _get_withdrawal_request_or_404(
    session: AsyncSession,
    withdrawal_request_id: str,
    *,
    driver_id: int | None = None,
) -> WithdrawalRequest:
    filters = [WithdrawalRequest.id == withdrawal_request_id]
    if driver_id is not None:
        filters.append(WithdrawalRequest.driver_id == driver_id)
    result = await session.execute(select(WithdrawalRequest).where(*filters))
    withdrawal = result.scalar_one_or_none()
    if withdrawal is None:
        raise WithdrawalRequestNotFoundError(Messages.WITHDRAWAL_NOT_FOUND)
    return withdrawal


async def create_driver_withdrawal_request(
    session: AsyncSession,
    *,
    driver_id: int,
    driver_note: str | None,
) -> dict[str, object]:
    pending_result = await session.execute(
        select(WithdrawalRequest.id).where(
            WithdrawalRequest.driver_id == driver_id,
            WithdrawalRequest.status == WithdrawalRequestStatus.PENDING.value,
        )
    )
    if pending_result.scalar_one_or_none() is not None:
        raise WithdrawalRequestPendingConflictError(
            Messages.WITHDRAWAL_ALREADY_PENDING,
        )

    wallet = await get_or_create_driver_wallet(session, driver_id)
    amount_due = money(wallet.total_commission or 0)
    if amount_due < MIN_WITHDRAWAL_AMOUNT:
        raise WithdrawalRequestAmountTooLowError(
            Messages.INSUFFICIENT_BALANCE,
        )

    withdrawal = WithdrawalRequest(
        driver_id=driver_id,
        amount_due=amount_due,
        commission_rate_snapshot=money(await get_platform_commission_percent(session)),
        status=WithdrawalRequestStatus.PENDING.value,
        driver_note=_normalize_withdrawal_note(driver_note, required=False),
    )
    session.add(withdrawal)
    await session.commit()
    await session.refresh(withdrawal)
    return _withdrawal_payload(withdrawal)


async def list_driver_withdrawal_requests(
    session: AsyncSession,
    *,
    driver_id: int,
    limit: int,
    offset: int,
) -> dict[str, object]:
    filters = [WithdrawalRequest.driver_id == driver_id]
    total_count_result = await session.execute(
        select(func.count(WithdrawalRequest.id)).where(*filters)
    )
    items_result = await session.execute(
        select(WithdrawalRequest)
        .where(*filters)
        .order_by(WithdrawalRequest.created_at.desc(), WithdrawalRequest.id.desc())
        .offset(offset)
        .limit(limit)
    )
    pending_result = await session.execute(
        select(WithdrawalRequest)
        .where(
            WithdrawalRequest.driver_id == driver_id,
            WithdrawalRequest.status == WithdrawalRequestStatus.PENDING.value,
        )
        .order_by(WithdrawalRequest.created_at.desc(), WithdrawalRequest.id.desc())
        .limit(1)
    )
    pending = pending_result.scalar_one_or_none()
    return {
        "total_count": int(total_count_result.scalar_one() or 0),
        "pending_request": None if pending is None else _withdrawal_payload(pending),
        "items": [_withdrawal_payload(item) for item in items_result.scalars().all()],
    }


async def cancel_driver_withdrawal_request(
    session: AsyncSession,
    *,
    driver_id: int,
    withdrawal_request_id: str,
) -> None:
    withdrawal = await _get_withdrawal_request_or_404(
        session,
        withdrawal_request_id,
        driver_id=driver_id,
    )
    if withdrawal.status != WithdrawalRequestStatus.PENDING.value:
        raise WithdrawalRequestStateConflictError(
            Messages.WITHDRAWAL_PENDING_ONLY,
        )
    await session.delete(withdrawal)
    await session.commit()


async def list_admin_withdrawal_requests(
    session: AsyncSession,
    *,
    status: str | None,
    driver_id: int | None,
    limit: int,
    offset: int,
) -> dict[str, object]:
    filters = _withdrawal_filters(status=status, driver_id=driver_id)
    count_result = await session.execute(
        select(func.count(WithdrawalRequest.id)).where(*filters)
    )
    rows = await _list_admin_withdrawal_rows(
        session,
        filters=filters,
        limit=limit,
        offset=offset,
    )
    return {
        "total_count": int(count_result.scalar_one() or 0),
        "pending_count": await _count_pending_withdrawals(session, driver_id=driver_id),
        "items": [
            _withdrawal_payload(
                withdrawal,
                driver_phone_number=phone_number,
                driver_first_name=first_name,
                driver_plate_number=plate_number,
            )
            for withdrawal, phone_number, plate_number, first_name in rows
        ],
    }


async def resolve_admin_withdrawal_request(
    session: AsyncSession,
    *,
    withdrawal_request_id: str,
    action: str,
    admin_id: int,
    admin_note: str | None,
) -> dict[str, object]:
    withdrawal = await _get_withdrawal_request_or_404(session, withdrawal_request_id)
    if withdrawal.status != WithdrawalRequestStatus.PENDING.value:
        raise WithdrawalRequestStateConflictError(
            Messages.WITHDRAWAL_PENDING_ONLY,
        )

    if action == "confirm":
        return await _confirm_withdrawal_request(
            session,
            withdrawal=withdrawal,
            admin_id=admin_id,
            admin_note=admin_note,
        )

    if action != "reject":
        raise WithdrawalRequestValidationError(Messages.INVALID_WITHDRAWAL_ACTION)
    return await _reject_withdrawal_request(
        session,
        withdrawal=withdrawal,
        admin_note=admin_note,
    )


def _withdrawal_filters(*, status: str | None, driver_id: int | None):
    filters = []
    if status is not None:
        filters.append(WithdrawalRequest.status == status)
    if driver_id is not None:
        filters.append(WithdrawalRequest.driver_id == driver_id)
    return filters


async def _list_admin_withdrawal_rows(
    session: AsyncSession,
    *,
    filters,
    limit: int,
    offset: int,
):
    rows_result = await session.execute(
        select(WithdrawalRequest, User.phone_number, User.plate_number, DriverProfile.first_name)
        .join(User, WithdrawalRequest.driver_id == User.id)
        .outerjoin(DriverProfile, DriverProfile.user_id == User.id)
        .where(*filters)
        .order_by(_status_priority(), WithdrawalRequest.created_at.desc(), WithdrawalRequest.id.desc())
        .offset(offset)
        .limit(limit)
    )
    return rows_result.all()


async def _count_pending_withdrawals(
    session: AsyncSession,
    *,
    driver_id: int | None,
) -> int:
    filters = [WithdrawalRequest.status == WithdrawalRequestStatus.PENDING.value]
    if driver_id is not None:
        filters.append(WithdrawalRequest.driver_id == driver_id)
    result = await session.execute(select(func.count(WithdrawalRequest.id)).where(*filters))
    return int(result.scalar_one() or 0)


async def _confirm_withdrawal_request(
    session: AsyncSession,
    *,
    withdrawal: WithdrawalRequest,
    admin_id: int,
    admin_note: str | None,
) -> dict[str, object]:
    wallet = await get_or_create_driver_wallet(session, withdrawal.driver_id)
    due_amount = money(wallet.total_commission or 0)
    if due_amount < money(withdrawal.amount_due):
        raise WithdrawalRequestStateConflictError(
            Messages.WALLET_DUE_AMOUNT_CONFLICT,
        )
    wallet.total_commission = money(due_amount - money(withdrawal.amount_due))
    withdrawal.status = WithdrawalRequestStatus.CONFIRMED.value
    withdrawal.confirmed_at = datetime.utcnow()
    withdrawal.confirmed_by = admin_id
    withdrawal.admin_note = _normalize_withdrawal_note(admin_note, required=False)
    await session.commit()
    await session.refresh(withdrawal)
    amount = int(round(float(withdrawal.amount_due or 0)))
    await notify_user(
        session,
        withdrawal.driver_id,
        title="Paiement confirme",
        body=f"Paiement de {amount} FCFA confirme.",
        data={"type": "withdrawal_confirmed", "amount": amount},
    )
    return _withdrawal_payload(withdrawal)


async def _reject_withdrawal_request(
    session: AsyncSession,
    *,
    withdrawal: WithdrawalRequest,
    admin_note: str | None,
) -> dict[str, object]:
    note = _normalize_withdrawal_note(admin_note, required=True)
    withdrawal.status = WithdrawalRequestStatus.REJECTED.value
    withdrawal.admin_note = note
    await session.commit()
    await session.refresh(withdrawal)
    await notify_user(
        session,
        withdrawal.driver_id,
        title="Demande refusee",
        body=f"Demande de paiement refusee: {note}",
        data={"type": "withdrawal_rejected"},
    )
    return _withdrawal_payload(withdrawal)


async def get_admin_commission_ledger(
    session: AsyncSession,
    *,
    driver_id: int | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> CommissionLedgerRead:
    filters = _commission_ledger_filters(
        driver_id=driver_id,
        date_from=date_from,
        date_to=date_to,
    )
    total_count, total_gross_amount, total_commission_amount, total_net_amount = (
        await _commission_ledger_totals(session, filters)
    )
    rows = await _commission_ledger_rows(
        session,
        filters=filters,
        limit=limit,
        offset=offset,
    )
    items = [_commission_ledger_item(ride, client_phone, driver_phone) for ride, client_phone, driver_phone in rows]
    return CommissionLedgerRead(
        total_count=total_count,
        total_gross_amount=total_gross_amount,
        total_commission_amount=total_commission_amount,
        total_net_amount=total_net_amount,
        items=items,
    )


def _commission_ledger_filters(
    *,
    driver_id: int | None,
    date_from: datetime | None,
    date_to: datetime | None,
):
    filters = [
        RideRequest.status == RideRequestStatus.COMPLETED,
        RideRequest.driver_id.is_not(None),
        RideRequest.platform_commission.is_not(None),
    ]
    if driver_id is not None:
        filters.append(RideRequest.driver_id == driver_id)
    if date_from is not None:
        filters.append(_ride_event_time() >= date_from)
    if date_to is not None:
        filters.append(_ride_event_time() <= date_to)
    return filters


async def _commission_ledger_totals(
    session: AsyncSession,
    filters,
) -> tuple[int, float, float, float]:
    count_result = await session.execute(select(func.count(RideRequest.id)).where(*filters))
    totals_result = await session.execute(
        select(
            func.coalesce(func.sum(RideRequest.final_price), 0.0),
            func.coalesce(func.sum(RideRequest.platform_commission), 0.0),
            func.coalesce(func.sum(RideRequest.driver_net_earnings), 0.0),
        ).where(*filters)
    )
    total_gross_amount, total_commission_amount, total_net_amount = totals_result.one()
    return (
        int(count_result.scalar_one() or 0),
        round(float(total_gross_amount or 0), 2),
        round(float(total_commission_amount or 0), 2),
        round(float(total_net_amount or 0), 2),
    )


async def _commission_ledger_rows(
    session: AsyncSession,
    *,
    filters,
    limit: int,
    offset: int,
):
    client = aliased(User)
    driver = aliased(User)
    rows_result = await session.execute(
        select(
            RideRequest,
            client.phone_number,
            driver.phone_number,
        )
        .join(client, RideRequest.client_id == client.id)
        .join(driver, RideRequest.driver_id == driver.id)
        .where(*filters)
        .order_by(
            func.coalesce(RideRequest.completed_at, RideRequest.created_at).desc(),
            RideRequest.id.desc(),
        )
        .offset(offset)
        .limit(limit)
    )
    return rows_result.all()


def _commission_ledger_item(
    ride: RideRequest,
    client_phone: str,
    driver_phone: str,
) -> CommissionLedgerItemRead:
    return CommissionLedgerItemRead(
        ride_id=ride.id,
        client_phone_number=client_phone,
        driver_id=ride.driver_id or 0,
        driver_phone_number=driver_phone,
        completed_at=ride.completed_at,
        gross_amount=round(float(ride.final_price or 0), 2),
        commission_amount=round(float(ride.platform_commission or 0), 2),
        net_amount=round(float(ride.driver_net_earnings or 0), 2),
    )


async def _earnings_window(
    session: AsyncSession,
    driver_id: int,
    *,
    date_from: datetime | None,
    date_to: datetime | None,
) -> EarningsWindowRead:
    filters = [
        RideRequest.driver_id == driver_id,
        RideRequest.status == RideRequestStatus.COMPLETED,
    ]
    if date_from is not None:
        filters.append(
            func.coalesce(RideRequest.completed_at, RideRequest.created_at) >= date_from
        )
    if date_to is not None:
        filters.append(
            func.coalesce(RideRequest.completed_at, RideRequest.created_at) <= date_to
        )

    result = await session.execute(
        select(
            func.count(RideRequest.id),
            func.coalesce(func.sum(RideRequest.final_price), 0.0),
            func.coalesce(func.sum(RideRequest.platform_commission), 0.0),
            func.coalesce(func.sum(RideRequest.driver_net_earnings), 0.0),
        ).where(*filters)
    )
    rides_count, gross_amount, commission_amount, net_amount = result.one()
    return EarningsWindowRead(
        rides_count=int(rides_count or 0),
        gross_amount=round(float(gross_amount or 0), 2),
        commission_amount=round(float(commission_amount or 0), 2),
        net_amount=round(float(net_amount or 0), 2),
    )
