import asyncio
import json
from datetime import datetime, timedelta
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel

from app.core.messages import Messages

router = APIRouter(prefix="/geocoding", tags=["geocoding"])

NOMINATIM_SEARCH_URL = "https://nominatim.openstreetmap.org/search"
NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"
USER_AGENT = "NoorExpress/1.0 contact@noorexpress.ne"
CACHE_TTL = timedelta(hours=1)


class GeocodingResult(BaseModel):
    name: str
    display_name: str
    lat: float
    lon: float
    type: str


NIAMEY_ZONES = [
    {"name": "Plateau", "lat": 13.5137, "lon": 2.1098, "type": "zone"},
    {"name": "Grand Marche", "lat": 13.5116, "lon": 2.1247, "type": "zone"},
    {"name": "Aeroport Diori Hamani", "lat": 13.4815, "lon": 2.1836, "type": "zone"},
    {"name": "Universite Abdou Moumouni", "lat": 13.5189, "lon": 2.0869, "type": "zone"},
    {"name": "Nouveau Marche", "lat": 13.5061, "lon": 2.1189, "type": "zone"},
    {"name": "Talladje", "lat": 13.4952, "lon": 2.1456, "type": "zone"},
    {"name": "Dar Es Salam", "lat": 13.5234, "lon": 2.0912, "type": "zone"},
    {"name": "Yantala", "lat": 13.5089, "lon": 2.0734, "type": "zone"},
    {"name": "Route de Tillaberi", "lat": 13.5312, "lon": 2.0623, "type": "zone"},
    {"name": "Terminus", "lat": 13.5198, "lon": 2.1312, "type": "zone"},
]

_cache: dict[str, tuple[datetime, list[dict]]] = {}


@router.get("/search", response_model=list[GeocodingResult])
async def search_address_endpoint(
    q: str = Query(min_length=1),
    limit: int = Query(default=5, ge=1, le=10),
) -> list[GeocodingResult]:
    cache_key = f"search:{q.lower().strip()}:{limit}"
    cached = _read_cache(cache_key)
    if cached is not None:
        return [GeocodingResult(**item) for item in cached]

    params = {
        "q": q,
        "format": "json",
        "countrycodes": "ne",
        "limit": str(limit),
    }
    results = await _request_nominatim(NOMINATIM_SEARCH_URL, params)
    normalized = [_normalize_search_item(item) for item in results[:limit]]
    normalized = [item for item in normalized if item is not None]
    if not normalized:
        normalized = _fallback_zones(q, limit)

    _write_cache(cache_key, normalized)
    return [GeocodingResult(**item) for item in normalized]


@router.get("/reverse", response_model=GeocodingResult)
async def reverse_address_endpoint(lat: float, lng: float) -> GeocodingResult:
    cache_key = f"reverse:{round(lat, 5)}:{round(lng, 5)}"
    cached = _read_cache(cache_key)
    if cached is not None and cached:
        return GeocodingResult(**cached[0])

    params = {
        "lat": str(lat),
        "lon": str(lng),
        "format": "json",
    }
    results = await _request_nominatim(NOMINATIM_REVERSE_URL, params)
    item = _normalize_reverse_item(results, lat, lng)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=Messages.LOCATION_NOT_FOUND,
        )
    _write_cache(cache_key, [item])
    return GeocodingResult(**item)


async def _request_nominatim(url: str, params: dict[str, str]) -> list | dict:
    full_url = f"{url}?{urlencode(params)}"
    try:
        return await asyncio.to_thread(_fetch_json, full_url)
    except Exception:
        return []


def _fetch_json(url: str) -> list | dict:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=6) as response:
        return json.loads(response.read().decode("utf-8"))


def _normalize_search_item(item: dict) -> dict | None:
    try:
        display_name = str(item.get("display_name") or "")
        name = str(item.get("name") or display_name.split(",")[0])
        return {
            "name": name,
            "display_name": display_name,
            "lat": float(item["lat"]),
            "lon": float(item["lon"]),
            "type": str(item.get("type") or "address"),
        }
    except (KeyError, TypeError, ValueError):
        return None


def _normalize_reverse_item(item: list | dict, lat: float, lng: float) -> dict | None:
    if not isinstance(item, dict):
        return None
    display_name = str(item.get("display_name") or "").strip()
    if not display_name:
        return None
    address = item.get("address") if isinstance(item.get("address"), dict) else {}
    name = str(
        address.get("suburb")
        or address.get("neighbourhood")
        or address.get("road")
        or display_name.split(",")[0]
    ).strip()
    if not name:
        return None
    return {
        "name": name,
        "display_name": display_name,
        "lat": lat,
        "lon": lng,
        "type": "current_location",
    }


def _fallback_zones(query: str, limit: int) -> list[dict]:
    needle = query.lower().strip()
    zones = [
        zone
        for zone in NIAMEY_ZONES
        if not needle or needle in zone["name"].lower()
    ]
    if not zones:
        zones = NIAMEY_ZONES
    return [
        {
            **zone,
            "display_name": f"{zone['name']}, Niamey, Niger",
        }
        for zone in zones[:limit]
    ]


def _read_cache(key: str) -> list[dict] | None:
    cached = _cache.get(key)
    if cached is None:
        return None
    expires_at, payload = cached
    if datetime.utcnow() >= expires_at:
        _cache.pop(key, None)
        return None
    return payload


def _write_cache(key: str, payload: list[dict]) -> None:
    _cache[key] = (datetime.utcnow() + CACHE_TTL, payload)
