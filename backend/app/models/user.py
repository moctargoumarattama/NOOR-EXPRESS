from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, String, func
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class UserRole(str, Enum):
    DRIVER = "driver"
    CLIENT = "client"


class DriverStatus(str, Enum):
    OFFLINE = "offline"
    ONLINE = "online"
    BUSY = "busy"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    phone_number: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    profile_photo: Mapped[str | None] = mapped_column(MEDIUMTEXT, nullable=True)
    role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole), nullable=False)
    refresh_token: Mapped[str | None] = mapped_column(String(255), nullable=True)
    fcm_token: Mapped[str | None] = mapped_column(String(500), nullable=True)
    vehicle_brand: Mapped[str | None] = mapped_column(String(100), nullable=True)
    vehicle_model: Mapped[str | None] = mapped_column(String(100), nullable=True)
    vehicle_color: Mapped[str | None] = mapped_column(String(50), nullable=True)
    plate_number: Mapped[str | None] = mapped_column(String(30), nullable=True)
    is_available: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
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
