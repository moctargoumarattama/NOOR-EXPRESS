from datetime import datetime
from enum import Enum

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SqlEnum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class UserRole(str, Enum):
    DRIVER = "driver"
    CLIENT = "client"


class DriverStatus(str, Enum):
    OFFLINE = "offline"
    ONLINE = "online"
    PAUSED = "paused"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    phone_number: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    profile_photo: Mapped[str | None] = mapped_column(MEDIUMTEXT, nullable=True)
    role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole), nullable=False)
    refresh_token: Mapped[str | None] = mapped_column(String(255), nullable=True)
    fcm_token: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_blocked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_suspended: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    deletion_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    suspended_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    suspension_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    cancellations_today: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    cancellations_last_24h: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    cancellation_window_started_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )
    ride_request_blocked_until: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )
    vehicle_brand: Mapped[str | None] = mapped_column(String(100), nullable=True)
    vehicle_model: Mapped[str | None] = mapped_column(String(100), nullable=True)
    vehicle_color: Mapped[str | None] = mapped_column(String(50), nullable=True)
    vehicle_photo: Mapped[str | None] = mapped_column(MEDIUMTEXT, nullable=True)
    plate_number: Mapped[str | None] = mapped_column(String(30), nullable=True)
    max_radius_km: Mapped[int | None] = mapped_column(Integer, nullable=True, default=5)
    last_known_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_known_lon: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_position_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_available: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    pause_started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    driver_status: Mapped[DriverStatus | None] = mapped_column(
        SqlEnum(
            DriverStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )


class SavedAddress(Base):
    __tablename__ = "saved_addresses"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lon: Mapped[float] = mapped_column(Float, nullable=False)
    address_display: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )


class UserSuspension(Base):
    __tablename__ = "user_suspensions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    suspended_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )
    suspended_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    lifted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
