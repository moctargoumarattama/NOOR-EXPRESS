from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class RideRequestRejection(Base):
    __tablename__ = "ride_request_rejections"
    __table_args__ = (
        UniqueConstraint(
            "ride_request_id",
            "driver_id",
            name="uq_ride_request_rejections_ride_driver",
        ),
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
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )
