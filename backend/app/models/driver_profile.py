from datetime import date, datetime, timedelta
from enum import Enum

from sqlalchemy import (
    Date,
    DateTime,
    Enum as SqlEnum,
    ForeignKey,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class DriverVerificationStatus(str, Enum):
    PENDING = "pending"
    VERIFIED = "verified"
    REJECTED = "rejected"


class DriverDocumentStatus(str, Enum):
    PENDING = "en_attente"
    VALIDATED = "validé"
    EXPIRED = "expiré"
    REJECTED = "rejeté"


class DriverDocumentType(str, Enum):
    DRIVER_LICENSE = "driver_license"
    VEHICLE_REGISTRATION = "vehicle_registration"
    VEHICLE_INSURANCE = "vehicle_insurance"
    TECHNICAL_INSPECTION = "technical_inspection"


DOCUMENT_EXPIRY_ALERT_DAYS = 30

DRIVER_DOCUMENT_FIELD_MAP = {
    DriverDocumentType.DRIVER_LICENSE: (
        "driver_license_file",
        "driver_license_expires_at",
        "driver_license_status",
        "Permis de conduire",
    ),
    DriverDocumentType.VEHICLE_REGISTRATION: (
        "vehicle_registration_file",
        "vehicle_registration_expires_at",
        "vehicle_registration_status",
        "Carte grise",
    ),
    DriverDocumentType.VEHICLE_INSURANCE: (
        "vehicle_insurance_file",
        "vehicle_insurance_expires_at",
        "vehicle_insurance_status",
        "Assurance auto",
    ),
    DriverDocumentType.TECHNICAL_INSPECTION: (
        "technical_inspection_file",
        "technical_inspection_expires_at",
        "technical_inspection_status",
        "Visite technique",
    ),
}


class DriverProfile(Base):
    __tablename__ = "driver_profiles"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    id_card_photo: Mapped[str | None] = mapped_column(MEDIUMTEXT, nullable=True)
    selfie_photo: Mapped[str | None] = mapped_column(MEDIUMTEXT, nullable=True)
    driver_license_file: Mapped[str | None] = mapped_column(MEDIUMTEXT, nullable=True)
    driver_license_expires_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    driver_license_status: Mapped[DriverDocumentStatus] = mapped_column(
        SqlEnum(
            DriverDocumentStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        default=DriverDocumentStatus.PENDING,
        nullable=False,
    )
    vehicle_registration_file: Mapped[str | None] = mapped_column(
        MEDIUMTEXT,
        nullable=True,
    )
    vehicle_registration_expires_at: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )
    vehicle_registration_status: Mapped[DriverDocumentStatus] = mapped_column(
        SqlEnum(
            DriverDocumentStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        default=DriverDocumentStatus.PENDING,
        nullable=False,
    )
    vehicle_insurance_file: Mapped[str | None] = mapped_column(
        MEDIUMTEXT,
        nullable=True,
    )
    vehicle_insurance_expires_at: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )
    vehicle_insurance_status: Mapped[DriverDocumentStatus] = mapped_column(
        SqlEnum(
            DriverDocumentStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        default=DriverDocumentStatus.PENDING,
        nullable=False,
    )
    technical_inspection_file: Mapped[str | None] = mapped_column(
        MEDIUMTEXT,
        nullable=True,
    )
    technical_inspection_expires_at: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )
    technical_inspection_status: Mapped[DriverDocumentStatus] = mapped_column(
        SqlEnum(
            DriverDocumentStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        default=DriverDocumentStatus.PENDING,
        nullable=False,
    )
    verification_status: Mapped[DriverVerificationStatus] = mapped_column(
        SqlEnum(
            DriverVerificationStatus,
            values_callable=lambda enum_class: [item.value for item in enum_class],
        ),
        default=DriverVerificationStatus.PENDING,
        nullable=False,
        index=True,
    )
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        server_default=func.now(),
        nullable=False,
    )


def effective_document_status(
    status: DriverDocumentStatus | str,
    expires_at: date | datetime | None,
    today: date | datetime | None = None,
) -> DriverDocumentStatus:
    document_status = _coerce_document_status(status)
    expires_on = _as_date(expires_at)
    if document_status == DriverDocumentStatus.REJECTED or expires_on is None:
        return document_status
    current_day = _as_date(today) or date.today()
    if expires_on < current_day:
        return DriverDocumentStatus.EXPIRED
    return document_status


def driver_document_expiry_alerts(
    profile: object,
    today: date | datetime | None = None,
) -> list[str]:
    current_day = _as_date(today) or date.today()
    alert_limit = current_day + timedelta(days=DOCUMENT_EXPIRY_ALERT_DAYS)
    alerts: list[str] = []
    for _, expiry_field, status_field, label in DRIVER_DOCUMENT_FIELD_MAP.values():
        expires_on = _as_date(getattr(profile, expiry_field, None))
        if expires_on is None:
            continue
        status = effective_document_status(
            getattr(profile, status_field),
            expires_on,
            today=current_day,
        )
        if status == DriverDocumentStatus.EXPIRED:
            alerts.append(f"{label} expiré")
        elif status == DriverDocumentStatus.VALIDATED and expires_on < alert_limit:
            alerts.append(f"{label} expire le {expires_on.isoformat()}")
    return alerts


def all_driver_documents_valid(profile: object, today: date | None = None) -> bool:
    for _, expiry_field, status_field, _ in DRIVER_DOCUMENT_FIELD_MAP.values():
        if effective_document_status(
            getattr(profile, status_field),
            getattr(profile, expiry_field, None),
            today=today,
        ) != DriverDocumentStatus.VALIDATED:
            return False
    return True


def _as_date(value: date | datetime | None) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    return value


def _coerce_document_status(status: DriverDocumentStatus | str | None) -> DriverDocumentStatus:
    if isinstance(status, DriverDocumentStatus):
        return status
    if isinstance(status, str):
        try:
            return DriverDocumentStatus(status)
        except ValueError:
            return DriverDocumentStatus.PENDING
    return DriverDocumentStatus.PENDING
