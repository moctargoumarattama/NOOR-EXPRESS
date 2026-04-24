from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.append(str(Path(__file__).resolve().parents[1]))

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app.api.admin import router as admin_router
from app.api.admin_pricing import router as admin_pricing_router
from app.api.auth import router as auth_router
from app.api.driver import router as driver_router
from app.api.driver_profile import router as driver_profile_router
from app.api.geocoding import router as geocoding_router
from app.api.notifications import router as notifications_router
from app.api.pricing import router as pricing_router
from app.api.realtime import router as realtime_router
from app.api.routing import router as routing_router
from app.api.ride_offer import router as ride_offer_router
from app.api.ride_request import router as ride_request_router
from app.api.user import router as user_router
from app.core.api_errors import (
    ApiError,
    api_error_response,
    http_exception_response,
)
from app.db.schema_bootstrap import ensure_database_schema


class RootResponse(BaseModel):
    message: str


app = FastAPI(title="Noor Express API")
# TODO(prod): remplacer "*" par les domaines frontend Noor Express autorises.
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
app.include_router(admin_router)
app.include_router(admin_pricing_router)
app.include_router(auth_router)
app.include_router(driver_router)
app.include_router(driver_profile_router)
app.include_router(geocoding_router)
app.include_router(notifications_router)
app.include_router(pricing_router)
app.include_router(realtime_router)
app.include_router(routing_router)
app.include_router(ride_offer_router)
app.include_router(ride_request_router)
app.include_router(user_router)


@app.on_event("startup")
async def bootstrap_database_schema() -> None:
    await ensure_database_schema()


@app.exception_handler(ApiError)
async def api_error_handler(_request: Request, exc: ApiError):
    return api_error_response(exc)


@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException):
    return http_exception_response(exc)


@app.get("/")
def read_root() -> RootResponse:
    return RootResponse(message="Noor Express API running")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000, http="httptools")
