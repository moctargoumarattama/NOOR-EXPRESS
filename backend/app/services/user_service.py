from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.api_errors import ApiError
from app.models.driver_profile import DriverProfile, DriverVerificationStatus
from app.models.user import DriverStatus, User, UserRole
from app.models.ride_request import RideRequest, RideRequestStatus
from app.schemas.user import (
    ClientProfileRead,
    ClientProfileUpdate,
    DriverAvailabilityUpdate,
    DriverProfileUpdate,
    UserCreate,
)


class UserPhoneAlreadyExistsError(Exception):
    pass


async def create_user(session: AsyncSession, user_in: UserCreate) -> User:
    existing_user = await get_user_by_phone_number(session, user_in.phone_number)
    if existing_user is not None:
        raise UserPhoneAlreadyExistsError("Phone number already exists")

    user = User(
        phone_number=user_in.phone_number,
        name=user_in.name,
        role=user_in.role,
        is_available=True if user_in.role == UserRole.DRIVER else None,
        driver_status=DriverStatus.OFFLINE if user_in.role == UserRole.DRIVER else None,
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise UserPhoneAlreadyExistsError("Phone number already exists") from exc
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
    return await get_user_by_phone_number(session, phone_number)


async def update_driver_status(
    session: AsyncSession,
    driver_id: int,
    driver_status: DriverStatus,
) -> User | None:
    driver = await session.get(User, driver_id)
    if driver is None or driver.role != UserRole.DRIVER:
        return None

    driver.driver_status = driver_status
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

    if availability_in.is_available and not await is_driver_verified(session, driver_id):
        raise ApiError(
            status_code=403,
            code="driver_not_verified",
            message="Driver verification is required.",
        )

    driver.is_available = availability_in.is_available
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


async def is_driver_verified(
    session: AsyncSession,
    driver_id: int,
) -> bool:
    result = await session.execute(
        select(DriverProfile.verification_status).where(DriverProfile.user_id == driver_id)
    )
    verification_status = result.scalar_one_or_none()
    return verification_status == DriverVerificationStatus.VERIFIED
