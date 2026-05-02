from datetime import date, datetime, time

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import gone
from app.core.security import get_current_client, get_current_driver, get_current_user
from app.db.database import get_db_session
from app.models.ride_request import RideRequestStatus
from app.models.user import User
from app.schemas.pricing import PriceEstimateRead
from app.schemas.ride_request import (
    ClientRideRequestStatsRead,
    ClientRideRatingCreate,
    PublicRideTrackingRead,
    PublicTrackingDriverRead,
    PublicTrackingPositionRead,
    RideMessageCreate,
    RideMessagePageRead,
    RideMessageRead,
    RideShareLinkRead,
    DriverRideRatingCreate,
    RideRequestCancel,
    RideRequestComplete,
    RideRequestCreate,
    RideRequestReject,
    DriverRideRequestStatsRead,
    RevenueStatsRead,
    RideRequestRead,
    RideRequestStatsRead,
    TopDriverStatsRead,
)
from app.schemas.ride_report import (
    RideReportCreate,
    RideReportCreateBody,
    RideReportRead,
)
from app.services.ride_message_service import (
    create_ride_message,
    list_ride_messages,
)
from app.services.ride_report_service import (
    RideReportForbiddenError,
    RideReportNotFoundError,
    create_report,
)
from app.services.ride_request_service import (
    RideRequestAlreadyRatedError,
    RideRequestExpiredError,
    RideRequestNotCompletedError,
    RideRequestNotPendingError,
    RideRequestNotFoundError,
    RideRequestRatingNotAllowedError,
    arrive_ride_request,
    cancel_ride_request,
    complete_ride_request,
    create_ride_share_link,
    create_ride_request,
    get_public_ride_tracking,
    get_active_ride_request,
    get_client_ride_request_stats,
    get_client_ride_history,
    get_available_ride_requests,
    get_driver_ride_history,
    get_driver_ride_request_stats,
    get_ride_request_by_id,
    get_ride_request_stats,
    get_revenue_stats,
    get_top_drivers,
    list_ride_requests,
    rate_client_for_ride,
    rate_driver_for_ride,
    reject_ride_request,
    start_ride_request,
)
from app.services.ride_lifecycle_service import estimate_ride_preview

router = APIRouter(prefix="/ride-requests", tags=["ride_requests"])
estimate_router = APIRouter(prefix="/rides", tags=["rides"])
public_track_router = APIRouter(tags=["public_tracking"])


@estimate_router.get("/estimate", response_model=PriceEstimateRead)
async def estimate_ride_request_endpoint(
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


@router.get("", response_model=list[RideRequestRead])
async def list_ride_requests_endpoint(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
    status: RideRequestStatus | None = None,
    limit: int = Query(default=100, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[RideRequestRead]:
    ride_requests = await list_ride_requests(
        session=session,
        client_id=current_user.id if current_user.role.value == "client" else None,
        driver_id=current_user.id if current_user.role.value == "driver" else None,
        status=status,
        limit=limit,
        offset=offset,
    )
    return [RideRequestRead.model_validate(ride_request) for ride_request in ride_requests]


@router.get("/stats", response_model=RideRequestStatsRead)
async def get_ride_request_stats_endpoint(
    _current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestStatsRead:
    return await get_ride_request_stats(session)


@router.get("/stats/top-drivers", response_model=list[TopDriverStatsRead])
async def get_top_drivers_endpoint(
    _current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=5, ge=1, le=20),
) -> list[TopDriverStatsRead]:
    return await get_top_drivers(session, limit=limit)


@router.get("/stats/revenue", response_model=RevenueStatsRead)
async def get_revenue_stats_endpoint(
    _current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
) -> RevenueStatsRead:
    return await get_revenue_stats(
        session,
        date_from=(
            datetime.combine(date_from, time.min) if date_from is not None else None
        ),
        date_to=datetime.combine(date_to, time.max) if date_to is not None else None,
        filter_date_from=date_from,
        filter_date_to=date_to,
    )


@router.get("/stats/driver/me", response_model=DriverRideRequestStatsRead)
async def get_driver_ride_request_stats_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> DriverRideRequestStatsRead:
    return await get_driver_ride_request_stats(session, current_user.id)


@router.get("/stats/client/me", response_model=ClientRideRequestStatsRead)
async def get_client_ride_request_stats_endpoint(
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> ClientRideRequestStatsRead:
    return await get_client_ride_request_stats(session, current_user.id)


@router.get("/stats/driver/{driver_id}", response_model=DriverRideRequestStatsRead)
async def get_driver_ride_request_stats_by_id_endpoint(
    driver_id: int,
    _current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> DriverRideRequestStatsRead:
    return await get_driver_ride_request_stats(session, driver_id)


@router.get("/client/me", response_model=list[RideRequestRead])
async def get_client_ride_history_endpoint(
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=100, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[RideRequestRead]:
    ride_requests = await get_client_ride_history(
        session=session,
        client_id=current_user.id,
        limit=limit,
        offset=offset,
    )
    return [RideRequestRead.model_validate(ride_request) for ride_request in ride_requests]


@router.get("/driver/me", response_model=list[RideRequestRead])
async def get_driver_ride_history_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=100, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[RideRequestRead]:
    ride_requests = await get_driver_ride_history(
        session=session,
        driver_id=current_user.id,
        limit=limit,
        offset=offset,
    )
    return [RideRequestRead.model_validate(ride_request) for ride_request in ride_requests]


@router.get("/available", response_model=list[RideRequestRead])
async def get_available_ride_requests_endpoint(
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=50, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
) -> list[RideRequestRead]:
    ride_requests = await get_available_ride_requests(
        session=session,
        current_user=current_user,
        limit=limit,
        offset=offset,
    )
    return [RideRequestRead.model_validate(ride_request) for ride_request in ride_requests]


@router.get("/active", response_model=RideRequestRead | None)
async def get_active_ride_request_endpoint(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead | None:
    ride_request = await get_active_ride_request(session, current_user)
    if ride_request is None:
        return None
    return RideRequestRead.model_validate(ride_request)


@router.post("/", response_model=RideRequestRead, status_code=status.HTTP_201_CREATED)
async def create_ride_request_endpoint(
    ride_request_in: RideRequestCreate,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    ride_request = await create_ride_request(session, ride_request_in, current_user)
    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/share-link", response_model=RideShareLinkRead)
async def create_ride_share_link_endpoint(
    ride_request_id: int,
    request: Request,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> RideShareLinkRead:
    token, relative_tracking_url = await create_ride_share_link(
        session,
        ride_id=ride_request_id,
        current_user=current_user,
    )
    tracking_url = str(request.base_url).rstrip("/") + relative_tracking_url
    return RideShareLinkRead(
        token=token,
        tracking_url=tracking_url,
    )


@router.patch("/{ride_request_id}/cancel", response_model=RideRequestRead)
@router.post("/{ride_request_id}/cancel", response_model=RideRequestRead)
async def cancel_ride_request_endpoint(
    ride_request_id: int,
    ride_request_cancel_in: RideRequestCancel,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    ride_request = await cancel_ride_request(
        session,
        ride_request_id,
        current_user,
        ride_request_cancel_in,
    )
    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/report", response_model=RideReportRead)
async def report_ride_request_endpoint(
    ride_request_id: int,
    report_in: RideReportCreateBody,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideReportRead:
    try:
        report = await create_report(
            session,
            current_user,
            RideReportCreate(
                ride_request_id=ride_request_id,
                reason=report_in.reason,
                description=report_in.description,
            ),
        )
    except RideReportNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideReportForbiddenError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc
    return RideReportRead.model_validate(report)


@router.post("/{ride_request_id}/messages", response_model=RideMessageRead)
async def create_ride_message_endpoint(
    ride_request_id: int,
    message_in: RideMessageCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideMessageRead:
    return await create_ride_message(
        session=session,
        ride_request_id=ride_request_id,
        current_user=current_user,
        message_in=message_in,
    )


@router.get("/{ride_request_id}/messages", response_model=RideMessagePageRead)
async def list_ride_messages_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    mark_read: bool = Query(default=True),
) -> RideMessagePageRead:
    return await list_ride_messages(
        session=session,
        ride_request_id=ride_request_id,
        current_user=current_user,
        limit=limit,
        offset=offset,
        mark_read=mark_read,
    )


@router.post("/{ride_request_id}/reject", response_model=RideRequestRead)
async def reject_ride_request_endpoint(
    ride_request_id: int,
    ride_request_reject_in: RideRequestReject,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await reject_ride_request(
            session,
            ride_request_id,
            current_user,
            ride_request_reject_in,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestExpiredError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except RideRequestNotPendingError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    return RideRequestRead.model_validate(ride_request)


@router.get("/{ride_request_id}", response_model=RideRequestRead)
async def get_ride_request_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    ride_request = await get_ride_request_by_id(session, ride_request_id)
    if ride_request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ride request not found",
        )

    if current_user.id not in {ride_request.client_id, ride_request.driver_id}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied",
        )

    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/accept", response_model=RideRequestRead)
async def accept_ride_request_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    del ride_request_id, current_user, session
    raise gone(
        "ride_direct_accept_disabled",
        "Direct ride acceptance is disabled. Drivers must create an offer and clients accept the winning offer.",
    )


@router.post("/{ride_request_id}/start", response_model=RideRequestRead)
async def start_ride_request_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    ride_request = await start_ride_request(
        session,
        ride_request_id,
        current_user,
    )
    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/arrive", response_model=RideRequestRead)
async def arrive_ride_request_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    ride_request = await arrive_ride_request(
        session,
        ride_request_id,
        current_user,
    )
    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/complete", response_model=RideRequestRead)
async def complete_ride_request_endpoint(
    ride_request_id: int,
    ride_request_complete_in: RideRequestComplete | None = None,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    ride_request = await complete_ride_request(
        session,
        ride_request_id,
        current_user,
        ride_request_complete_in,
    )
    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/rate-driver", response_model=RideRequestRead)
async def rate_driver_for_ride_endpoint(
    ride_request_id: int,
    rating_in: ClientRideRatingCreate,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await rate_driver_for_ride(
            session,
            ride_request_id,
            current_user,
            rating_in,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestNotCompletedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except RideRequestRatingNotAllowedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc
    except RideRequestAlreadyRatedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/rate-client", response_model=RideRequestRead)
async def rate_client_for_ride_endpoint(
    ride_request_id: int,
    rating_in: DriverRideRatingCreate,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await rate_client_for_ride(
            session,
            ride_request_id,
            current_user,
            rating_in,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestNotCompletedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except RideRequestRatingNotAllowedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc
    except RideRequestAlreadyRatedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    return RideRequestRead.model_validate(ride_request)


@public_track_router.get("/track/{token}", response_model=PublicRideTrackingRead)
async def public_track_ride_endpoint(
    token: str,
    session: AsyncSession = Depends(get_db_session),
) -> PublicRideTrackingRead:
    payload = await get_public_ride_tracking(session, token=token)
    driver_payload = payload["driver"]
    position_payload = payload["driver_position"]
    return PublicRideTrackingRead(
        ride_id=int(payload["ride_id"]),
        status=payload["status"],
        driver=PublicTrackingDriverRead(
            first_name=str(driver_payload["first_name"]),
            vehicle_model=driver_payload["vehicle_model"],
            plate_number=driver_payload["plate_number"],
        ),
        driver_position=(
            None
            if position_payload is None
            else PublicTrackingPositionRead(
                latitude=float(position_payload["latitude"]),
                longitude=float(position_payload["longitude"]),
            )
        ),
    )


@public_track_router.get("/track/{token}/map", response_class=HTMLResponse)
async def public_track_ride_map_endpoint(token: str) -> HTMLResponse:
    return HTMLResponse(content=_public_track_map_html(token))


def _public_track_map_html(token: str) -> str:
    return f"""<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Suivi de course - Noor Express</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
  <style>
    :root {{
      color-scheme: light;
      --bg: #f5f7fb;
      --card: #ffffff;
      --ink: #0f172a;
      --muted: #64748b;
      --accent: #0f766e;
      --border: #dbe4ee;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--ink);
    }}
    main {{
      max-width: 760px;
      margin: 0 auto;
      padding: 16px;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }}
    .card {{
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 14px;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08);
    }}
    .title {{
      font-size: 18px;
      font-weight: 800;
      margin: 0 0 4px;
    }}
    .muted {{
      color: var(--muted);
      margin: 0;
      font-size: 13px;
    }}
    .status {{
      margin-top: 10px;
      display: inline-block;
      background: rgba(15, 118, 110, 0.1);
      color: var(--accent);
      border-radius: 999px;
      padding: 6px 10px;
      font-weight: 700;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }}
    .grid {{
      margin-top: 12px;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }}
    .label {{
      color: var(--muted);
      font-size: 12px;
      margin-bottom: 3px;
    }}
    .value {{
      font-weight: 700;
    }}
    #map {{
      width: 100%;
      min-height: 360px;
      border-radius: 16px;
      border: 1px solid var(--border);
      overflow: hidden;
      background: #e6eef8;
    }}
    .error {{
      color: #b91c1c;
      font-size: 13px;
      font-weight: 600;
      margin-top: 10px;
    }}
    @media (max-width: 560px) {{
      .grid {{
        grid-template-columns: 1fr;
      }}
      #map {{
        min-height: 300px;
      }}
    }}
  </style>
</head>
<body>
  <main>
    <section class="card">
      <h1 class="title">Suivi de la course</h1>
      <p class="muted">Mise a jour automatique toutes les 5 secondes.</p>
      <span id="status" class="status">Chargement</span>
      <div class="grid">
        <div>
          <div class="label">Chauffeur</div>
          <div id="driver-name" class="value">-</div>
        </div>
        <div>
          <div class="label">Vehicule</div>
          <div id="vehicle-model" class="value">-</div>
        </div>
        <div>
          <div class="label">Plaque</div>
          <div id="plate-number" class="value">-</div>
        </div>
      </div>
      <p id="error" class="error" hidden></p>
    </section>
    <div id="map"></div>
  </main>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    const trackingToken = {token!r};
    const statusElement = document.getElementById('status');
    const driverNameElement = document.getElementById('driver-name');
    const vehicleModelElement = document.getElementById('vehicle-model');
    const plateNumberElement = document.getElementById('plate-number');
    const errorElement = document.getElementById('error');

    const map = L.map('map', {{ zoomControl: true }}).setView([13.5116, 2.1254], 13);
    L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png', {{
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap',
    }}).addTo(map);

    let marker = null;
    let lastStatus = null;
    let pollingHandle = null;

    async function loadTracking() {{
      try {{
        const response = await fetch(`/track/${{trackingToken}}`, {{ cache: 'no-store' }});
        if (!response.ok) {{
          throw new Error(response.status === 404
            ? 'Ce lien n est plus actif.'
            : response.status === 429
              ? 'Trop de requetes. Reessayez dans quelques secondes.'
              : 'Impossible de recuperer le suivi.');
        }}
        const payload = await response.json();
        renderPayload(payload);
      }} catch (error) {{
        showError(error.message || 'Impossible de recuperer le suivi.');
      }}
    }}

    function renderPayload(payload) {{
      hideError();
      statusElement.textContent = payload.status;
      driverNameElement.textContent = payload.driver.first_name || '-';
      vehicleModelElement.textContent = payload.driver.vehicle_model || '-';
      plateNumberElement.textContent = payload.driver.plate_number || '-';

      if (payload.driver_position) {{
        const lat = payload.driver_position.latitude;
        const lng = payload.driver_position.longitude;
        if (!marker) {{
          marker = L.marker([lat, lng]).addTo(map);
        }} else {{
          marker.setLatLng([lat, lng]);
        }}
        map.setView([lat, lng], map.getZoom() < 14 ? 14 : map.getZoom());
      }}

      if (lastStatus !== payload.status && ['completed', 'cancelled', 'expired'].includes(payload.status)) {{
        showError('Cette course est terminee.');
      }}
      lastStatus = payload.status;
    }}

    function showError(message) {{
      errorElement.hidden = false;
      errorElement.textContent = message;
    }}

    function hideError() {{
      errorElement.hidden = true;
      errorElement.textContent = '';
    }}

    function startPolling() {{
      if (pollingHandle !== null) {{
        window.clearInterval(pollingHandle);
      }}
      loadTracking();
      pollingHandle = window.setInterval(loadTracking, 5000);
    }}

    startPolling();
  </script>
</body>
</html>
"""
