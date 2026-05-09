from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from enum import Enum
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class WithdrawalRequestStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    REJECTED = "rejected"


def _withdrawal_request_id() -> str:
    return str(uuid4())


class WithdrawalRequest(Base):
    __tablename__ = "withdrawal_requests"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=_withdrawal_request_id,
    )
    driver_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    amount_due: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    commission_rate_snapshot: Mapped[Decimal] = mapped_column(
        Numeric(5, 2),
        nullable=False,
    )
    status: Mapped[WithdrawalRequestStatus] = mapped_column(
        String(20),
        nullable=False,
        default=WithdrawalRequestStatus.PENDING.value,
        index=True,
    )
    driver_note: Mapped[str | None] = mapped_column(String(200), nullable=True)
    admin_note: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    confirmed_by: Mapped[int | None] = mapped_column(
        ForeignKey("admins.id"),
        nullable=True,
    )
