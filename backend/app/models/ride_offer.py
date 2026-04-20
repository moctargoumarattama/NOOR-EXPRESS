from datetime import datetime
from decimal import Decimal
from enum import Enum

from sqlalchemy import DateTime, Enum as SqlEnum, ForeignKey, Numeric, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class RideOfferStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class RideOffer(Base):
    __tablename__ = "ride_offers"
    __table_args__ = (
        UniqueConstraint("ride_request_id", "driver_id", name="uq_ride_offer_ride_driver"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    ride_request_id: Mapped[int] = mapped_column(
        ForeignKey("ride_requests.id"),
        nullable=False,
    )
    driver_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )
    proposed_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    status: Mapped[RideOfferStatus] = mapped_column(
        SqlEnum(
            RideOfferStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        nullable=False,
        default=RideOfferStatus.PENDING,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )
    responded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
