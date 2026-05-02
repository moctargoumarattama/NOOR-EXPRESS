from __future__ import annotations

from datetime import datetime, timedelta
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.models.driver_wallet import DriverWallet
from app.models.pricing_zone import PricingZone
from app.models.ride_request import RideRequest, RideRequestStatus
from app.models.ride_request_rejection import RideRequestRejection
from app.models.user import User
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
    money,
)

DRIVER_STATS_CACHE_TTL_SECONDS = 600
_driver_dashboard_stats_cache: dict[str, tuple[datetime, DriverDashboardStatsRead]] = {}


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
) -> DriverWalletSummaryRead:
    wallet_result = await session.execute(
        select(DriverWallet).where(DriverWallet.driver_id == driver_id)
    )
    wallet = wallet_result.scalar_one_or_none()
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
    total = EarningsWindowRead(
        rides_count=int(wallet.total_completed_rides if wallet is not None else 0),
        gross_amount=(
            round(float(wallet.total_gross_earnings or 0), 2)
            if wallet is not None
            else 0.0
        ),
        commission_amount=(
            round(float(wallet.total_commission or 0), 2) if wallet is not None else 0.0
        ),
        net_amount=(
            round(float(wallet.total_net_earnings or 0), 2)
            if wallet is not None
            else 0.0
        ),
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


async def get_admin_commission_ledger(
    session: AsyncSession,
    *,
    driver_id: int | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> CommissionLedgerRead:
    client = aliased(User)
    driver = aliased(User)
    filters = [
        RideRequest.status == RideRequestStatus.COMPLETED,
        RideRequest.driver_id.is_not(None),
        RideRequest.platform_commission.is_not(None),
    ]
    if driver_id is not None:
        filters.append(RideRequest.driver_id == driver_id)
    if date_from is not None:
        filters.append(
            func.coalesce(RideRequest.completed_at, RideRequest.created_at) >= date_from
        )
    if date_to is not None:
        filters.append(
            func.coalesce(RideRequest.completed_at, RideRequest.created_at) <= date_to
        )

    count_result = await session.execute(
        select(func.count(RideRequest.id)).where(*filters)
    )
    totals_result = await session.execute(
        select(
            func.coalesce(func.sum(RideRequest.final_price), 0.0),
            func.coalesce(func.sum(RideRequest.platform_commission), 0.0),
            func.coalesce(func.sum(RideRequest.driver_net_earnings), 0.0),
        ).where(*filters)
    )
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
    total_gross_amount, total_commission_amount, total_net_amount = totals_result.one()
    items = [
        CommissionLedgerItemRead(
            ride_id=ride.id,
            client_phone_number=client_phone,
            driver_id=ride.driver_id or 0,
            driver_phone_number=driver_phone,
            completed_at=ride.completed_at,
            gross_amount=round(float(ride.final_price or 0), 2),
            commission_amount=round(float(ride.platform_commission or 0), 2),
            net_amount=round(float(ride.driver_net_earnings or 0), 2),
        )
        for ride, client_phone, driver_phone in rows_result.all()
    ]
    return CommissionLedgerRead(
        total_count=int(count_result.scalar_one() or 0),
        total_gross_amount=round(float(total_gross_amount or 0), 2),
        total_commission_amount=round(float(total_commission_amount or 0), 2),
        total_net_amount=round(float(total_net_amount or 0), 2),
        items=items,
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
