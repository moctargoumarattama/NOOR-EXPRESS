from typing import Any
from datetime import datetime

from pydantic import AliasChoices, BaseModel, Field


class DriverLocationUpdate(BaseModel):
    latitude: float = Field(validation_alias=AliasChoices("latitude", "lat"))
    longitude: float = Field(validation_alias=AliasChoices("longitude", "lng"))


class ConnectedDriverLocation(BaseModel):
    driver_id: int
    latitude: float
    longitude: float


class StoredDriverLocation(ConnectedDriverLocation):
    updated_at: datetime


class NearbyDriverLocation(BaseModel):
    driver_id: int
    latitude: float
    longitude: float
    distance_km: float


class RideStatusNotification(BaseModel):
    type: str = "status_update"
    ride_request_id: int
    status: str


class NewRideRequestNotification(BaseModel):
    type: str = "new_ride_request"
    ride_id: int
    ride_request_id: int
    pickup: str
    pickup_location: str
    dropoff: str
    dropoff_location: str
    client_price: float
    distance_km: float


class NewOfferDriverPayload(BaseModel):
    ride_id: int
    offer_id: int
    driver_id: int
    driver_name: str
    driver_rating: float
    proposed_price: float
    driver_distance_km: float | None
    driver_eta_minutes: int | None = None
    driver_completed_rides: int = 0
    driver_verified: bool = False
    vehicle_brand: str | None = None
    vehicle_model: str | None = None
    vehicle_color: str | None = None
    plate_number: str | None = None
    vehicle_photo: str | None = None


class NewOfferNotification(BaseModel):
    type: str = "new_offer"
    offer: NewOfferDriverPayload


class OfferAcceptedClientPayload(BaseModel):
    name: str
    pickup: str


class OfferAcceptedNotification(BaseModel):
    type: str = "offer_accepted"
    ride_id: int
    client: OfferAcceptedClientPayload


class OfferRejectedNotification(BaseModel):
    type: str = "offer_rejected"
    ride_id: int


class DriverPositionNotification(BaseModel):
    type: str = "driver_position_update"
    driver_id: int
    latitude: float
    longitude: float


class RideMessageNotification(BaseModel):
    type: str = "ride_message"
    ride_request_id: int
    message: dict[str, Any]


class PassengerReadyNotification(BaseModel):
    type: str = "passenger_ready"
    ride_id: str
    passenger_name: str
    timestamp: datetime
