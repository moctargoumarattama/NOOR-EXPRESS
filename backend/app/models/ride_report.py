from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, Enum as SqlEnum, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class RideReportReason(str, Enum):
    COMPORTEMENT = "comportement"
    PRIX = "prix"
    SECURITE = "securite"
    AUTRE = "autre"


class RideReportStatus(str, Enum):
    NOUVEAU = "nouveau"
    EN_COURS = "en_cours"
    RESOLU = "resolu"
    CLASSE_SANS_SUITE = "classe_sans_suite"


class RideReport(Base):
    __tablename__ = "ride_reports"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    ride_request_id: Mapped[int] = mapped_column(
        ForeignKey("ride_requests.id"),
        nullable=False,
    )
    reported_by_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
    )
    reason: Mapped[RideReportReason] = mapped_column(
        SqlEnum(
            RideReportReason,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        nullable=False,
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[RideReportStatus] = mapped_column(
        SqlEnum(
            RideReportStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        nullable=False,
        default=RideReportStatus.NOUVEAU,
    )
    note_admin: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )
