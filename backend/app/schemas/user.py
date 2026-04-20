from datetime import datetime
import re

from pydantic import BaseModel, ConfigDict, field_validator

from app.models.user import DriverStatus, UserRole


class UserCreate(BaseModel):
    phone_number: str
    role: UserRole
    name: str | None = None

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, value: str) -> str:
        phone_number = value.strip()
        if not phone_number:
            raise ValueError("Phone number cannot be empty")

        digits_only = phone_number[1:] if phone_number.startswith("+") else phone_number
        if not re.fullmatch(r"\+?\d+", phone_number) or not 8 <= len(digits_only) <= 15:
            raise ValueError("Phone number format is invalid")

        return phone_number


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    phone_number: str
    name: str | None
    profile_photo: str | None = None
    role: UserRole
    vehicle_brand: str | None
    vehicle_model: str | None
    vehicle_color: str | None
    plate_number: str | None
    is_available: bool | None
    driver_status: DriverStatus | None
    created_at: datetime


class UserLogin(BaseModel):
    phone_number: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"


class DriverProfileUpdate(BaseModel):
    name: str | None = None
    profile_photo: str | None = None
    vehicle_brand: str | None = None
    vehicle_model: str | None = None
    vehicle_color: str | None = None
    plate_number: str | None = None


class DriverAvailabilityUpdate(BaseModel):
    is_available: bool


class ClientProfileRead(BaseModel):
    id: int
    name: str | None
    phone_number: str
    profile_photo: str | None
    created_at: datetime
    total_rides: int
    average_rating: float


class ClientProfileUpdate(BaseModel):
    name: str | None = None
    profile_photo: str | None = None
