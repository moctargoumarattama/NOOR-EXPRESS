from datetime import date, datetime, time

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_client, get_current_driver, get_current_user
from app.db.database import get_db_session
from app.models.ride_request import RideRequestStatus
from app.models.user import User
from app.schemas.ride_request import (
    ClientRideRequestStatsRead,
    ClientRideRatingCreate,
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
from app.services.ride_report_service import (
    RideReportForbiddenError,
    RideReportNotFoundError,
    create_report,
)
from app.services.ride_request_service import (
    RideRequestAlreadyRatedError,
    RideRequestCancellationNotAllowedError,
    RideRequestDriverNotConnectedError,
    RideRequestDriverMismatchError,
    RideRequestDriverNotFoundError,
    RideRequestExpiredError,
    RideRequestInvalidDriverError,
    RideRequestInvalidClientError,
    RideRequestNotAcceptedError,
    RideRequestNotArrivedError,
    RideRequestNotCompletedError,
    RideRequestNotPendingError,
    RideRequestNotFoundError,
    RideRequestNotStartedError,
    RideRequestRatingNotAllowedError,
    accept_ride_request,
    arrive_ride_request,
    cancel_ride_request,
    complete_ride_request,
    create_ride_request,
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

router = APIRouter(prefix="/ride-requests", tags=["ride_requests"])


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
    try:
        ride_requests = await get_available_ride_requests(
            session=session,
            current_user=current_user,
            limit=limit,
            offset=offset,
        )
    except RideRequestInvalidDriverError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

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
    try:
        ride_request = await create_ride_request(session, ride_request_in, current_user)
    except RideRequestInvalidClientError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/cancel", response_model=RideRequestRead)
async def cancel_ride_request_endpoint(
    ride_request_id: int,
    ride_request_cancel_in: RideRequestCancel,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await cancel_ride_request(
            session,
            ride_request_id,
            current_user,
            ride_request_cancel_in,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestCancellationNotAllowedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc

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
    except RideRequestDriverNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestInvalidDriverError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except RideRequestDriverNotConnectedError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
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
    try:
        ride_request = await accept_ride_request(
            session,
            ride_request_id,
            current_user,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestDriverNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestInvalidDriverError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
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


@router.post("/{ride_request_id}/start", response_model=RideRequestRead)
async def start_ride_request_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await start_ride_request(
            session,
            ride_request_id,
            current_user,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestDriverNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestInvalidDriverError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except RideRequestNotArrivedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except RideRequestDriverMismatchError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/arrive", response_model=RideRequestRead)
async def arrive_ride_request_endpoint(
    ride_request_id: int,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await arrive_ride_request(
            session,
            ride_request_id,
            current_user,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestInvalidDriverError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except RideRequestNotAcceptedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except RideRequestDriverMismatchError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return RideRequestRead.model_validate(ride_request)


@router.post("/{ride_request_id}/complete", response_model=RideRequestRead)
async def complete_ride_request_endpoint(
    ride_request_id: int,
    ride_request_complete_in: RideRequestComplete | None = None,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideRequestRead:
    try:
        ride_request = await complete_ride_request(
            session,
            ride_request_id,
            current_user,
            ride_request_complete_in,
        )
    except RideRequestNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestDriverNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except RideRequestInvalidDriverError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except RideRequestNotStartedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except RideRequestDriverMismatchError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

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
