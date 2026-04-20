from datetime import datetime
from decimal import Decimal

from datetime import time
from enum import Enum

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Numeric, String, Time, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class PricingZone(Base):
    __tablename__ = "pricing_zones"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    base_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    price_per_km: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    radius_km: Mapped[float] = mapped_column(Float, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )


class PricingMode(str, Enum):
    DISTANCE = "distance"
    ZONE = "zone"
    MIXED = "mixed"


class TimeSurchargeType(str, Enum):
    FIXED = "fixed"
    PERCENT = "percent"


class PricingSettings(Base):
    __tablename__ = "pricing_settings"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    active_mode: Mapped[str] = mapped_column(String(20), nullable=False, default=PricingMode.MIXED.value)
    price_per_km: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, default=Decimal("300.00"))
    minimum_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, default=Decimal("1500.00"))
    platform_commission_percent: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False, default=Decimal("15.00"))
    long_ride_threshold_minutes: Mapped[int] = mapped_column(default=60, nullable=False)
    long_ride_minimum_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, default=Decimal("5000.00"))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class ZoneFare(Base):
    __tablename__ = "zone_fares"
    __table_args__ = (
        UniqueConstraint("origin_zone_id", "destination_zone_id", name="uq_zone_fares_pair"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    origin_zone_id: Mapped[int] = mapped_column(ForeignKey("pricing_zones.id"), nullable=False)
    destination_zone_id: Mapped[int] = mapped_column(ForeignKey("pricing_zones.id"), nullable=False)
    fixed_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), nullable=False)


class TimePricingRule(Base):
    __tablename__ = "time_pricing_rules"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    surcharge_type: Mapped[str] = mapped_column(String(20), nullable=False)
    surcharge_value: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), nullable=False)
