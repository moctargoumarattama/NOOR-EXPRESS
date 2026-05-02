from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db_session
from app.schemas.pricing import (
    PriceEstimateRead,
    PricingZoneCreate,
    PricingZoneRead,
    PricingZoneUpdate,
)
from app.services.admin_service import admin_bearer_scheme, decode_admin_token, require_admin
from app.services.pricing_admin_service import (
    create_zone,
    delete_zone,
    get_all_zones_for_admin,
    update_zone,
)
from app.services.pricing_service import (
    PricingZoneNotFoundError,
    get_all_zones,
)
from app.services.ride_lifecycle_service import estimate_ride_preview

router = APIRouter(prefix="/pricing", tags=["pricing"])


async def _optional_admin(credentials=Depends(admin_bearer_scheme)) -> dict | None:
    if credentials is None:
        return None
    try:
        return decode_admin_token(credentials.credentials)
    except HTTPException:
        return None


@router.get("/zones", response_model=list[PricingZoneRead])
async def list_pricing_zones_endpoint(
    session: AsyncSession = Depends(get_db_session),
    include_inactive: bool = Query(default=False),
    _admin: dict | None = Depends(_optional_admin),
) -> list[PricingZoneRead]:
    zones = (
        await get_all_zones_for_admin(session)
        if include_inactive and _admin is not None
        else await get_all_zones(session)
    )
    return [PricingZoneRead.model_validate(zone) for zone in zones]


@router.get("/estimate", response_model=PriceEstimateRead)
async def estimate_price_endpoint(
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
    session: AsyncSession = Depends(get_db_session),
) -> PriceEstimateRead:
    estimate = await estimate_ride_preview(
        session,
        pickup_latitude=pickup_lat,
        pickup_longitude=pickup_lng,
        dropoff_latitude=dropoff_lat,
        dropoff_longitude=dropoff_lng,
    )
    return PriceEstimateRead(**estimate)


@router.post("/zones", response_model=PricingZoneRead, status_code=status.HTTP_201_CREATED)
async def create_pricing_zone_endpoint(
    zone_in: PricingZoneCreate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingZoneRead:
    zone = await create_zone(session, zone_in.model_dump())
    return PricingZoneRead.model_validate(zone)


@router.put("/zones/{zone_id}", response_model=PricingZoneRead)
async def update_pricing_zone_endpoint(
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
async def delete_pricing_zone_endpoint(
    zone_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> PricingZoneRead:
    try:
        zone = await delete_zone(session, zone_id)
    except PricingZoneNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    return PricingZoneRead.model_validate(zone)
