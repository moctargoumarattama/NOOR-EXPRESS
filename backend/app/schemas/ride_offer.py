from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.ride_offer import RideOfferStatus


class RideOfferCreate(BaseModel):
    ride_request_id: int
    proposed_price: float = Field(gt=0)

    @field_validator("proposed_price", mode="before")
    @classmethod
    def parse_price(cls, value: object) -> float:
        return _round_price(value)


class RideOfferRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ride_request_id: int
    driver_id: int
    proposed_price: float
    status: RideOfferStatus
    created_at: datetime
    responded_at: datetime | None

    @field_validator("proposed_price", mode="before")
    @classmethod
    def parse_price(cls, value: object) -> float:
        return _round_price(value)


class RideOfferDriverRead(BaseModel):
    offer_id: int
    driver_id: int
    driver_name: str
    driver_rating: float
    vehicle_brand: str | None
    vehicle_model: str | None
    vehicle_color: str | None
    plate_number: str | None
    proposed_price: float
    driver_distance_km: float | None
    status: RideOfferStatus
    created_at: datetime

    @field_validator("proposed_price", mode="before")
    @classmethod
    def parse_price(cls, value: object) -> float:
        return _round_price(value)


def _round_price(value: object) -> float:
    return round(float(value), 2)
