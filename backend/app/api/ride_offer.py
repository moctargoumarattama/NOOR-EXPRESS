from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_client, get_current_driver
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.ride_offer import RideOfferCreate, RideOfferDriverRead, RideOfferRead
from app.services.ride_offer_service import (
    RideOfferConflictError,
    RideOfferForbiddenError,
    RideOfferNotFoundError,
    accept_offer,
    create_offer,
    expire_ride_after_offer_timeout,
    get_offers_for_ride,
    reject_offer,
)

router = APIRouter(prefix="/ride-offers", tags=["ride_offers"])


@router.post("/", response_model=RideOfferDriverRead, status_code=status.HTTP_201_CREATED)
async def create_offer_endpoint(
    offer_in: RideOfferCreate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_driver),
    session: AsyncSession = Depends(get_db_session),
) -> RideOfferDriverRead:
    try:
        offer = await create_offer(
            session,
            ride_id=offer_in.ride_request_id,
            driver_id=current_user.id,
            proposed_price=offer_in.proposed_price,
        )
    except RideOfferNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RideOfferForbiddenError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RideOfferConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc

    background_tasks.add_task(expire_ride_after_offer_timeout, offer_in.ride_request_id)
    return offer


@router.get("/{ride_id}", response_model=list[RideOfferDriverRead])
async def get_offers_for_ride_endpoint(
    ride_id: int,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> list[RideOfferDriverRead]:
    try:
        return await get_offers_for_ride(session, ride_id, current_user.id)
    except RideOfferNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RideOfferForbiddenError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc


@router.post("/{offer_id}/accept", response_model=RideOfferRead)
async def accept_offer_endpoint(
    offer_id: int,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> RideOfferRead:
    try:
        offer = await accept_offer(session, offer_id, current_user.id)
    except RideOfferNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RideOfferForbiddenError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RideOfferConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return RideOfferRead.model_validate(offer)


@router.post("/{offer_id}/reject", response_model=RideOfferRead)
async def reject_offer_endpoint(
    offer_id: int,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> RideOfferRead:
    try:
        offer = await reject_offer(session, offer_id, current_user.id)
    except RideOfferNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    except RideOfferForbiddenError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except RideOfferConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return RideOfferRead.model_validate(offer)
