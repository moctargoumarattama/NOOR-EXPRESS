from datetime import datetime, time
from decimal import Decimal, ROUND_HALF_UP
from math import asin, cos, radians, sin, sqrt

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pricing_zone import (
    PricingMode,
    PricingSettings,
    PricingZone,
    TimePricingRule,
    TimeSurchargeType,
    ZoneFare,
)

DEFAULT_PRICE_PER_KM = Decimal("300.00")
DEFAULT_MINIMUM_PRICE = Decimal("1500.00")
DEFAULT_COMMISSION_PERCENT = Decimal("15.00")


class PricingNotFoundError(Exception):
    pass


class PricingZoneNotFoundError(PricingNotFoundError):
    pass


class ZoneFareNotFoundError(PricingNotFoundError):
    pass


class TimePricingRuleNotFoundError(PricingNotFoundError):
    pass


def money(value: Decimal | float | int | str) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def calculate_distance_km(
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
    return earth_radius_km * (2 * asin(sqrt(haversine)))


async def get_settings(session: AsyncSession) -> PricingSettings:
    settings = await session.get(PricingSettings, 1)
    if settings is not None:
        return settings
    settings = PricingSettings(
        id=1,
        active_mode=PricingMode.MIXED.value,
        price_per_km=DEFAULT_PRICE_PER_KM,
        minimum_price=DEFAULT_MINIMUM_PRICE,
        platform_commission_percent=DEFAULT_COMMISSION_PERCENT,
    )
    session.add(settings)
    await session.commit()
    await session.refresh(settings)
    return settings


async def get_all_zones(session: AsyncSession) -> list[PricingZone]:
    result = await session.execute(
        select(PricingZone)
        .where(PricingZone.is_active.is_(True))
        .order_by(PricingZone.name.asc())
    )
    return list(result.scalars().all())


async def calculate_ride_price(
    session: AsyncSession,
    pickup_latitude: float | None = None,
    pickup_longitude: float | None = None,
    dropoff_latitude: float | None = None,
    dropoff_longitude: float | None = None,
    pickup_zone_id: int | None = None,
    dropoff_zone_id: int | None = None,
    distance_km: Decimal | float | None = None,
    estimated_duration_minutes: int | None = None,
    request_datetime: datetime | None = None,
) -> dict:
    settings = await get_settings(session)
    zones = await get_all_zones(session)
    pickup_zone = await _resolve_zone(session, zones, pickup_zone_id, pickup_latitude, pickup_longitude)
    dropoff_zone = await _resolve_zone(session, zones, dropoff_zone_id, dropoff_latitude, dropoff_longitude)
    resolved_distance = _resolve_distance(
        distance_km,
        pickup_latitude,
        pickup_longitude,
        dropoff_latitude,
        dropoff_longitude,
    )

    mode = settings.active_mode or PricingMode.MIXED.value
    zone_rule = None
    base_price = None
    applied_mode = mode
    if mode in (PricingMode.ZONE.value, PricingMode.MIXED.value) and pickup_zone and dropoff_zone:
        zone_rule = await _find_zone_fare(session, pickup_zone.id, dropoff_zone.id)
        if zone_rule:
            base_price = money(zone_rule.fixed_price)
            applied_mode = "zone"

    if base_price is None:
        if mode == PricingMode.ZONE.value:
            base_price = money(settings.minimum_price)
        else:
            base_price = money(Decimal(str(resolved_distance)) * Decimal(settings.price_per_km))
            applied_mode = "distance" if mode == PricingMode.DISTANCE.value else "mixed_distance"

    time_rule = await _find_time_rule(session, request_datetime or datetime.now())
    final_price = _apply_time_rule(base_price, time_rule)
    minimum = money(settings.minimum_price)
    if estimated_duration_minutes and estimated_duration_minutes > settings.long_ride_threshold_minutes:
        minimum = max(minimum, money(settings.long_ride_minimum_price))
    final_price = max(money(final_price), minimum)
    commission = money(final_price * Decimal(settings.platform_commission_percent) / Decimal("100"))

    return {
        "base_price": float(money(base_price)),
        "applied_mode": applied_mode,
        "applied_zone_rule": _zone_fare_dict(zone_rule) if zone_rule else None,
        "applied_time_rule": _time_rule_dict(time_rule) if time_rule else None,
        "final_estimated_price": float(final_price),
        "estimated_price": float(final_price),
        "platform_commission_preview": float(commission),
        "distance_km": round(float(resolved_distance), 3),
        "pickup_zone": pickup_zone.name if pickup_zone else None,
        "dropoff_zone": dropoff_zone.name if dropoff_zone else None,
        "base_price_setting": float(settings.minimum_price),
        "price_per_km": float(settings.price_per_km),
    }


async def estimate_price(
    session: AsyncSession,
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
) -> dict:
    estimate = await calculate_ride_price(
        session,
        pickup_latitude=pickup_lat,
        pickup_longitude=pickup_lng,
        dropoff_latitude=dropoff_lat,
        dropoff_longitude=dropoff_lng,
    )
    estimate["base_price"] = estimate.pop("base_price_setting")
    return estimate


async def get_platform_commission_percent(session: AsyncSession) -> Decimal:
    settings = await get_settings(session)
    return Decimal(settings.platform_commission_percent)


async def _resolve_zone(session, zones, zone_id, latitude, longitude) -> PricingZone | None:
    if zone_id is not None:
        zone = await session.get(PricingZone, zone_id)
        return zone if zone and zone.is_active else None
    if latitude is None or longitude is None:
        return None
    return _detect_zone(zones, latitude, longitude)


def _resolve_distance(distance_km, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng) -> Decimal:
    if distance_km is not None:
        return Decimal(str(distance_km))
    if None in (pickup_lat, pickup_lng, dropoff_lat, dropoff_lng):
        return Decimal("0")
    return Decimal(str(calculate_distance_km(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)))


async def _find_zone_fare(session: AsyncSession, origin_id: int, destination_id: int) -> ZoneFare | None:
    result = await session.execute(
        select(ZoneFare).where(
            ZoneFare.origin_zone_id == origin_id,
            ZoneFare.destination_zone_id == destination_id,
            ZoneFare.is_active.is_(True),
        )
    )
    return result.scalar_one_or_none()


async def _find_time_rule(session: AsyncSession, at_datetime: datetime) -> TimePricingRule | None:
    result = await session.execute(
        select(TimePricingRule).where(TimePricingRule.is_active.is_(True))
    )
    rules = list(result.scalars().all())
    now_time = at_datetime.time()
    matches = [rule for rule in rules if _time_in_range(now_time, rule.start_time, rule.end_time)]
    return matches[0] if matches else None


def _time_in_range(value: time, start: time, end: time) -> bool:
    if start <= end:
        return start <= value <= end
    return value >= start or value <= end


def _apply_time_rule(price: Decimal, rule: TimePricingRule | None) -> Decimal:
    if rule is None:
        return price
    if rule.surcharge_type == TimeSurchargeType.PERCENT.value:
        return price + (price * Decimal(rule.surcharge_value) / Decimal("100"))
    return price + Decimal(rule.surcharge_value)


def _detect_zone(zones: list[PricingZone], latitude: float, longitude: float) -> PricingZone | None:
    matches: list[tuple[float, PricingZone]] = []
    for zone in zones:
        distance_km = calculate_distance_km(latitude, longitude, zone.latitude, zone.longitude)
        if distance_km <= zone.radius_km:
            matches.append((distance_km, zone))
    matches.sort(key=lambda item: item[0])
    return matches[0][1] if matches else None


def _zone_fare_dict(fare: ZoneFare | None) -> dict | None:
    if fare is None:
        return None
    return {
        "id": fare.id,
        "origin_zone_id": fare.origin_zone_id,
        "destination_zone_id": fare.destination_zone_id,
        "fixed_price": float(fare.fixed_price),
        "is_active": fare.is_active,
        "created_at": fare.created_at,
    }


def _time_rule_dict(rule: TimePricingRule | None) -> dict | None:
    if rule is None:
        return None
    return {
        "id": rule.id,
        "name": rule.name,
        "start_time": rule.start_time.isoformat(),
        "end_time": rule.end_time.isoformat(),
        "surcharge_type": rule.surcharge_type,
        "surcharge_value": float(rule.surcharge_value),
    }
