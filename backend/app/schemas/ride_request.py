from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.messages import Messages
from app.models.ride_request import RideCancelledByRole, RideRequestStatus
from app.models.user import UserRole


class RideRequestCreate(BaseModel):
    pickup_location: str
    dropoff_location: str
    client_latitude: float
    client_longitude: float
    dropoff_latitude: float
    dropoff_longitude: float
    estimated_price: float | None = Field(
        default=None,
        gt=0,
    )

    @field_validator("estimated_price", mode="before")
    @classmethod
    def parse_estimated_price(cls, value: object) -> float | None:
        return _round_optional_price(value)


class RideRequestCancel(BaseModel):
    reason: str | None = Field(default=None, max_length=200)
    reason_code: str | None = Field(default=None, max_length=40)

    @field_validator("reason", "reason_code", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: object) -> str | None:
        if value is None:
            return None
        if not isinstance(value, str):
            raise TypeError(
                Messages.FIELD_MUST_BE_STRING_TEMPLATE.format(field_name="value")
            )
        trimmed = value.strip()
        return trimmed or None


class RideRequestReject(BaseModel):
    reason: str | None = None


class RideRequestComplete(BaseModel):
    pass


class RideMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=500)

    @field_validator("content", mode="before")
    @classmethod
    def normalize_content(cls, value: object) -> str:
        if not isinstance(value, str):
            raise TypeError(
                Messages.FIELD_MUST_BE_STRING_TEMPLATE.format(field_name="content")
            )
        return value.strip()

    @field_validator("content")
    @classmethod
    def ensure_non_empty_content(cls, value: str) -> str:
        if not value:
            raise ValueError(Messages.CONTENT_EMPTY)
        return value


class ClientRideRatingCreate(BaseModel):
    rating: float = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=220)

    @field_validator("comment", mode="before")
    @classmethod
    def normalize_comment(cls, value: object) -> str | None:
        if value is None:
            return None
        if not isinstance(value, str):
            raise TypeError(
                Messages.FIELD_MUST_BE_STRING_TEMPLATE.format(field_name="comment")
            )
        trimmed = value.strip()
        return trimmed or None


class DriverRideRatingCreate(BaseModel):
    rating: float = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=220)

    @field_validator("comment", mode="before")
    @classmethod
    def normalize_comment(cls, value: object) -> str | None:
        if value is None:
            return None
        if not isinstance(value, str):
            raise TypeError(
                Messages.FIELD_MUST_BE_STRING_TEMPLATE.format(field_name="comment")
            )
        trimmed = value.strip()
        return trimmed or None


class RideRequestRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    client_id: int
    driver_id: int | None
    pickup_location: str
    dropoff_location: str
    pickup_latitude: float | None
    pickup_longitude: float | None
    dropoff_latitude: float | None
    dropoff_longitude: float | None
    distance_km: float | None
    duration_minutes: int | None
    estimated_price: float
    agreed_price: float | None
    final_price: float | None
    platform_commission: float | None
    driver_net_earnings: float | None
    client_rating_for_driver: float | None
    client_rating_comment: str | None
    driver_rating_for_client: float | None
    driver_rating_comment: str | None
    cancellation_reason: str | None
    cancelled_by_role: RideCancelledByRole | None
    status: RideRequestStatus
    created_at: datetime
    passenger_ready_at: datetime | None
    completed_at: datetime | None

    @field_validator(
        "estimated_price",
        "agreed_price",
        "final_price",
        "platform_commission",
        "driver_net_earnings",
        "distance_km",
        mode="before",
    )
    @classmethod
    def parse_price_fields(cls, value: object) -> float | None:
        return _round_optional_price(value)


class RideMessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ride_id: int
    sender_id: int
    sender_role: UserRole
    content: str
    is_read: bool
    created_at: datetime


class RideMessagePageRead(BaseModel):
    items: list[RideMessageRead]
    unread_count: int
    limit: int
    offset: int


class RideRequestStatsRead(BaseModel):
    total_rides: int
    pending: int
    offered: int
    accepted: int
    started: int
    completed: int
    cancelled: int
    expired: int
    average_estimated_price: float
    total_estimated_revenue_completed: float
    total_cancelled: int
    total_expired: int


class DriverRideRequestStatsRead(BaseModel):
    total_rides: int
    completed: int
    started: int
    cancelled: int
    total_earnings: float
    total_net_earnings: float
    average_completed_price: float
    average_rating_from_clients: float
    total_ratings_from_clients: int


class ClientRideRequestStatsRead(BaseModel):
    total_rides: int
    completed: int
    cancelled: int
    average_rating_from_drivers: float
    total_ratings_from_drivers: int


class TopDriverStatsRead(BaseModel):
    driver_id: int
    phone_number: str
    completed_rides: int
    total_earnings: float


class RevenueStatsRead(BaseModel):
    date_from: date | None
    date_to: date | None
    completed_rides: int
    total_revenue: float


class RideShareLinkRead(BaseModel):
    token: str
    tracking_url: str

    @field_validator("token")
    @classmethod
    def validate_token(cls, value: str) -> str:
        UUID(value)
        return value

    @field_validator("tracking_url")
    @classmethod
    def validate_tracking_url(cls, value: str) -> str:
        tracking_url = value.strip()
        if not tracking_url:
            raise ValueError(Messages.TRACKING_URL_EMPTY)
        return tracking_url


class PublicTrackingDriverRead(BaseModel):
    first_name: str
    vehicle_model: str | None
    plate_number: str | None


class PublicTrackingPositionRead(BaseModel):
    latitude: float
    longitude: float


class PublicRideTrackingRead(BaseModel):
    ride_id: int
    status: RideRequestStatus
    driver: PublicTrackingDriverRead
    driver_position: PublicTrackingPositionRead | None


def _round_optional_price(value: object) -> float | None:
    if value is None:
        return None
    return round(float(value), 2)
