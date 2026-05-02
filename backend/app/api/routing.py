from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.services.routing_service import get_route_payload

router = APIRouter(prefix="/routing", tags=["routing"])


class RouteResponse(BaseModel):
    polyline: list[list[float]]
    distance_km: float
    duration_min: int


@router.get("/route", response_model=RouteResponse)
async def route_endpoint(
    origin_lat: float = Query(),
    origin_lng: float = Query(),
    dest_lat: float = Query(),
    dest_lng: float = Query(),
) -> RouteResponse:
    payload = await get_route_payload(origin_lat, origin_lng, dest_lat, dest_lng)
    return RouteResponse(**payload)
