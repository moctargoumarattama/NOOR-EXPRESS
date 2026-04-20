from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

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
    created_at: datetime
