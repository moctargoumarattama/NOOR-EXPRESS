from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user
from app.db.database import get_db_session
from app.models.user import User

router = APIRouter(prefix="/notifications", tags=["notifications"])


class FcmTokenCreate(BaseModel):
    fcm_token: str = Field(min_length=20, max_length=500)


class NotificationTokenResponse(BaseModel):
    message: str


@router.post(
    "/token",
    response_model=NotificationTokenResponse,
    status_code=status.HTTP_200_OK,
)
async def register_fcm_token_endpoint(
    token_in: FcmTokenCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> NotificationTokenResponse:
    current_user.fcm_token = token_in.fcm_token
    await session.commit()
    return NotificationTokenResponse(message="FCM token saved")
