from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.messages import Messages
from app.models.pricing_zone import PricingSettings, PricingZone, TimePricingRule, ZoneFare
from app.services.pricing_service import (
    PricingZoneNotFoundError,
    TimePricingRuleNotFoundError,
    ZoneFareNotFoundError,
    get_settings,
    _zone_fare_dict,
)


async def update_settings(session: AsyncSession, data: dict) -> PricingSettings:
    settings = await get_settings(session)
    for key, value in data.items():
        if value is not None:
            setattr(settings, key, value)
    await session.commit()
    await session.refresh(settings)
    return settings


async def get_all_zones_for_admin(session: AsyncSession) -> list[PricingZone]:
    result = await session.execute(select(PricingZone).order_by(PricingZone.name.asc()))
    return list(result.scalars().all())


async def create_zone(session: AsyncSession, data: dict) -> PricingZone:
    zone = PricingZone(**data)
    session.add(zone)
    await session.commit()
    await session.refresh(zone)
    return zone


async def update_zone(session: AsyncSession, zone_id: int, data: dict) -> PricingZone:
    zone = await session.get(PricingZone, zone_id)
    if zone is None:
        raise PricingZoneNotFoundError(Messages.NOT_FOUND)
    for key, value in data.items():
        if value is not None:
            setattr(zone, key, value)
    await session.commit()
    await session.refresh(zone)
    return zone


async def delete_zone(session: AsyncSession, zone_id: int) -> PricingZone:
    return await update_zone(session, zone_id, {"is_active": False})


async def list_zone_fares(session: AsyncSession) -> list[dict]:
    origin = aliased(PricingZone)
    destination = aliased(PricingZone)
    result = await session.execute(
        select(ZoneFare, origin, destination)
        .join(origin, ZoneFare.origin_zone_id == origin.id)
        .join(destination, ZoneFare.destination_zone_id == destination.id)
        .order_by(ZoneFare.id.desc())
    )
    fares: list[dict] = []
    for fare, origin_zone, destination_zone in result.all():
        item = _zone_fare_dict(fare)
        item["origin_zone_name"] = origin_zone.name
        item["destination_zone_name"] = destination_zone.name
        fares.append(item)
    return fares


async def create_zone_fare(session: AsyncSession, data: dict) -> ZoneFare:
    fare = ZoneFare(**data)
    session.add(fare)
    await session.commit()
    await session.refresh(fare)
    return fare


async def update_zone_fare(session: AsyncSession, fare_id: int, data: dict) -> ZoneFare:
    fare = await session.get(ZoneFare, fare_id)
    if fare is None:
        raise ZoneFareNotFoundError(Messages.NOT_FOUND)
    for key, value in data.items():
        if value is not None:
            setattr(fare, key, value)
    await session.commit()
    await session.refresh(fare)
    return fare


async def delete_zone_fare(session: AsyncSession, fare_id: int) -> ZoneFare:
    return await update_zone_fare(session, fare_id, {"is_active": False})


async def list_time_rules(session: AsyncSession) -> list[TimePricingRule]:
    result = await session.execute(
        select(TimePricingRule).order_by(TimePricingRule.start_time.asc())
    )
    return list(result.scalars().all())


async def create_time_rule(session: AsyncSession, data: dict) -> TimePricingRule:
    rule = TimePricingRule(**data)
    session.add(rule)
    await session.commit()
    await session.refresh(rule)
    return rule


async def update_time_rule(
    session: AsyncSession,
    rule_id: int,
    data: dict,
) -> TimePricingRule:
    rule = await session.get(TimePricingRule, rule_id)
    if rule is None:
        raise TimePricingRuleNotFoundError(Messages.NOT_FOUND)
    for key, value in data.items():
        if value is not None:
            setattr(rule, key, value)
    await session.commit()
    await session.refresh(rule)
    return rule


async def delete_time_rule(session: AsyncSession, rule_id: int) -> TimePricingRule:
    return await update_time_rule(session, rule_id, {"is_active": False})
