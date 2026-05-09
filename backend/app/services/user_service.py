import hashlib
from datetime import datetime
from decimal import Decimal
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile
from PIL import Image, ImageOps

from sqlalchemy import delete, func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.api_errors import ApiError
from app.core.messages import Messages
from app.models.driver_profile import (
    DRIVER_DOCUMENT_FIELD_MAP,
    DriverProfile,
    DriverVerificationStatus,
)
from app.models.driver_wallet import DriverWallet
from app.models.ride_message import RideMessage
from app.models.user import DriverStatus, SavedAddress, User, UserRole
from app.models.ride_request import RideRequest, RideRequestStatus
from app.schemas.user import (
    ClientProfileRead,
    ClientProfileUpdate,
    DriverAvailabilityUpdate,
    DriverProfileUpdate,
    DriverRadiusUpdate,
    DriverStatusUpdate,
    SavedAddressCreate,
    SavedAddressUpdate,
    UserCreate,
)


class UserPhoneAlreadyExistsError(Exception):
    pass


MAX_SAVED_ADDRESSES_PER_USER = 10
SUSPENSION_CODE = "account_suspended"
DEFAULT_DRIVER_MAX_RADIUS_KM = 5
MAX_PROFILE_PHOTO_SIZE_BYTES = 5 * 1024 * 1024
PROFILE_PHOTO_DIMENSION = 400
DELETED_ACCOUNT_DISPLAY_NAME = "Utilisateur supprimé"
DELETED_DRIVER_PROFILE_LAST_NAME = "Supprimé"
DRIVER_WALLET_SETTLEMENT_MESSAGE = "Soldez votre wallet avant de supprimer votre compte"
ACCOUNT_DELETION_BLOCKING_STATUSES = (
    RideRequestStatus.ACCEPTED,
    RideRequestStatus.ARRIVED,
    RideRequestStatus.STARTED,
)
PROFILE_PHOTO_STORAGE_DIR = (
    Path(__file__).resolve().parents[2] / "uploads" / "profile_photos"
)
PROFILE_PHOTO_PUBLIC_PREFIX = "/uploads/profile_photos/"


async def create_user(session: AsyncSession, user_in: UserCreate) -> User:
    existing_user = await get_user_by_phone_number(session, user_in.phone_number)
    if existing_user is not None:
        raise UserPhoneAlreadyExistsError("Ce numero existe deja")

    user = User(
        phone_number=user_in.phone_number,
        name=user_in.name,
        role=user_in.role,
        max_radius_km=(
            DEFAULT_DRIVER_MAX_RADIUS_KM if user_in.role == UserRole.DRIVER else None
        ),
        is_available=True if user_in.role == UserRole.DRIVER else None,
        driver_status=DriverStatus.OFFLINE if user_in.role == UserRole.DRIVER else None,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise UserPhoneAlreadyExistsError("Ce numero existe deja") from exc
    await session.refresh(user)
    return user


async def get_user_by_id(session: AsyncSession, user_id: int) -> User | None:
    return await session.get(User, user_id)


async def get_user_by_phone_number(
    session: AsyncSession, phone_number: str
) -> User | None:
    result = await session.execute(
        select(User).where(User.phone_number == phone_number)
    )
    return result.scalar_one_or_none()


async def authenticate_user(session: AsyncSession, phone_number: str) -> User | None:
    user = await get_user_by_phone_number(session, phone_number)
    if user is None:
        return None
    if getattr(user, "deleted_at", None) is not None:
        raise ApiError(
            status_code=403,
            code="account_deleted",
            message=Messages.ACCOUNT_DELETED,
        )
    if user.is_blocked:
        raise ApiError(
            status_code=403,
            code="account_blocked",
            message=Messages.ACCOUNT_BLOCKED,
        )
    await ensure_user_not_suspended(session, user)
    return user


async def update_driver_status(
    session: AsyncSession,
    driver_id: int,
    driver_status: DriverStatus,
    *,
    is_available: bool | None = None,
) -> User | None:
    driver = await session.get(User, driver_id)
    if driver is None or driver.role != UserRole.DRIVER:
        return None

    _apply_driver_status(
        driver,
        driver_status=driver_status,
        is_available=is_available,
    )
    await session.commit()
    await session.refresh(driver)
    return driver


async def get_drivers_by_status(
    session: AsyncSession,
    driver_ids: list[int],
    driver_status: DriverStatus,
    is_available: bool | None = None,
) -> list[User]:
    if not driver_ids:
        return []

    query = select(User).where(
        User.id.in_(driver_ids),
        User.role == UserRole.DRIVER,
        User.driver_status == driver_status,
    )
    if is_available is not None:
        query = query.where(User.is_available == is_available)

    result = await session.execute(query)
    return list(result.scalars().all())


async def get_driver_profile(
    session: AsyncSession,
    driver_id: int,
) -> User | None:
    driver = await session.get(User, driver_id)
    if driver is None or driver.role != UserRole.DRIVER:
        return None
    return driver


async def update_driver_profile(
    session: AsyncSession,
    driver_id: int,
    profile_in: DriverProfileUpdate,
) -> User | None:
    driver = await get_driver_profile(session, driver_id)
    if driver is None:
        return None

    update_fields = profile_in.model_dump(exclude_unset=True)
    if "name" in update_fields:
        driver.name = profile_in.name
    if "profile_photo" in update_fields:
        driver.profile_photo = profile_in.profile_photo
    if "vehicle_brand" in update_fields:
        driver.vehicle_brand = profile_in.vehicle_brand
    if "vehicle_model" in update_fields:
        driver.vehicle_model = profile_in.vehicle_model
    if "vehicle_color" in update_fields:
        driver.vehicle_color = profile_in.vehicle_color
    if "vehicle_photo" in update_fields:
        driver.vehicle_photo = profile_in.vehicle_photo
    if "plate_number" in update_fields:
        driver.plate_number = profile_in.plate_number
    await session.commit()
    await session.refresh(driver)
    return driver


async def update_driver_availability(
    session: AsyncSession,
    driver_id: int,
    availability_in: DriverAvailabilityUpdate,
) -> User | None:
    driver = await get_driver_profile(session, driver_id)
    if driver is None:
        return None

    target_status = (
        DriverStatus.ONLINE if availability_in.is_available else DriverStatus.OFFLINE
    )
    return await update_driver_presence_status(
        session,
        driver_id,
        DriverStatusUpdate(status=target_status),
    )


async def update_driver_max_radius(
    session: AsyncSession,
    driver_id: int,
    radius_in: DriverRadiusUpdate,
) -> User | None:
    driver = await get_driver_profile(session, driver_id)
    if driver is None:
        return None

    driver.max_radius_km = radius_in.max_radius_km
    await session.commit()
    await session.refresh(driver)
    return driver


async def update_driver_presence_status(
    session: AsyncSession,
    driver_id: int,
    status_in: DriverStatusUpdate,
) -> User | None:
    driver = await get_driver_profile(session, driver_id)
    if driver is None:
        return None

    if status_in.status == DriverStatus.ONLINE and not await is_driver_verified(
        session, driver_id
    ):
        raise ApiError(
            status_code=403,
            code="driver_not_verified",
            message=Messages.DRIVER_NOT_VERIFIED,
        )

    is_available = None
    if status_in.status == DriverStatus.ONLINE:
        is_available = True
    elif status_in.status == DriverStatus.OFFLINE:
        is_available = False
    elif status_in.status == DriverStatus.PAUSED:
        is_available = True

    _apply_driver_status(
        driver,
        driver_status=status_in.status,
        is_available=is_available,
    )
    await session.commit()
    await session.refresh(driver)
    return driver


async def get_client_profile(
    session: AsyncSession,
    user_id: int,
) -> ClientProfileRead | None:
    client = await session.get(User, user_id)
    if client is None or client.role != UserRole.CLIENT:
        return None

    stats_result = await session.execute(
        select(
            func.count(RideRequest.id),
            func.coalesce(func.avg(RideRequest.driver_rating_for_client), 0.0),
        ).where(
            RideRequest.client_id == user_id,
            RideRequest.status == RideRequestStatus.COMPLETED,
        )
    )
    total_rides, average_rating = stats_result.one()
    return _client_profile_read(
        client,
        total_rides=int(total_rides or 0),
        average_rating=round(float(average_rating or 0.0), 2),
    )


async def update_client_profile(
    session: AsyncSession,
    user_id: int,
    profile_in: ClientProfileUpdate,
) -> ClientProfileRead | None:
    client = await session.get(User, user_id)
    if client is None or client.role != UserRole.CLIENT:
        return None

    update_fields = profile_in.model_fields_set
    if "name" in update_fields:
        client.name = profile_in.name
    if "profile_photo" in update_fields:
        client.profile_photo = profile_in.profile_photo
    await session.commit()
    await session.refresh(client)
    return await get_client_profile(session, user_id)


async def update_current_user_profile(
    session: AsyncSession,
    current_user: User,
    *,
    first_name: str | None = None,
    phone_number: str | None = None,
    profile_photo: UploadFile | None = None,
) -> User:
    _ = phone_number
    normalized_first_name = _normalize_first_name(first_name)
    current_photo = current_user.profile_photo
    new_photo_path: str | None = None

    if profile_photo is not None:
        new_photo_path = await _save_profile_photo(profile_photo)

    if normalized_first_name is not None:
        current_user.name = normalized_first_name
    if new_photo_path is not None:
        current_user.profile_photo = new_photo_path

    try:
        await session.commit()
    except Exception:
        if new_photo_path is not None:
            _delete_profile_photo_file(new_photo_path)
        await session.rollback()
        raise

    await session.refresh(current_user)
    if new_photo_path is not None:
        _delete_profile_photo_file(current_photo)
    return current_user


async def list_saved_addresses(
    session: AsyncSession,
    user_id: int,
) -> list[SavedAddress]:
    result = await session.execute(
        select(SavedAddress)
        .where(SavedAddress.user_id == user_id)
        .order_by(SavedAddress.created_at.desc(), SavedAddress.id.desc())
    )
    return list(result.scalars().all())


async def create_saved_address(
    session: AsyncSession,
    user_id: int,
    address_in: SavedAddressCreate,
) -> SavedAddress:
    saved_addresses_count = await _count_saved_addresses(session, user_id)
    if saved_addresses_count >= MAX_SAVED_ADDRESSES_PER_USER:
        raise ApiError(
            status_code=400,
            code="saved_address_limit_reached",
            message="Maximum 10 favoris par utilisateur.",
        )

    saved_address = SavedAddress(
        user_id=user_id,
        label=address_in.label,
        lat=address_in.lat,
        lon=address_in.lon,
        address_display=address_in.address_display,
    )
    session.add(saved_address)
    await session.commit()
    await session.refresh(saved_address)
    return saved_address


async def update_saved_address(
    session: AsyncSession,
    user_id: int,
    saved_address_id: int,
    address_in: SavedAddressUpdate,
) -> SavedAddress:
    saved_address = await _get_owned_saved_address(session, user_id, saved_address_id)
    saved_address.label = address_in.label
    saved_address.lat = address_in.lat
    saved_address.lon = address_in.lon
    saved_address.address_display = address_in.address_display
    await session.commit()
    await session.refresh(saved_address)
    return saved_address


async def delete_saved_address(
    session: AsyncSession,
    user_id: int,
    saved_address_id: int,
) -> None:
    saved_address = await _get_owned_saved_address(session, user_id, saved_address_id)
    await session.delete(saved_address)
    await session.commit()


async def delete_current_user_account(
    session: AsyncSession,
    current_user: User,
    *,
    deletion_reason: str | None = None,
) -> None:
    user = await session.get(User, current_user.id)
    if user is None:
        raise ApiError(
            status_code=404,
            code="user_not_found",
            message="Utilisateur introuvable.",
        )
    if user.deleted_at is not None:
        return

    await _ensure_user_can_delete_account(session, user)
    await _delete_user_saved_addresses(session, user.id)
    await _delete_user_ride_messages(session, user.id)
    await _anonymize_driver_profile(session, user.id)

    previous_profile_photo = user.profile_photo
    _anonymize_user(
        user,
        deletion_reason=_normalize_deletion_reason(deletion_reason),
    )

    try:
        await session.commit()
    except Exception:
        await session.rollback()
        raise

    await session.refresh(user)
    _delete_profile_photo_file(previous_profile_photo)


async def _ensure_user_can_delete_account(
    session: AsyncSession,
    user: User,
) -> None:
    if await _has_ride_in_progress(session, user.id):
        raise ApiError(
            status_code=409,
            code="account_deletion_ride_in_progress",
            message=(
                "Impossible de supprimer votre compte: "
                "une course est en cours (accepted/arrived/started)."
            ),
        )

    if user.role == UserRole.DRIVER and await _driver_wallet_has_non_zero_balance(
        session,
        user.id,
    ):
        raise ApiError(
            status_code=409,
            code="driver_wallet_not_settled",
            message=DRIVER_WALLET_SETTLEMENT_MESSAGE,
        )


async def _has_ride_in_progress(session: AsyncSession, user_id: int) -> bool:
    result = await session.execute(
        select(RideRequest.id)
        .where(
            or_(
                RideRequest.client_id == user_id,
                RideRequest.driver_id == user_id,
            ),
            RideRequest.status.in_(ACCOUNT_DELETION_BLOCKING_STATUSES),
        )
        .limit(1)
    )
    return result.scalar_one_or_none() is not None


async def _driver_wallet_has_non_zero_balance(
    session: AsyncSession,
    driver_id: int,
) -> bool:
    result = await session.execute(
        select(DriverWallet.total_net_earnings).where(DriverWallet.driver_id == driver_id)
    )
    net_balance = result.scalar_one_or_none()
    if net_balance is None:
        return False
    return Decimal(str(net_balance)) != Decimal("0")


async def _delete_user_saved_addresses(session: AsyncSession, user_id: int) -> None:
    await session.execute(delete(SavedAddress).where(SavedAddress.user_id == user_id))


async def _delete_user_ride_messages(session: AsyncSession, user_id: int) -> None:
    ride_ids_subquery = select(RideRequest.id).where(
        or_(
            RideRequest.client_id == user_id,
            RideRequest.driver_id == user_id,
        )
    )
    await session.execute(
        delete(RideMessage).where(
            or_(
                RideMessage.sender_id == user_id,
                RideMessage.ride_id.in_(ride_ids_subquery),
            )
        )
    )


async def _anonymize_driver_profile(session: AsyncSession, user_id: int) -> None:
    result = await session.execute(
        select(DriverProfile).where(DriverProfile.user_id == user_id)
    )
    profile = result.scalar_one_or_none()
    if profile is None:
        return

    profile.first_name = DELETED_ACCOUNT_DISPLAY_NAME
    profile.last_name = DELETED_DRIVER_PROFILE_LAST_NAME
    profile.address = None
    profile.id_card_photo = None
    profile.selfie_photo = None
    for file_field, expiry_field, _status_field, _label in DRIVER_DOCUMENT_FIELD_MAP.values():
        setattr(profile, file_field, None)
        setattr(profile, expiry_field, None)


def _anonymize_user(user: User, *, deletion_reason: str | None) -> None:
    user.name = DELETED_ACCOUNT_DISPLAY_NAME
    user.phone_number = _build_deleted_phone_hash(user)
    user.profile_photo = None
    user.refresh_token = None
    user.fcm_token = None
    user.is_blocked = True
    user.is_suspended = False
    user.suspended_until = None
    user.suspension_reason = None
    user.vehicle_brand = None
    user.vehicle_model = None
    user.vehicle_color = None
    user.vehicle_photo = None
    user.plate_number = None
    user.deleted_at = datetime.utcnow()
    user.deletion_reason = deletion_reason
    if user.role == UserRole.DRIVER:
        user.is_available = False
        user.driver_status = DriverStatus.OFFLINE
        user.pause_started_at = None


def _normalize_deletion_reason(deletion_reason: str | None) -> str | None:
    if deletion_reason is None:
        return None
    normalized = deletion_reason.strip()
    return normalized or None


def _build_deleted_phone_hash(user: User) -> str:
    seed = (
        f"{user.id}:{user.phone_number}:{datetime.utcnow().isoformat()}:"
        f"{settings.SECRET_KEY}"
    )
    digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()
    return f"del_{digest[:16]}"


def _client_profile_read(
    client: User,
    *,
    total_rides: int,
    average_rating: float,
) -> ClientProfileRead:
    return ClientProfileRead(
        id=client.id,
        name=client.name,
        phone_number=client.phone_number,
        profile_photo=client.profile_photo,
        created_at=client.created_at,
        total_rides=total_rides,
        average_rating=average_rating,
    )


def _normalize_first_name(first_name: str | None) -> str | None:
    if first_name is None:
        return None

    normalized = first_name.strip()
    if not normalized:
        raise ApiError(
            status_code=422,
            code="invalid_first_name",
            message="Le prenom doit contenir entre 2 et 50 caracteres.",
        )
    if len(normalized) < 2 or len(normalized) > 50:
        raise ApiError(
            status_code=422,
            code="invalid_first_name",
            message="Le prenom doit contenir entre 2 et 50 caracteres.",
        )
    return normalized


async def _save_profile_photo(upload_file: UploadFile) -> str:
    content = await upload_file.read()
    if not content:
        raise ApiError(
            status_code=422,
            code="invalid_profile_photo",
            message="La photo de profil est vide.",
        )
    if len(content) > MAX_PROFILE_PHOTO_SIZE_BYTES:
        raise ApiError(
            status_code=422,
            code="profile_photo_too_large",
            message="La photo de profil depasse 5 Mo.",
        )

    image = _open_image_or_raise(content)
    suffix, output_format = _resolve_image_format(image)
    resampling = getattr(Image, "Resampling", Image)
    processed_image = ImageOps.fit(
        image.convert("RGB"),
        (PROFILE_PHOTO_DIMENSION, PROFILE_PHOTO_DIMENSION),
        method=resampling.LANCZOS,
    )

    PROFILE_PHOTO_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}{suffix}"
    file_path = PROFILE_PHOTO_STORAGE_DIR / filename
    processed_image.save(file_path, format=output_format, optimize=True)
    return f"{PROFILE_PHOTO_PUBLIC_PREFIX}{filename}"


def _open_image_or_raise(content: bytes) -> Image.Image:
    try:
        image = Image.open(BytesIO(content))
        image.load()
    except Exception as exc:
        raise ApiError(
            status_code=422,
            code="invalid_profile_photo",
            message="Format image non supporte. Utilisez jpg, png ou webp.",
        ) from exc
    return image


def _resolve_image_format(image: Image.Image) -> tuple[str, str]:
    format_name = (image.format or "").upper()
    if format_name in {"JPEG", "JPG"}:
        return ".jpg", "JPEG"
    if format_name == "PNG":
        return ".png", "PNG"
    if format_name == "WEBP":
        return ".webp", "WEBP"
    raise ApiError(
        status_code=422,
        code="invalid_profile_photo",
        message="Format image non supporte. Utilisez jpg, png ou webp.",
    )


def _delete_profile_photo_file(profile_photo_path: str | None) -> None:
    if profile_photo_path is None:
        return
    if not profile_photo_path.startswith(PROFILE_PHOTO_PUBLIC_PREFIX):
        return

    relative_name = profile_photo_path.replace(PROFILE_PHOTO_PUBLIC_PREFIX, "", 1)
    file_path = PROFILE_PHOTO_STORAGE_DIR / relative_name
    try:
        resolved_path = file_path.resolve()
        resolved_root = PROFILE_PHOTO_STORAGE_DIR.resolve()
    except FileNotFoundError:
        return

    if resolved_root not in resolved_path.parents:
        return
    if resolved_path.exists():
        resolved_path.unlink()


def _apply_driver_status(
    driver: User,
    *,
    driver_status: DriverStatus,
    is_available: bool | None,
) -> None:
    driver.driver_status = driver_status
    if is_available is not None:
        driver.is_available = is_available
    if driver_status == DriverStatus.PAUSED:
        driver.pause_started_at = datetime.utcnow()
    else:
        driver.pause_started_at = None


async def is_driver_verified(
    session: AsyncSession,
    driver_id: int,
) -> bool:
    result = await session.execute(
        select(DriverProfile.verification_status).where(
            DriverProfile.user_id == driver_id
        )
    )
    verification_status = result.scalar_one_or_none()
    return verification_status == DriverVerificationStatus.VERIFIED


async def _count_saved_addresses(session: AsyncSession, user_id: int) -> int:
    result = await session.execute(
        select(func.count(SavedAddress.id)).where(SavedAddress.user_id == user_id)
    )
    return int(result.scalar_one() or 0)


async def _get_owned_saved_address(
    session: AsyncSession,
    user_id: int,
    saved_address_id: int,
) -> SavedAddress:
    saved_address = await session.get(SavedAddress, saved_address_id)
    if saved_address is None:
        raise ApiError(
            status_code=404,
            code="saved_address_not_found",
            message="Adresse favorite introuvable.",
        )
    if saved_address.user_id != user_id:
        raise ApiError(
            status_code=403,
            code="saved_address_forbidden",
            message="Vous ne pouvez modifier que vos propres adresses.",
        )
    return saved_address


async def ensure_user_not_suspended(
    session: AsyncSession,
    user: User,
) -> None:
    if not user.is_suspended:
        return

    if _is_suspension_expired(user):
        await _clear_user_suspension(session, user)
        return

    raise ApiError(
        status_code=403,
        code=SUSPENSION_CODE,
        message=build_suspension_message(user),
    )


def build_suspension_message(user: User) -> str:
    reason = (user.suspension_reason or "").strip() or "Motif non precise"
    if user.suspended_until is None:
        return f"Compte suspendu: {reason}. Suspension permanente."
    return (
        f"Compte suspendu: {reason}. "
        f"Fin de suspension: {_format_suspension_datetime(user.suspended_until)}."
    )


def _is_suspension_expired(user: User) -> bool:
    if user.suspended_until is None:
        return False
    return user.suspended_until <= datetime.utcnow()


async def _clear_user_suspension(session: AsyncSession, user: User) -> None:
    user.is_suspended = False
    user.suspended_until = None
    user.suspension_reason = None
    await session.commit()
    await session.refresh(user)


def _format_suspension_datetime(value: datetime) -> str:
    return value.strftime("%Y-%m-%d %H:%M UTC")


async def reset_daily_cancellation_counters(session: AsyncSession) -> int:
    result = await session.execute(update(User).values(cancellations_today=0))
    await session.commit()
    return int(result.rowcount or 0)
