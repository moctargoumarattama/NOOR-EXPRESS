from datetime import datetime
from enum import Enum

from decimal import Decimal

from sqlalchemy import DateTime, Enum as SqlEnum, Float, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class RideRequestStatus(str, Enum):
    PENDING = "pending"
    OFFERED = "offered"
    ACCEPTED = "accepted"
    ARRIVED = "arrived"
    STARTED = "started"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class RideCancelledByRole(str, Enum):
    PASSENGER = "passenger"
    DRIVER = "driver"
    SYSTEM = "system"


class RideRequest(Base):
    __tablename__ = "ride_requests"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    driver_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    pickup_location: Mapped[str] = mapped_column(String(255), nullable=False)
    dropoff_location: Mapped[str] = mapped_column(String(255), nullable=False)
    pickup_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    dropoff_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    dropoff_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_km: Mapped[float | None] = mapped_column(Float, nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    estimated_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    agreed_price: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    final_price: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    platform_commission: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    driver_net_earnings: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    client_rating_for_driver: Mapped[float | None] = mapped_column(Float, nullable=True)
    client_rating_comment: Mapped[str | None] = mapped_column(String(255), nullable=True)
    driver_rating_for_client: Mapped[float | None] = mapped_column(Float, nullable=True)
    driver_rating_comment: Mapped[str | None] = mapped_column(String(255), nullable=True)
    cancellation_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    cancelled_by_role: Mapped[RideCancelledByRole | None] = mapped_column(
        SqlEnum(
            RideCancelledByRole,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        nullable=True,
    )
    status: Mapped[RideRequestStatus] = mapped_column(
        SqlEnum(
            RideRequestStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        nullable=False,
        default=RideRequestStatus.PENDING,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )
    passenger_ready_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )
    share_token: Mapped[str | None] = mapped_column(
        String(36),
        nullable=True,
        unique=True,
        index=True,
    )
    share_token_created_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
    )
