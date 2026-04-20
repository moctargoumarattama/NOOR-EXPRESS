from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.ride_request import RideRequestStatus
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
    reason: str | None = None


class RideRequestReject(BaseModel):
    reason: str | None = None


class RideRequestComplete(BaseModel):
    final_price: float | None = Field(
        default=None,
        gt=0,
    )

    @field_validator("final_price", mode="before")
    @classmethod
    def parse_final_price(cls, value: object) -> float | None:
        return _round_optional_price(value)


class ClientRideRatingCreate(BaseModel):
    rating: float = Field(ge=1, le=5)
    comment: str | None = None


class DriverRideRatingCreate(BaseModel):
    rating: float = Field(ge=1, le=5)
    comment: str | None = None


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
    estimated_price: float
    final_price: float | None
    platform_commission: float | None
    driver_net_earnings: float | None
    client_rating_for_driver: float | None
    client_rating_comment: str | None
    driver_rating_for_client: float | None
    driver_rating_comment: str | None
    cancellation_reason: str | None
    cancelled_by_role: UserRole | None
    status: RideRequestStatus
    created_at: datetime

    @field_validator(
        "estimated_price",
        "final_price",
        "platform_commission",
        "driver_net_earnings",
        mode="before",
    )
    @classmethod
    def parse_price_fields(cls, value: object) -> float | None:
        return _round_optional_price(value)


class RideRequestStatsRead(BaseModel):
    total_rides: int
    pending: int
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


def _round_optional_price(value: object) -> float | None:
    if value is None:
        return None
    return round(float(value), 2)
