from sqlalchemy import inspect, text
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import AsyncEngine

from app.db.database import engine


RIDE_REQUEST_COMPLETION_STATUSES = (
    "accepted",
    "arrived",
    "started",
    "completed",
)
RIDE_REQUEST_V1_STATUSES = (
    "pending",
    "offered",
    "accepted",
    "arrived",
    "started",
    "completed",
    "cancelled",
    "expired",
)
RIDE_OFFER_V1_STATUSES = (
    "pending",
    "accepted",
    "rejected",
    "invalidated",
    "expired",
)


def _table_names(connection: Connection) -> set[str]:
    return set(inspect(connection).get_table_names())


def _column_names(connection: Connection, table_name: str) -> set[str]:
    return {
        column["name"]
        for column in inspect(connection).get_columns(table_name)
    }


def _format_mysql_enum(values: tuple[str, ...]) -> str:
    return ", ".join(f"'{value}'" for value in values)


def _ensure_ride_request_agreed_price(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "ride_requests" not in table_names:
        return

    ride_request_columns = _column_names(connection, "ride_requests")
    if "agreed_price" not in ride_request_columns:
        connection.execute(
            text(
                "ALTER TABLE ride_requests "
                "ADD COLUMN agreed_price NUMERIC(10,2) NULL"
            )
        )
        ride_request_columns = _column_names(connection, "ride_requests")

    if {
        "agreed_price",
        "estimated_price",
        "status",
    }.issubset(ride_request_columns):
        price_source = "estimated_price"
        if "final_price" in ride_request_columns:
            price_source = "COALESCE(final_price, estimated_price)"

        completion_statuses = ", ".join(
            f"'{status}'" for status in RIDE_REQUEST_COMPLETION_STATUSES
        )
        connection.execute(
            text(
                f"""
                UPDATE ride_requests
                SET agreed_price = {price_source}
                WHERE agreed_price IS NULL
                  AND status IN ({completion_statuses})
                """
            )
        )


def _ensure_mysql_v1_statuses(connection: Connection) -> None:
    if connection.dialect.name != "mysql":
        return

    table_names = _table_names(connection)
    if "ride_requests" in table_names:
        connection.execute(
            text(
                "ALTER TABLE ride_requests "
                f"MODIFY COLUMN status ENUM({_format_mysql_enum(RIDE_REQUEST_V1_STATUSES)}) "
                "NOT NULL DEFAULT 'pending'"
            )
        )

    if "ride_offers" in table_names:
        connection.execute(
            text(
                "ALTER TABLE ride_offers "
                f"MODIFY COLUMN status ENUM({_format_mysql_enum(RIDE_OFFER_V1_STATUSES)}) "
                "NOT NULL DEFAULT 'pending'"
            )
        )


def ensure_database_schema_sync(connection: Connection) -> None:
    _ensure_ride_request_agreed_price(connection)
    _ensure_mysql_v1_statuses(connection)


async def ensure_database_schema(async_engine: AsyncEngine | None = None) -> None:
    target_engine = async_engine or engine
    async with target_engine.begin() as connection:
        await connection.run_sync(ensure_database_schema_sync)
