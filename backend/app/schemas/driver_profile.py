from datetime import date, datetime

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.models.driver_profile import (
    DRIVER_DOCUMENT_FIELD_MAP,
    DriverDocumentStatus,
    DriverVerificationStatus,
    driver_document_expiry_alerts,
    effective_document_status,
)


class DriverProfileCreate(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    address: str | None = None
    id_card_photo: str | None = None
    selfie_photo: str | None = None
    driver_license_file: str | None = None
    driver_license_expires_at: date | None = None
    vehicle_registration_file: str | None = None
    vehicle_registration_expires_at: date | None = None
    vehicle_insurance_file: str | None = None
    vehicle_insurance_expires_at: date | None = None
    technical_inspection_file: str | None = None
    technical_inspection_expires_at: date | None = None

    @field_validator(
        "id_card_photo",
        "selfie_photo",
        "driver_license_file",
        "vehicle_registration_file",
        "vehicle_insurance_file",
        "technical_inspection_file",
    )
    @classmethod
    def strip_optional_document(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @model_validator(mode="after")
    def require_private_driver_documents(self) -> "DriverProfileCreate":
        required_fields = {
            "id_card_photo": "Identity card photo",
            "selfie_photo": "Selfie photo",
            "driver_license_file": "Driver license",
            "vehicle_registration_file": "Vehicle registration",
            "vehicle_insurance_file": "Vehicle insurance",
            "technical_inspection_file": "Technical inspection",
        }
        for field_name, label in required_fields.items():
            if getattr(self, field_name) is None:
                raise ValueError(f"{label} is required")
        for _, expiry_field, _, label in DRIVER_DOCUMENT_FIELD_MAP.values():
            if getattr(self, expiry_field) is None:
                raise ValueError(f"{label} expiration date is required")
        return self


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
            raise ValueError("Document rejection reason is required")
        self.reason = self.reason.strip()
        return self
