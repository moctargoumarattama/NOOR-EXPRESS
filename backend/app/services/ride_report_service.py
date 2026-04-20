from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ride_report import RideReport
from app.models.ride_request import RideRequest
from app.models.user import User
from app.schemas.ride_report import RideReportCreate


class RideReportNotFoundError(Exception):
    pass


class RideReportForbiddenError(Exception):
    pass


async def create_report(
    session: AsyncSession,
    user: User,
    report_in: RideReportCreate,
) -> RideReport:
    ride_request = await session.get(RideRequest, report_in.ride_request_id)
    if ride_request is None:
        raise RideReportNotFoundError("Ride request not found")

    allowed_user_ids = {
        ride_request.client_id,
        ride_request.driver_id,
    }
    if user.id not in allowed_user_ids:
        raise RideReportForbiddenError("User cannot report this ride")

    report = RideReport(
        ride_request_id=ride_request.id,
        reported_by_id=user.id,
        reason=report_in.reason,
        description=report_in.description,
    )
    session.add(report)
    await session.commit()
    await session.refresh(report)
    return report
