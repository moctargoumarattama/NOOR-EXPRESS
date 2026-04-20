from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_client, get_current_user
from app.db.database import get_db_session
from app.models.user import User
from app.schemas.user import ClientProfileRead, ClientProfileUpdate, UserCreate, UserRead
from app.services.user_service import (
    UserPhoneAlreadyExistsError,
    create_user,
    get_client_profile,
    get_user_by_id,
    update_client_profile,
)

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def create_user_endpoint(
    user_in: UserCreate,
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    try:
        user = await create_user(session, user_in)
    except UserPhoneAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    return UserRead.model_validate(user)


@router.get("/me", response_model=UserRead)
async def get_current_user_endpoint(
    current_user: User = Depends(get_current_user),
) -> UserRead:
    return UserRead.model_validate(current_user)


@router.get("/me/profile", response_model=ClientProfileRead)
async def get_current_client_profile_endpoint(
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> ClientProfileRead:
    profile = await get_client_profile(session, current_user.id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client profile not found",
        )
    return profile


@router.put("/me/profile", response_model=ClientProfileRead)
async def update_current_client_profile_endpoint(
    profile_in: ClientProfileUpdate,
    current_user: User = Depends(get_current_client),
    session: AsyncSession = Depends(get_db_session),
) -> ClientProfileRead:
    profile = await update_client_profile(session, current_user.id, profile_in)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client profile not found",
        )
    return profile


@router.get("/{user_id}", response_model=UserRead)
async def get_user_endpoint(
    user_id: int,
    session: AsyncSession = Depends(get_db_session),
) -> UserRead:
    user = await get_user_by_id(session, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserRead.model_validate(user)
