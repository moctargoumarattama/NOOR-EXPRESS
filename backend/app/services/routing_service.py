import asyncio
import json
import logging
from datetime import datetime, timedelta
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from app.services.pricing_service import calculate_distance_km


OSRM_ROUTE_URL = "https://router.project-osrm.org/route/v1/driving"
USER_AGENT = "NoorExpress/1.0 contact@noorexpress.ne"
CACHE_TTL = timedelta(minutes=2)
FALLBACK_DISTANCE_MULTIPLIER = 1.3
FALLBACK_AVERAGE_SPEED_KMH = 30

_cache: dict[str, tuple[datetime, dict]] = {}
logger = logging.getLogger(__name__)


async def get_route_payload(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> dict:
    cache_key = _cache_key(origin_lat, origin_lng, dest_lat, dest_lng)
    cached = _read_cache(cache_key)
    if cached is not None:
        return cached

    payload = await fetch_osrm_route(origin_lat, origin_lng, dest_lat, dest_lng)
    if payload is None:
        payload = fallback_route(origin_lat, origin_lng, dest_lat, dest_lng)

    _write_cache(cache_key, payload)
    return payload


async def fetch_osrm_route(
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
        return _route_payload(routes[0])
    except Exception as exc:
        logger.warning(
            "OSRM route lookup failed for %s -> %s: %s",
            f"{origin_lat},{origin_lng}",
            f"{dest_lat},{dest_lng}",
            exc,
        )
        return None


def fallback_route(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> dict:
    distance_km = round(
        calculate_distance_km(
            origin_lat,
            origin_lng,
            dest_lat,
            dest_lng,
        )
        * FALLBACK_DISTANCE_MULTIPLIER,
        2,
    )
    return {
        "polyline": [[origin_lat, origin_lng], [dest_lat, dest_lng]],
        "distance_km": distance_km,
        "duration_min": max(
            1,
            round((distance_km / FALLBACK_AVERAGE_SPEED_KMH) * 60),
        ),
    }


def _route_payload(route: dict) -> dict | None:
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


def _fetch_json(url: str) -> dict:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=8) as response:
        return json.loads(response.read().decode("utf-8"))


def _cache_key(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> str:
    return (
        f"{round(origin_lat, 5)},{round(origin_lng, 5)}:"
        f"{round(dest_lat, 5)},{round(dest_lng, 5)}"
    )


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
