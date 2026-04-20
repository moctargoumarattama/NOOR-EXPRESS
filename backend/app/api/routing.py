import asyncio
import json
from datetime import datetime, timedelta
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fastapi import APIRouter, Query
from pydantic import BaseModel

router = APIRouter(prefix="/routing", tags=["routing"])

OSRM_ROUTE_URL = "https://router.project-osrm.org/route/v1/driving"
USER_AGENT = "NoorExpress/1.0 contact@noorexpress.ne"
CACHE_TTL = timedelta(minutes=2)

_cache: dict[str, tuple[datetime, dict]] = {}


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
    cache_key = (
        f"{round(origin_lat, 5)},{round(origin_lng, 5)}:"
        f"{round(dest_lat, 5)},{round(dest_lng, 5)}"
    )
    cached = _read_cache(cache_key)
    if cached is not None:
        return RouteResponse(**cached)

    payload = await _fetch_osrm_route(origin_lat, origin_lng, dest_lat, dest_lng)
    if payload is None:
        payload = _fallback_route(origin_lat, origin_lng, dest_lat, dest_lng)

    _write_cache(cache_key, payload)
    return RouteResponse(**payload)


async def _fetch_osrm_route(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> dict | None:
    coordinates = f"{origin_lng},{origin_lat};{dest_lng},{dest_lat}"
    params = urlencode({"overview": "full", "geometries": "geojson"})
    url = f"{OSRM_ROUTE_URL}/{coordinates}?{params}"
    try:
        data = await asyncio.to_thread(_fetch_json, url)
        routes = data.get("routes") if isinstance(data, dict) else None
        if not routes:
            return None
        route = routes[0]
        geometry = route.get("geometry") if isinstance(route, dict) else None
        coordinates = geometry.get("coordinates") if isinstance(geometry, dict) else []
        points = [
            [float(lat), float(lng)]
            for lng, lat in coordinates
            if isinstance(lng, (int, float)) and isinstance(lat, (int, float))
        ]
        if len(points) < 2:
            return None
        return {
            "polyline": points,
            "distance_km": round(float(route.get("distance", 0)) / 1000, 2),
            "duration_min": max(1, round(float(route.get("duration", 0)) / 60)),
        }
    except Exception:
        return None


def _fetch_json(url: str) -> dict:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=8) as response:
        return json.loads(response.read().decode("utf-8"))


def _fallback_route(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> dict:
    return {
        "polyline": [[origin_lat, origin_lng], [dest_lat, dest_lng]],
        "distance_km": 0,
        "duration_min": 1,
    }


def _read_cache(key: str) -> dict | None:
    cached = _cache.get(key)
    if cached is None:
        return None
    expires_at, payload = cached
    if datetime.utcnow() >= expires_at:
        _cache.pop(key, None)
        return None
    return payload


def _write_cache(key: str, payload: dict) -> None:
    _cache[key] = (datetime.utcnow() + CACHE_TTL, payload)
