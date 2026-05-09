import sys
import asyncio
from contextlib import suppress
from datetime import datetime, time, timedelta
from pathlib import Path

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parents[1]))

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app.api.admin import router as admin_router
from app.api.admin_pricing import router as admin_pricing_router
from app.api.admin_simulations import router as admin_simulations_router
from app.api.auth import router as auth_router
from app.api.driver import router as driver_router
from app.api.driver_profile import router as driver_profile_router
from app.api.geocoding import router as geocoding_router
from app.api.notifications import router as notifications_router
from app.api.pricing import router as pricing_router
from app.api.realtime import router as realtime_router
from app.api.routing import router as routing_router
from app.api.ride_offer import router as ride_offer_router
from app.api.ride_request import (
    estimate_router as rides_estimate_router,
    public_track_router,
    router as ride_request_router,
)
from app.api.user import config_router, legal_router, router as user_router
from app.core.api_errors import (
    ApiError,
    api_error_response,
    http_exception_response,
)
from app.core.firebase import is_firebase_ready
from app.db.database import AsyncSessionLocal
from app.db.schema_bootstrap import ensure_database_schema
from app.services.user_service import reset_daily_cancellation_counters


class RootResponse(BaseModel):
    message: str


app = FastAPI(title="Noor Express API")
_daily_cancellation_reset_task: asyncio.Task[None] | None = None
_uploads_dir = Path(__file__).resolve().parents[1] / "uploads"
_uploads_dir.mkdir(parents=True, exist_ok=True)
# En local, on autorise toutes les origines pour simplifier le developpement.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.mount(
    "/admin-panel",
    StaticFiles(directory=Path(__file__).resolve().parents[1] / "admin_panel", html=True),
    name="admin_panel",
)
app.mount("/uploads", StaticFiles(directory=_uploads_dir), name="uploads")
app.include_router(admin_router)
app.include_router(admin_pricing_router)
app.include_router(admin_simulations_router)
app.include_router(auth_router)
app.include_router(driver_router)
app.include_router(driver_profile_router)
app.include_router(geocoding_router)
app.include_router(notifications_router)
app.include_router(pricing_router)
app.include_router(realtime_router)
app.include_router(routing_router)
app.include_router(ride_offer_router)
app.include_router(rides_estimate_router)
app.include_router(ride_request_router)
app.include_router(public_track_router)
app.include_router(user_router)
app.include_router(config_router)
app.include_router(legal_router)


@app.on_event("startup")
async def bootstrap_database_schema() -> None:
    await ensure_database_schema()
    is_firebase_ready()
    global _daily_cancellation_reset_task
    if _daily_cancellation_reset_task is None:
        _daily_cancellation_reset_task = asyncio.create_task(
            _daily_cancellation_reset_loop()
        )


@app.on_event("shutdown")
async def shutdown_background_jobs() -> None:
    global _daily_cancellation_reset_task
    task = _daily_cancellation_reset_task
    _daily_cancellation_reset_task = None
    if task is None:
        return
    task.cancel()
    with suppress(asyncio.CancelledError):
        await task


@app.exception_handler(ApiError)
async def api_error_handler(_request: Request, exc: ApiError):
    return api_error_response(exc)


@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException):
    return http_exception_response(exc)


@app.get("/")
def read_root() -> RootResponse:
    return RootResponse(message="Noor Express API running")


async def _daily_cancellation_reset_loop() -> None:
    while True:
        await asyncio.sleep(_seconds_until_next_utc_midnight())
        async with AsyncSessionLocal() as session:
            await reset_daily_cancellation_counters(session)


def _seconds_until_next_utc_midnight(now: datetime | None = None) -> float:
    current = now or datetime.utcnow()
    next_day = current.date() + timedelta(days=1)
    next_midnight = datetime.combine(next_day, time.min)
    seconds = (next_midnight - current).total_seconds()
    return max(1.0, seconds)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000, http="httptools")
