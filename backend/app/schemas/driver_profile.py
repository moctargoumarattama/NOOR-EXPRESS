from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.driver_profile import DriverVerificationStatus


class DriverProfileCreate(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    address: str | None = None
    id_card_photo: str | None = None
    selfie_photo: str | None = None


class DriverProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    first_name: str
    last_name: str
    address: str | None
    id_card_photo: str | None
    selfie_photo: str | None
    verification_status: DriverVerificationStatus
    rejection_reason: str | None
    submitted_at: datetime | None
    verified_at: datetime | None


class DriverProfileAdminRead(DriverProfileRead):
    phone_number: str
    user_name: str | None = None


class DriverRejectRequest(BaseModel):
    reason: str = Field(min_length=2, max_length=500)
