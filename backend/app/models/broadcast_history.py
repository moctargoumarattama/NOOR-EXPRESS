from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class BroadcastFCMStatus(str, Enum):
    SENT = "sent"
    PARTIAL = "partial"
    FAILED = "failed"
    FIREBASE_NOT_CONFIGURED = "firebase_not_configured"


class BroadcastHistory(Base):
    __tablename__ = "broadcast_history"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    target: Mapped[str] = mapped_column(String(32), nullable=False)
    title: Mapped[str] = mapped_column(String(60), nullable=False)
    message: Mapped[str] = mapped_column(String(200), nullable=False)
    notification_type: Mapped[str] = mapped_column(String(20), nullable=False)
    sent_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
        index=True,
    )
    estimated_recipients: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    fcm_sent_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    fcm_failed_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    fcm_status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        default=BroadcastFCMStatus.FAILED.value,
    )
    fcm_error_reason: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
