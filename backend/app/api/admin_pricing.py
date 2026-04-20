from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db_session
from app.schemas.pricing import (
    PricingPreviewRequest,
    PricingSettingsRead,
    PricingSettingsUpdate,
    PricingZoneCreate,
    PricingZoneRead,
    PricingZoneUpdate,
    TimePricingRuleCreate,
    TimePricingRuleRead,
    TimePricingRuleUpdate,
    ZoneFareCreate,
    ZoneFareRead,
    ZoneFareUpdate,
)
from app.services.admin_service import require_admin
from app.services.pricing_admin_service import (
    create_time_rule,
    create_zone,
    create_zone_fare,
    delete_time_rule,
    delete_zone,
    delete_zone_fare,
    get_all_zones_for_admin,
    list_time_rules,
    list_zone_fares,
    update_settings,
    update_time_rule,
    update_zone,
    update_zone_fare,
)
from app.services.pricing_service import (
    PricingZoneNotFoundError,
    TimePricingRuleNotFoundError,
    ZoneFareNotFoundError,
    calculate_ride_price,
    get_settings,
)

router = APIRouter(prefix="/admin/pricing", tags=["admin_pricing"])


@router.get("/settings", response_model=PricingSettingsRead)
async def read_settings_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingSettingsRead:
    return PricingSettingsRead.model_validate(await get_settings(session))


@router.put("/settings", response_model=PricingSettingsRead)
async def update_settings_endpoint(
    settings_in: PricingSettingsUpdate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingSettingsRead:
    settings = await update_settings(session, settings_in.model_dump(exclude_unset=True))
    return PricingSettingsRead.model_validate(settings)


@router.get("/zones", response_model=list[PricingZoneRead])
async def list_zones_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[PricingZoneRead]:
    return [PricingZoneRead.model_validate(zone) for zone in await get_all_zones_for_admin(session)]


@router.post("/zones", response_model=PricingZoneRead, status_code=status.HTTP_201_CREATED)
async def create_zone_endpoint(
    zone_in: PricingZoneCreate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingZoneRead:
    return PricingZoneRead.model_validate(await create_zone(session, zone_in.model_dump()))


@router.put("/zones/{zone_id}", response_model=PricingZoneRead)
async def update_zone_endpoint(
    zone_id: int,
    zone_in: PricingZoneUpdate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingZoneRead:
    try:
        zone = await update_zone(session, zone_id, zone_in.model_dump(exclude_unset=True))
    except PricingZoneNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    return PricingZoneRead.model_validate(zone)


@router.delete("/zones/{zone_id}", response_model=PricingZoneRead)
async def delete_zone_endpoint(
    zone_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingZoneRead:
    try:
        return PricingZoneRead.model_validate(await delete_zone(session, zone_id))
    except PricingZoneNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc


@router.get("/zone-fares", response_model=list[ZoneFareRead])
async def list_zone_fares_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[ZoneFareRead]:
    return [ZoneFareRead(**fare) for fare in await list_zone_fares(session)]


@router.post("/zone-fares", response_model=ZoneFareRead, status_code=status.HTTP_201_CREATED)
async def create_zone_fare_endpoint(
    fare_in: ZoneFareCreate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> ZoneFareRead:
    fare = await create_zone_fare(session, fare_in.model_dump())
    return ZoneFareRead.model_validate(fare)


@router.put("/zone-fares/{fare_id}", response_model=ZoneFareRead)
async def update_zone_fare_endpoint(
    fare_id: int,
    fare_in: ZoneFareUpdate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> ZoneFareRead:
    try:
        fare = await update_zone_fare(session, fare_id, fare_in.model_dump(exclude_unset=True))
    except ZoneFareNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    return ZoneFareRead.model_validate(fare)


@router.delete("/zone-fares/{fare_id}", response_model=ZoneFareRead)
async def delete_zone_fare_endpoint(
    fare_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> ZoneFareRead:
    try:
        return ZoneFareRead.model_validate(await delete_zone_fare(session, fare_id))
    except ZoneFareNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc


@router.get("/time-rules", response_model=list[TimePricingRuleRead])
async def list_time_rules_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[TimePricingRuleRead]:
    return [TimePricingRuleRead.model_validate(rule) for rule in await list_time_rules(session)]


@router.post("/time-rules", response_model=TimePricingRuleRead, status_code=status.HTTP_201_CREATED)
async def create_time_rule_endpoint(
    rule_in: TimePricingRuleCreate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> TimePricingRuleRead:
    return TimePricingRuleRead.model_validate(await create_time_rule(session, rule_in.model_dump()))


@router.put("/time-rules/{rule_id}", response_model=TimePricingRuleRead)
async def update_time_rule_endpoint(
    rule_id: int,
    rule_in: TimePricingRuleUpdate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> TimePricingRuleRead:
    try:
        rule = await update_time_rule(session, rule_id, rule_in.model_dump(exclude_unset=True))
    except TimePricingRuleNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    return TimePricingRuleRead.model_validate(rule)


@router.delete("/time-rules/{rule_id}", response_model=TimePricingRuleRead)
async def delete_time_rule_endpoint(
    rule_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> TimePricingRuleRead:
    try:
        return TimePricingRuleRead.model_validate(await delete_time_rule(session, rule_id))
    except TimePricingRuleNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc


@router.post("/preview")
async def preview_pricing_endpoint(
    preview_in: PricingPreviewRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    return await calculate_ride_price(
        session,
        pickup_zone_id=preview_in.pickup_zone_id,
        dropoff_zone_id=preview_in.dropoff_zone_id,
        distance_km=preview_in.distance_km,
        estimated_duration_minutes=preview_in.estimated_duration_minutes,
        request_datetime=preview_in.request_datetime,
    )
