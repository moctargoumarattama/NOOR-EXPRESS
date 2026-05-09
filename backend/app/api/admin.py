import os
from datetime import date, datetime, time
from enum import Enum

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, field_validator, model_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.messages import Messages
from app.db.database import get_db_session
from app.services.admin_service import (
    AdminAlreadyExistsError,
    AdminNotificationRateLimitError,
    AdminReportNotFoundError,
    AdminSuspensionInvalidError,
    AdminUserDeleteBlockedError,
    AdminUserNotFoundError,
    block_user,
    create_admin,
    delete_user,
    get_all_reports,
    get_all_rides,
    get_deleted_users,
    get_user_suspension_history,
    get_all_users,
    get_dashboard_stats,
    get_notification_broadcast_history,
    login_admin,
    estimate_broadcast_recipients,
    send_notification_broadcast,
    suspend_user,
    unsuspend_user,
    update_report,
    require_admin,
    unblock_user,
)
from app.models.driver_profile import DRIVER_DOCUMENT_FIELD_MAP, DriverDocumentType
from app.schemas.driver_profile import (
    DriverDocumentReviewRequest,
    DriverProfileAdminUpdate,
    DriverRejectRequest,
)
from app.schemas.driver_wallet import CommissionLedgerRead
from app.services.driver_profile_service import (
    admin_update_driver_profile,
    get_all_drivers,
    get_pending_drivers,
    reject_driver,
    review_driver_document,
    verify_driver,
)
from app.services.ride_request_service import get_top_drivers
from app.services.wallet_service import (
    WithdrawalRequestNotFoundError,
    WithdrawalRequestStateConflictError,
    WithdrawalRequestValidationError,
    get_admin_commission_ledger,
    list_admin_withdrawal_requests,
    resolve_admin_withdrawal_request,
)
from app.schemas.ride_report import RideReportAdminUpdate

router = APIRouter(prefix="/admin", tags=["admin"])


def _admin_init_enabled() -> bool:
    return os.getenv("ADMIN_INIT_ENABLED", "").strip().lower() == "true"


class AdminLoginRequest(BaseModel):
    username: str
    password: str


class AdminInitRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=4)


class AdminTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AdminNotificationTarget(str, Enum):
    ALL = "all"
    DRIVERS = "drivers"
    PASSENGERS = "passengers"
    USER_ID = "user_id"


class AdminNotificationType(str, Enum):
    INFO = "info"
    PROMO = "promo"
    ALERTE = "alerte"


class AdminNotificationBroadcastRequest(BaseModel):
    target: AdminNotificationTarget
    user_id: int | None = Field(default=None, ge=1)
    title: str = Field(min_length=1, max_length=60)
    message: str = Field(min_length=1, max_length=200)
    type: AdminNotificationType

    @field_validator("title", "message")
    @classmethod
    def validate_non_empty_text(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError(Messages.FIELD_REQUIRED)
        return cleaned

    @model_validator(mode="after")
    def validate_target_user(self) -> "AdminNotificationBroadcastRequest":
        if self.target == AdminNotificationTarget.USER_ID and self.user_id is None:
            raise ValueError(Messages.USER_ID_REQUIRED_FOR_TARGET)
        if self.target != AdminNotificationTarget.USER_ID and self.user_id is not None:
            raise ValueError(Messages.USER_ID_ALLOWED_ONLY_FOR_TARGET)
        return self


class AdminUserSuspendRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=2000)
    duration_days: int | None = Field(default=None, ge=1, le=3650)
    is_permanent: bool = False

    @model_validator(mode="after")
    def validate_duration_or_permanent(self) -> "AdminUserSuspendRequest":
        if self.is_permanent and self.duration_days is not None:
            raise ValueError(Messages.DURATION_OMITTED_FOR_PERMANENT_SUSPENSION)
        if not self.is_permanent and self.duration_days is None:
            raise ValueError(Messages.DURATION_REQUIRED_FOR_TEMP_SUSPENSION)
        return self


class AdminWithdrawalStatus(str, Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    REJECTED = "rejected"


class AdminWithdrawalAction(str, Enum):
    CONFIRM = "confirm"
    REJECT = "reject"


class AdminWithdrawalResolveRequest(BaseModel):
    action: AdminWithdrawalAction
    admin_note: str | None = Field(default=None, max_length=200)

    @model_validator(mode="after")
    def validate_reject_note(self) -> "AdminWithdrawalResolveRequest":
        if self.action == AdminWithdrawalAction.REJECT and (
            self.admin_note is None or not self.admin_note.strip()
        ):
            raise ValueError(Messages.ADMIN_NOTE_REQUIRED_FOR_REJECT)
        return self


@router.post("/auth/login", response_model=AdminTokenResponse)
async def admin_login_endpoint(
    login_in: AdminLoginRequest,
    session: AsyncSession = Depends(get_db_session),
) -> AdminTokenResponse:
    token = await login_admin(session, login_in.username, login_in.password)
    return AdminTokenResponse(access_token=token)


@router.post(
    "/init",
    response_model=AdminTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
async def admin_init_endpoint(
    init_in: AdminInitRequest,
    session: AsyncSession = Depends(get_db_session),
) -> AdminTokenResponse:
    # Route désactivée en production.
    # Utiliser backend/scripts/create_admin.py en local uniquement.
    if not _admin_init_enabled():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    try:
        admin = await create_admin(session, init_in.username, init_in.password)
    except AdminAlreadyExistsError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    token = await login_admin(session, admin.username, init_in.password)
    return AdminTokenResponse(access_token=token)


@router.get("/init", include_in_schema=False)
async def admin_init_probe_endpoint() -> None:
    if not _admin_init_enabled():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    raise HTTPException(status_code=status.HTTP_405_METHOD_NOT_ALLOWED)


@router.get("/users")
async def admin_users_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_users(session)


@router.get("/users/deleted")
async def admin_deleted_users_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_deleted_users(session)


@router.get("/notifications/estimate")
async def admin_notification_estimate_endpoint(
    target: AdminNotificationTarget = Query(default=AdminNotificationTarget.ALL),
    user_id: int | None = Query(default=None, ge=1),
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    if target == AdminNotificationTarget.USER_ID and user_id is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            Messages.USER_ID_REQUIRED_FOR_TARGET,
        )
    if target != AdminNotificationTarget.USER_ID and user_id is not None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            Messages.USER_ID_ALLOWED_ONLY_FOR_TARGET,
        )
    estimated = await estimate_broadcast_recipients(
        session,
        target=target.value,
        user_id=user_id,
    )
    return {"estimated_recipients": estimated}


@router.post("/notifications/broadcast")
async def admin_notification_broadcast_endpoint(
    broadcast_in: AdminNotificationBroadcastRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        return await send_notification_broadcast(
            session,
            target=broadcast_in.target.value,
            user_id=broadcast_in.user_id,
            title=broadcast_in.title,
            message=broadcast_in.message,
            notification_type=broadcast_in.type.value,
        )
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc
    except AdminNotificationRateLimitError as exc:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            Messages.BROADCAST_LIMIT_REACHED,
            headers={"Retry-After": str(exc.retry_after_seconds)},
        ) from exc


@router.get("/notifications/history")
async def admin_notification_history_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> dict:
    return await get_notification_broadcast_history(
        session,
        limit=limit,
        offset=offset,
    )


def _user_not_found_response(exc: AdminUserNotFoundError) -> HTTPException:
    return HTTPException(status.HTTP_404_NOT_FOUND, str(exc))


def _report_not_found_response(exc: AdminReportNotFoundError) -> HTTPException:
    return HTTPException(status.HTTP_404_NOT_FOUND, str(exc))


@router.post("/users/{user_id}/block")
async def admin_block_user_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        user = await block_user(session, user_id)
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc
    return {"user_id": user.id, "is_blocked": user.is_blocked}


@router.post("/users/{user_id}/suspend")
async def admin_suspend_user_endpoint(
    user_id: int,
    suspend_in: AdminUserSuspendRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        user = await suspend_user(
            session,
            user_id,
            reason=suspend_in.reason,
            duration_days=(
                None if suspend_in.is_permanent else suspend_in.duration_days
            ),
        )
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc
    except AdminSuspensionInvalidError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc
    return {
        "user_id": user.id,
        "is_suspended": user.is_suspended,
        "suspended_until": user.suspended_until,
        "suspension_reason": user.suspension_reason,
    }


@router.post("/users/{user_id}/unsuspend")
async def admin_unsuspend_user_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        user = await unsuspend_user(session, user_id)
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc
    return {
        "user_id": user.id,
        "is_suspended": user.is_suspended,
    }


@router.get("/users/{user_id}/suspensions")
async def admin_user_suspension_history_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    try:
        return await get_user_suspension_history(session, user_id)
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc


@router.post("/users/{user_id}/unblock")
async def admin_unblock_user_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        user = await unblock_user(session, user_id)
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc
    return {"user_id": user.id, "is_blocked": user.is_blocked}


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_user_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    try:
        await delete_user(session, user_id)
    except AdminUserNotFoundError as exc:
        raise _user_not_found_response(exc) from exc
    except AdminUserDeleteBlockedError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc


@router.get("/rides")
async def admin_rides_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_rides(session)


@router.get("/reports")
async def admin_reports_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_reports(session)


@router.patch("/reports/{report_id}")
async def admin_update_report_endpoint(
    report_id: int,
    report_in: RideReportAdminUpdate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    try:
        report = await update_report(
            session,
            report_id,
            status=report_in.status,
            note_admin=report_in.note_admin,
        )
    except AdminReportNotFoundError as exc:
        raise _report_not_found_response(exc) from exc
    return {
        "id": report.id,
        "status": report.status.value,
        "note_admin": report.note_admin,
    }


@router.get("/dashboard")
async def admin_dashboard_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    stats = await get_dashboard_stats(session)
    stats["top_drivers"] = [
        driver.model_dump() for driver in await get_top_drivers(session, limit=5)
    ]
    return stats


@router.get("/drivers/pending")
async def admin_pending_drivers_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_pending_drivers(session)


@router.get("/drivers")
async def admin_drivers_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> list[dict]:
    return await get_all_drivers(session)


@router.put("/drivers/{user_id}/profile")
async def admin_update_driver_profile_endpoint(
    user_id: int,
    profile_in: DriverProfileAdminUpdate,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    profile = await admin_update_driver_profile(session, user_id, profile_in)
    return {
        "user_id": profile.user_id,
        "verification_status": profile.verification_status.value,
    }


@router.post("/drivers/{user_id}/verify")
async def admin_verify_driver_endpoint(
    user_id: int,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    profile = await verify_driver(session, user_id)
    return {
        "user_id": profile.user_id,
        "verification_status": profile.verification_status.value,
    }


@router.post("/drivers/{user_id}/reject")
async def admin_reject_driver_endpoint(
    user_id: int,
    reject_in: DriverRejectRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    profile = await reject_driver(session, user_id, reject_in.reason)
    return {
        "user_id": profile.user_id,
        "verification_status": profile.verification_status.value,
        "rejection_reason": profile.rejection_reason,
    }


@router.post("/drivers/{user_id}/documents/{document_type}/review")
async def admin_review_driver_document_endpoint(
    user_id: int,
    document_type: DriverDocumentType,
    review_in: DriverDocumentReviewRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict:
    profile = await review_driver_document(
        session,
        user_id,
        document_type,
        review_in.status,
        reason=review_in.reason,
    )
    _, _, status_field, _ = DRIVER_DOCUMENT_FIELD_MAP[document_type]
    return {
        "user_id": profile.user_id,
        "document_type": document_type.value,
        "document_status": getattr(profile, status_field).value,
    }


@router.get("/withdrawal-requests")
async def admin_withdrawal_requests_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
    status: AdminWithdrawalStatus | None = Query(default=None),
    driver_id: int | None = Query(default=None, ge=1),
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict[str, object]:
    return await list_admin_withdrawal_requests(
        session,
        status=None if status is None else status.value,
        driver_id=driver_id,
        limit=limit,
        offset=offset,
    )


@router.patch("/withdrawal-requests/{withdrawal_request_id}")
async def admin_resolve_withdrawal_request_endpoint(
    withdrawal_request_id: str,
    resolve_in: AdminWithdrawalResolveRequest,
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, object]:
    try:
        return await resolve_admin_withdrawal_request(
            session,
            withdrawal_request_id=withdrawal_request_id,
            action=resolve_in.action.value,
            admin_id=int(_admin.get("sub", 0)),
            admin_note=resolve_in.admin_note,
        )
    except WithdrawalRequestNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    except WithdrawalRequestStateConflictError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
    except WithdrawalRequestValidationError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc


@router.get("/commissions/ledger", response_model=CommissionLedgerRead)
async def admin_commission_ledger_endpoint(
    _admin: dict = Depends(require_admin),
    session: AsyncSession = Depends(get_db_session),
    driver_id: int | None = Query(default=None),
    date_from: date | None = Query(default=None),
    date_to: date | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> CommissionLedgerRead:
    return await get_admin_commission_ledger(
        session,
        driver_id=driver_id,
        date_from=(
            datetime.combine(date_from, time.min) if date_from is not None else None
        ),
        date_to=datetime.combine(date_to, time.max) if date_to is not None else None,
        limit=limit,
        offset=offset,
    )

