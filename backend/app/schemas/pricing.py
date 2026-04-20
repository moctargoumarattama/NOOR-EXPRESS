from datetime import datetime, time
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class PricingSettingsRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    active_mode: str
    price_per_km: Decimal
    minimum_price: Decimal
    platform_commission_percent: Decimal
    long_ride_threshold_minutes: int
    long_ride_minimum_price: Decimal
    updated_at: datetime


class PricingSettingsUpdate(BaseModel):
    active_mode: str | None = Field(default=None, pattern="^(distance|zone|mixed)$")
    price_per_km: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    minimum_price: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    platform_commission_percent: Decimal | None = Field(default=None, ge=0, le=100)
    long_ride_threshold_minutes: int | None = Field(default=None, ge=1)
    long_ride_minimum_price: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)


class PricingZoneRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str | None = None
    base_price: Decimal
    price_per_km: Decimal
    latitude: float
    longitude: float
    radius_km: float
    is_active: bool
    created_at: datetime


class PricingZoneCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    description: str | None = Field(default=None, max_length=255)
    base_price: Decimal = Field(default=Decimal("500.00"), gt=0, max_digits=10, decimal_places=2)
    price_per_km: Decimal = Field(default=Decimal("300.00"), gt=0, max_digits=10, decimal_places=2)
    latitude: float
    longitude: float
    radius_km: float = Field(gt=0)
    is_active: bool = True


class PricingZoneUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    description: str | None = Field(default=None, max_length=255)
    base_price: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    price_per_km: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    latitude: float | None = None
    longitude: float | None = None
    radius_km: float | None = Field(default=None, gt=0)
    is_active: bool | None = None


class ZoneFareRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    origin_zone_id: int
    destination_zone_id: int
    fixed_price: Decimal
    is_active: bool
    created_at: datetime
    origin_zone_name: str | None = None
    destination_zone_name: str | None = None


class ZoneFareCreate(BaseModel):
    origin_zone_id: int
    destination_zone_id: int
    fixed_price: Decimal = Field(gt=0, max_digits=10, decimal_places=2)
    is_active: bool = True


class ZoneFareUpdate(BaseModel):
    origin_zone_id: int | None = None
    destination_zone_id: int | None = None
    fixed_price: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    is_active: bool | None = None


class TimePricingRuleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    start_time: time
    end_time: time
    surcharge_type: str
    surcharge_value: Decimal
    is_active: bool
    created_at: datetime


class TimePricingRuleCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    start_time: time
    end_time: time
    surcharge_type: str = Field(pattern="^(fixed|percent)$")
    surcharge_value: Decimal = Field(ge=0, max_digits=10, decimal_places=2)
    is_active: bool = True


class TimePricingRuleUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    start_time: time | None = None
    end_time: time | None = None
    surcharge_type: str | None = Field(default=None, pattern="^(fixed|percent)$")
    surcharge_value: Decimal | None = Field(default=None, ge=0, max_digits=10, decimal_places=2)
    is_active: bool | None = None


class PriceEstimateRead(BaseModel):
    estimated_price: float
    distance_km: float
    pickup_zone: str | None
    dropoff_zone: str | None
    base_price: float
    price_per_km: float
    applied_mode: str
    applied_zone_rule: dict | None = None
    applied_time_rule: dict | None = None
    platform_commission_preview: float


class PricingPreviewRequest(BaseModel):
    distance_km: Decimal | None = Field(default=None, ge=0)
    pickup_zone_id: int | None = None
    dropoff_zone_id: int | None = None
    request_datetime: datetime | None = None
    estimated_duration_minutes: int | None = Field(default=None, ge=0)

    @field_validator("distance_km", mode="before")
    @classmethod
    def parse_distance(cls, value: object) -> Decimal | None:
        if value is None or value == "":
            return None
        return Decimal(str(value))
