from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.ride_report import RideReportReason, RideReportStatus


class RideReportCreate(BaseModel):
    ride_request_id: int
    reason: RideReportReason
    description: str | None = Field(default=None, max_length=2000)


class RideReportCreateBody(BaseModel):
    reason: RideReportReason
    description: str | None = Field(default=None, max_length=2000)


class RideReportRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    ride_request_id: int
    reason: RideReportReason
    description: str | None
    status: RideReportStatus
    note_admin: str | None
    created_at: datetime


class RideReportAdminUpdate(BaseModel):
    status: RideReportStatus
    note_admin: str | None = Field(default=None, max_length=2000)

    @field_validator("note_admin")
    @classmethod
    def validate_note_admin(cls, value: str | None) -> str | None:
        if value is None:
            return None
        note_admin = value.strip()
        return note_admin or None
