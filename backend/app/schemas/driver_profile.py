from datetime import date, datetime
import base64
import binascii

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    ValidationInfo,
    field_validator,
    model_validator,
)

from app.core.messages import Messages
from app.models.driver_profile import (
    DRIVER_DOCUMENT_FIELD_MAP,
    DriverDocumentStatus,
    DriverVerificationStatus,
    driver_document_expiry_alerts,
    effective_document_status,
)

DRIVER_PROFILE_MAX_IMAGE_BYTES = 5 * 1024 * 1024
_DRIVER_PROFILE_DOCUMENT_FIELDS = (
    "id_card_photo",
    "selfie_photo",
    "vehicle_photo",
    "driver_license_file",
    "vehicle_registration_file",
    "vehicle_insurance_file",
    "technical_inspection_file",
)


class DriverProfileCreate(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    address: str | None = None
    id_card_photo: str | None = None
    selfie_photo: str | None = None
    vehicle_photo: str | None = None
    driver_license_file: str | None = None
    driver_license_expires_at: date | None = None
    vehicle_registration_file: str | None = None
    vehicle_registration_expires_at: date | None = None
    vehicle_insurance_file: str | None = None
    vehicle_insurance_expires_at: date | None = None
    technical_inspection_file: str | None = None
    technical_inspection_expires_at: date | None = None

    @field_validator(*_DRIVER_PROFILE_DOCUMENT_FIELDS)
    @classmethod
    def strip_optional_document(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @field_validator(*_DRIVER_PROFILE_DOCUMENT_FIELDS)
    @classmethod
    def validate_document_payload_size(
        cls,
        value: str | None,
        info: ValidationInfo,
    ) -> str | None:
        if value is None:
            return None
        _assert_base64_document_size(
            field_name=info.field_name or "document",
            value=value,
            max_bytes=DRIVER_PROFILE_MAX_IMAGE_BYTES,
        )
        return value

    @model_validator(mode="after")
    def require_private_driver_documents(self) -> "DriverProfileCreate":
        required_fields = {
            "id_card_photo": "Photo de carte d'identité",
            "selfie_photo": "Photo selfie",
            "vehicle_photo": "Photo du véhicule",
            "driver_license_file": "Permis de conduire",
            "vehicle_registration_file": "Carte grise",
            "vehicle_insurance_file": "Assurance auto",
            "technical_inspection_file": "Visite technique",
        }
        for field_name, label in required_fields.items():
            if getattr(self, field_name) is None:
                raise ValueError(
                    Messages.DRIVER_DOCUMENT_REQUIRED_TEMPLATE.format(label=label)
                )
        for _, expiry_field, _, label in DRIVER_DOCUMENT_FIELD_MAP.values():
            if getattr(self, expiry_field) is None:
                raise ValueError(
                    Messages.DRIVER_DOCUMENT_EXPIRY_REQUIRED_TEMPLATE.format(
                        label=label
                    )
                )
        return self


def _assert_base64_document_size(
    *,
    field_name: str,
    value: str,
    max_bytes: int,
) -> None:
    payload = _extract_base64_payload(value)
    try:
        decoded = base64.b64decode(payload, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ValueError(
            Messages.DOCUMENT_BASE64_INVALID_TEMPLATE.format(field_name=field_name)
        ) from exc
    if len(decoded) > max_bytes:
        max_megabytes = max_bytes / (1024 * 1024)
        raise ValueError(
            Messages.DOCUMENT_TOO_LARGE_TEMPLATE.format(
                field_name=field_name,
                max_megabytes=max_megabytes,
            )
        )


def _extract_base64_payload(value: str) -> str:
    normalized = value.strip()
    if normalized.startswith("data:") and "," in normalized:
        return normalized.split(",", 1)[1].strip()
    return normalized


class DriverProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    first_name: str
    last_name: str
    address: str | None
    id_card_photo: str | None
    selfie_photo: str | None
    driver_license_file: str | None
    driver_license_expires_at: date | None
    driver_license_status: DriverDocumentStatus
    vehicle_registration_file: str | None
    vehicle_registration_expires_at: date | None
    vehicle_registration_status: DriverDocumentStatus
    vehicle_insurance_file: str | None
    vehicle_insurance_expires_at: date | None
    vehicle_insurance_status: DriverDocumentStatus
    technical_inspection_file: str | None
    technical_inspection_expires_at: date | None
    technical_inspection_status: DriverDocumentStatus
    verification_status: DriverVerificationStatus
    rejection_reason: str | None
    submitted_at: datetime | None
    verified_at: datetime | None
    document_expiry_alerts: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def apply_document_statuses(self) -> "DriverProfileRead":
        for _, expiry_field, status_field, _ in DRIVER_DOCUMENT_FIELD_MAP.values():
            setattr(
                self,
                status_field,
                effective_document_status(
                    getattr(self, status_field),
                    getattr(self, expiry_field),
                ),
            )
        self.document_expiry_alerts = driver_document_expiry_alerts(self)
        return self


class DriverProfileAdminRead(DriverProfileRead):
    phone_number: str
    user_name: str | None = None
    is_blocked: bool = False
    vehicle_brand: str | None = None
    vehicle_model: str | None = None
    vehicle_color: str | None = None
    plate_number: str | None = None


class DriverProfileAdminUpdate(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    phone_number: str = Field(min_length=3, max_length=20)
    user_name: str | None = Field(default=None, max_length=120)
    address: str | None = None
    vehicle_brand: str | None = Field(default=None, max_length=100)
    vehicle_model: str | None = Field(default=None, max_length=100)
    vehicle_color: str | None = Field(default=None, max_length=50)
    plate_number: str | None = Field(default=None, max_length=30)


class DriverRejectRequest(BaseModel):
    reason: str = Field(min_length=2, max_length=500)


class DriverDocumentReviewRequest(BaseModel):
    status: DriverDocumentStatus
    reason: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def require_rejection_reason(self) -> "DriverDocumentReviewRequest":
        if self.status != DriverDocumentStatus.REJECTED:
            return self
        if self.reason is None or not self.reason.strip():
            raise ValueError(Messages.DOCUMENT_REJECTION_REASON_REQUIRED)
        self.reason = self.reason.strip()
        return self
