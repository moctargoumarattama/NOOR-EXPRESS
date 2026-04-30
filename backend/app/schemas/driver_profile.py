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
    is_blocked: bool = False
    vehicle_brand: str | None = None
    vehicle_model: str | None = None
    vehicle_color: str | None = None
    plate_number: str | None = None


class DriverProfileAdminUpdate(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    phone_number: str = Field(min_length=3, max_length=20)
    user_name: str | None = Field(default=None, max_length=120)
    address: str | None = None
    vehicle_brand: str | None = Field(default=None, max_length=100)
    vehicle_model: str | None = Field(default=None, max_length=100)
    vehicle_color: str | None = Field(default=None, max_length=50)
    plate_number: str | None = Field(default=None, max_length=30)


class DriverRejectRequest(BaseModel):
    reason: str = Field(min_length=2, max_length=500)
