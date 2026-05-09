from datetime import datetime
import re

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator

from app.core.messages import Messages
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
            raise ValueError(Messages.PHONE_NUMBER_EMPTY)

        digits_only = phone_number[1:] if phone_number.startswith("+") else phone_number
        if not re.fullmatch(r"\+?\d+", phone_number) or not 8 <= len(digits_only) <= 15:
            raise ValueError(Messages.PHONE_NUMBER_INVALID)

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
    vehicle_photo: str | None = None
    plate_number: str | None
    max_radius_km: int | None = None
    is_available: bool | None
    pause_started_at: datetime | None = None
    driver_status: DriverStatus | None
    created_at: datetime

    @computed_field
    @property
    def first_name(self) -> str | None:
        raw_name = (self.name or "").strip()
        if not raw_name:
            return None
        return raw_name.split()[0]


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
    vehicle_photo: str | None = None
    plate_number: str | None = None


class DriverAvailabilityUpdate(BaseModel):
    is_available: bool


class DriverRadiusUpdate(BaseModel):
    max_radius_km: int = Field(ge=1, le=10)


class DriverStatusUpdate(BaseModel):
    status: DriverStatus


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


class SavedAddressCreate(BaseModel):
    label: str
    lat: float
    lon: float
    address_display: str

    @field_validator("label")
    @classmethod
    def validate_label(cls, value: str) -> str:
        label = value.strip()
        if not label:
            raise ValueError(Messages.LABEL_EMPTY)
        return label

    @field_validator("address_display")
    @classmethod
    def validate_address_display(cls, value: str) -> str:
        address_display = value.strip()
        if not address_display:
            raise ValueError(Messages.ADDRESS_DISPLAY_EMPTY)
        return address_display

    @field_validator("lat")
    @classmethod
    def validate_latitude(cls, value: float) -> float:
        if value < -90 or value > 90:
            raise ValueError(Messages.LATITUDE_OUT_OF_RANGE)
        return value

    @field_validator("lon")
    @classmethod
    def validate_longitude(cls, value: float) -> float:
        if value < -180 or value > 180:
            raise ValueError(Messages.LONGITUDE_OUT_OF_RANGE)
        return value


class SavedAddressUpdate(SavedAddressCreate):
    pass


class SavedAddressRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    label: str
    lat: float
    lon: float
    address_display: str
    created_at: datetime
