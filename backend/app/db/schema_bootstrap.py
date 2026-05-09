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
RIDE_REPORT_V2_STATUSES = (
    "nouveau",
    "en_cours",
    "resolu",
    "classe_sans_suite",
)
RIDE_REPORT_LEGACY_STATUSES = (
    "ouvert",
    "traite",
)
DRIVER_STATUS_PAUSE_TRANSITION_VALUES = (
    "offline",
    "online",
    "busy",
    "paused",
)
DRIVER_STATUS_VALUES = (
    "offline",
    "online",
    "paused",
)


def _table_names(connection: Connection) -> set[str]:
    return set(inspect(connection).get_table_names())


def _column_names(connection: Connection, table_name: str) -> set[str]:
    return {column["name"] for column in inspect(connection).get_columns(table_name)}


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
        connection.execute(text(f"""
                UPDATE ride_requests
                SET agreed_price = {price_source}
                WHERE agreed_price IS NULL
                  AND status IN ({completion_statuses})
                """))


def _ensure_ride_request_history_columns(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "ride_requests" not in table_names:
        return

    ride_request_columns = _column_names(connection, "ride_requests")
    if "distance_km" not in ride_request_columns:
        connection.execute(
            text("ALTER TABLE ride_requests " "ADD COLUMN distance_km FLOAT NULL")
        )
    if "duration_minutes" not in ride_request_columns:
        connection.execute(
            text(
                "ALTER TABLE ride_requests " "ADD COLUMN duration_minutes INTEGER NULL"
            )
        )
    if "completed_at" not in ride_request_columns:
        connection.execute(
            text("ALTER TABLE ride_requests " "ADD COLUMN completed_at DATETIME NULL")
        )


def _ensure_ride_request_share_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "ride_requests" not in table_names:
        return

    ride_request_columns = _column_names(connection, "ride_requests")
    if "share_token" not in ride_request_columns:
        connection.execute(
            text("ALTER TABLE ride_requests ADD COLUMN share_token VARCHAR(36) NULL")
        )
    if "share_token_created_at" not in ride_request_columns:
        connection.execute(
            text(
                "ALTER TABLE ride_requests "
                "ADD COLUMN share_token_created_at DATETIME NULL"
            )
        )

    indexes = inspect(connection).get_indexes("ride_requests")
    index_names = {index["name"] for index in indexes}
    if "ix_ride_requests_share_token" not in index_names:
        connection.execute(
            text(
                "CREATE UNIQUE INDEX ix_ride_requests_share_token "
                "ON ride_requests (share_token)"
            )
        )


def _ensure_driver_wallets_table(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "driver_wallets" in table_names:
        return

    connection.execute(text("""
            CREATE TABLE driver_wallets (
                id INTEGER PRIMARY KEY,
                driver_id INTEGER NOT NULL UNIQUE,
                total_completed_rides INTEGER NOT NULL DEFAULT 0,
                total_gross_earnings NUMERIC(12,2) NOT NULL DEFAULT 0,
                total_commission NUMERIC(12,2) NOT NULL DEFAULT 0,
                total_net_earnings NUMERIC(12,2) NOT NULL DEFAULT 0,
                created_at DATETIME NULL,
                updated_at DATETIME NULL,
                FOREIGN KEY(driver_id) REFERENCES users(id)
            )
            """))


def _ensure_ride_messages_table(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "ride_messages" not in table_names:
        connection.execute(text("""
                CREATE TABLE ride_messages (
                    id INTEGER PRIMARY KEY,
                    ride_id INTEGER NOT NULL,
                    sender_id INTEGER NOT NULL,
                    sender_role VARCHAR(20) NOT NULL,
                    content VARCHAR(500) NOT NULL,
                    is_read BOOLEAN NOT NULL DEFAULT 0,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(ride_id) REFERENCES ride_requests(id),
                    FOREIGN KEY(sender_id) REFERENCES users(id)
                )
                """))
        return

    ride_message_columns = _column_names(connection, "ride_messages")
    if "created_at" not in ride_message_columns:
        connection.execute(
            text("ALTER TABLE ride_messages ADD COLUMN created_at DATETIME NULL")
        )

    connection.execute(
        text(
            "UPDATE ride_messages "
            "SET created_at = CURRENT_TIMESTAMP "
            "WHERE created_at IS NULL"
        )
    )

    if connection.dialect.name == "mysql":
        connection.execute(
            text(
                "ALTER TABLE ride_messages "
                "MODIFY COLUMN created_at DATETIME NOT NULL "
                "DEFAULT CURRENT_TIMESTAMP"
            )
        )


def _ensure_saved_addresses_table(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "saved_addresses" in table_names or "users" not in table_names:
        return

    if connection.dialect.name == "mysql":
        connection.execute(text("""
                CREATE TABLE saved_addresses (
                    id INTEGER PRIMARY KEY AUTO_INCREMENT,
                    user_id INTEGER NOT NULL,
                    label VARCHAR(120) NOT NULL,
                    lat FLOAT NOT NULL,
                    lon FLOAT NOT NULL,
                    address_display TEXT NOT NULL,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """))
    else:
        connection.execute(text("""
                CREATE TABLE saved_addresses (
                    id INTEGER PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    label VARCHAR(120) NOT NULL,
                    lat FLOAT NOT NULL,
                    lon FLOAT NOT NULL,
                    address_display TEXT NOT NULL,
                    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """))
    connection.execute(
        text("CREATE INDEX ix_saved_addresses_user_id " "ON saved_addresses (user_id)")
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


def _ensure_user_block_flag(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "is_blocked" in user_columns:
        return

    if connection.dialect.name == "mysql":
        connection.execute(
            text(
                "ALTER TABLE users ADD COLUMN is_blocked BOOLEAN NOT NULL DEFAULT FALSE"
            )
        )
        return

    connection.execute(
        text("ALTER TABLE users ADD COLUMN is_blocked BOOLEAN NOT NULL DEFAULT 0")
    )


def _ensure_user_suspension_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "is_suspended" not in user_columns:
        default_false = "FALSE" if connection.dialect.name == "mysql" else "0"
        connection.execute(
            text(
                "ALTER TABLE users "
                f"ADD COLUMN is_suspended BOOLEAN NOT NULL DEFAULT {default_false}"
            )
        )
    if "suspended_until" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN suspended_until DATETIME NULL")
        )
    if "suspension_reason" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN suspension_reason TEXT NULL")
        )


def _ensure_user_deletion_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "deleted_at" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN deleted_at DATETIME NULL")
        )
    if "deletion_reason" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN deletion_reason TEXT NULL")
        )


def _ensure_user_suspensions_table(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "user_suspensions" in table_names or "users" not in table_names:
        return

    if connection.dialect.name == "mysql":
        connection.execute(text("""
                CREATE TABLE user_suspensions (
                    id INTEGER PRIMARY KEY AUTO_INCREMENT,
                    user_id INTEGER NOT NULL,
                    reason TEXT NOT NULL,
                    suspended_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    suspended_until DATETIME NULL,
                    lifted_at DATETIME NULL,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """))
    else:
        connection.execute(text("""
                CREATE TABLE user_suspensions (
                    id INTEGER PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    reason TEXT NOT NULL,
                    suspended_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    suspended_until DATETIME NULL,
                    lifted_at DATETIME NULL,
                    FOREIGN KEY(user_id) REFERENCES users(id)
                )
                """))
    connection.execute(
        text(
            "CREATE INDEX ix_user_suspensions_user_id " "ON user_suspensions (user_id)"
        )
    )


def _ensure_user_cancellation_policy_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "cancellations_today" not in user_columns:
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN cancellations_today INTEGER NOT NULL DEFAULT 0"
            )
        )
    if "cancellations_last_24h" not in user_columns:
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN cancellations_last_24h INTEGER NOT NULL DEFAULT 0"
            )
        )
    if "cancellation_window_started_at" not in user_columns:
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN cancellation_window_started_at DATETIME NULL"
            )
        )
    if "ride_request_blocked_until" not in user_columns:
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN ride_request_blocked_until DATETIME NULL"
            )
        )


def _ensure_driver_max_radius_field(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "max_radius_km" in user_columns:
        return

    connection.execute(
        text(
            "ALTER TABLE users "
            "ADD COLUMN max_radius_km INTEGER NULL DEFAULT 5"
        )
    )
    connection.execute(
        text(
            "UPDATE users "
            "SET max_radius_km = 5 "
            "WHERE role = 'driver' AND max_radius_km IS NULL"
        )
    )


def _ensure_driver_pause_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "pause_started_at" not in user_columns:
        connection.execute(
            text(
                "ALTER TABLE users "
                "ADD COLUMN pause_started_at DATETIME NULL"
            )
        )

    if connection.dialect.name != "mysql" or "driver_status" not in user_columns:
        return

    connection.execute(
        text(
            "ALTER TABLE users "
            "MODIFY COLUMN driver_status "
            f"ENUM({_format_mysql_enum(DRIVER_STATUS_PAUSE_TRANSITION_VALUES)}) NULL"
        )
    )
    connection.execute(
        text(
            "UPDATE users "
            "SET driver_status = 'online' "
            "WHERE driver_status = 'busy'"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE users "
            "MODIFY COLUMN driver_status "
            f"ENUM({_format_mysql_enum(DRIVER_STATUS_VALUES)}) NULL"
        )
    )


def _ensure_driver_last_known_position_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "users" not in table_names:
        return

    user_columns = _column_names(connection, "users")
    if "last_known_lat" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN last_known_lat FLOAT NULL")
        )
    if "last_known_lon" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN last_known_lon FLOAT NULL")
        )
    if "last_position_at" not in user_columns:
        connection.execute(
            text("ALTER TABLE users ADD COLUMN last_position_at DATETIME NULL")
        )


def _ensure_ride_request_cancelled_role_values(connection: Connection) -> None:
    if connection.dialect.name != "mysql":
        return

    table_names = _table_names(connection)
    if "ride_requests" not in table_names:
        return

    ride_columns = _column_names(connection, "ride_requests")
    if "cancelled_by_role" not in ride_columns:
        return

    connection.execute(
        text(
            "ALTER TABLE ride_requests "
            "MODIFY COLUMN cancelled_by_role "
            "ENUM('client','passenger','driver','system') NULL"
        )
    )
    connection.execute(
        text(
            "UPDATE ride_requests "
            "SET cancelled_by_role = 'passenger' "
            "WHERE cancelled_by_role = 'client'"
        )
    )
    connection.execute(
        text(
            "ALTER TABLE ride_requests "
            "MODIFY COLUMN cancelled_by_role "
            "ENUM('passenger','driver','system') NULL"
        )
    )


def _ensure_ride_reports_workflow_fields(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "ride_reports" not in table_names:
        return

    report_columns = _column_names(connection, "ride_reports")
    if "note_admin" not in report_columns:
        connection.execute(
            text("ALTER TABLE ride_reports ADD COLUMN note_admin TEXT NULL")
        )

    if connection.dialect.name == "mysql":
        expanded_values = _format_mysql_enum(
            (*RIDE_REPORT_LEGACY_STATUSES, *RIDE_REPORT_V2_STATUSES)
        )
        connection.execute(
            text(
                "ALTER TABLE ride_reports "
                f"MODIFY COLUMN status ENUM({expanded_values}) "
                "NOT NULL DEFAULT 'nouveau'"
            )
        )

    connection.execute(
        text("UPDATE ride_reports SET status = 'nouveau' " "WHERE status = 'ouvert'")
    )
    connection.execute(
        text("UPDATE ride_reports SET status = 'resolu' " "WHERE status = 'traite'")
    )

    if connection.dialect.name != "mysql":
        return

    connection.execute(
        text(
            "ALTER TABLE ride_reports "
            f"MODIFY COLUMN status ENUM({_format_mysql_enum(RIDE_REPORT_V2_STATUSES)}) "
            "NOT NULL DEFAULT 'nouveau'"
        )
    )


def _ensure_broadcast_history_table(connection: Connection) -> None:
    table_names = _table_names(connection)
    if "broadcast_history" not in table_names:
        if connection.dialect.name == "mysql":
            connection.execute(text("""
                CREATE TABLE broadcast_history (
                        id INTEGER PRIMARY KEY AUTO_INCREMENT,
                        target VARCHAR(32) NOT NULL,
                        title VARCHAR(60) NOT NULL,
                        message VARCHAR(200) NOT NULL,
                        notification_type VARCHAR(20) NOT NULL,
                        sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        estimated_recipients INTEGER NOT NULL DEFAULT 0,
                        fcm_sent_count INTEGER NOT NULL DEFAULT 0,
                        fcm_failed_count INTEGER NOT NULL DEFAULT 0,
                        fcm_status VARCHAR(32) NOT NULL DEFAULT 'failed',
                        fcm_error_reason TEXT NULL
                    )
                    """))
        else:
            connection.execute(text("""
                    CREATE TABLE broadcast_history (
                        id INTEGER PRIMARY KEY,
                        target VARCHAR(32) NOT NULL,
                        title VARCHAR(60) NOT NULL,
                        message VARCHAR(200) NOT NULL,
                        notification_type VARCHAR(20) NOT NULL,
                        sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        estimated_recipients INTEGER NOT NULL DEFAULT 0,
                        fcm_sent_count INTEGER NOT NULL DEFAULT 0,
                        fcm_failed_count INTEGER NOT NULL DEFAULT 0,
                        fcm_status VARCHAR(32) NOT NULL DEFAULT 'failed',
                        fcm_error_reason TEXT NULL
                    )
                    """))
        connection.execute(
            text(
                "CREATE INDEX ix_broadcast_history_sent_at "
                "ON broadcast_history (sent_at)"
            )
        )
        return

    history_columns = _column_names(connection, "broadcast_history")
    if "target" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN target VARCHAR(32) NOT NULL DEFAULT 'all'"
            )
        )
    if "title" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN title VARCHAR(60) NOT NULL DEFAULT ''"
            )
        )
    if "message" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN message VARCHAR(200) NOT NULL DEFAULT ''"
            )
        )
    if "notification_type" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN notification_type VARCHAR(20) NOT NULL DEFAULT 'info'"
            )
        )
    if "sent_at" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP"
            )
        )
    if "estimated_recipients" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN estimated_recipients INTEGER NOT NULL DEFAULT 0"
            )
        )
    if "fcm_sent_count" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN fcm_sent_count INTEGER NOT NULL DEFAULT 0"
            )
        )
    if "fcm_failed_count" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN fcm_failed_count INTEGER NOT NULL DEFAULT 0"
            )
        )
    if "fcm_status" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN fcm_status VARCHAR(32) NOT NULL DEFAULT 'sent'"
            )
        )
    if "fcm_error_reason" not in history_columns:
        connection.execute(
            text(
                "ALTER TABLE broadcast_history "
                "ADD COLUMN fcm_error_reason TEXT NULL"
            )
        )

    connection.execute(
        text(
            "UPDATE broadcast_history "
            "SET fcm_sent_count = estimated_recipients "
            "WHERE fcm_sent_count = 0 "
            "AND estimated_recipients > 0 "
            "AND fcm_status = 'sent'"
        )
    )
    connection.execute(
        text(
            "UPDATE broadcast_history "
            "SET fcm_status = 'failed' "
            "WHERE fcm_status IS NULL OR fcm_status = ''"
        )
    )

    indexes = inspect(connection).get_indexes("broadcast_history")
    index_names = {index["name"] for index in indexes}
    if "ix_broadcast_history_sent_at" not in index_names:
        connection.execute(
            text(
                "CREATE INDEX ix_broadcast_history_sent_at "
                "ON broadcast_history (sent_at)"
            )
        )


def ensure_database_schema_sync(connection: Connection) -> None:
    _ensure_user_block_flag(connection)
    _ensure_user_suspension_fields(connection)
    _ensure_user_deletion_fields(connection)
    _ensure_user_cancellation_policy_fields(connection)
    _ensure_driver_max_radius_field(connection)
    _ensure_driver_pause_fields(connection)
    _ensure_driver_last_known_position_fields(connection)
    _ensure_ride_request_agreed_price(connection)
    _ensure_ride_request_history_columns(connection)
    _ensure_ride_request_share_fields(connection)
    _ensure_ride_request_cancelled_role_values(connection)
    _ensure_driver_wallets_table(connection)
    _ensure_ride_messages_table(connection)
    _ensure_saved_addresses_table(connection)
    _ensure_user_suspensions_table(connection)
    _ensure_ride_reports_workflow_fields(connection)
    _ensure_broadcast_history_table(connection)
    _ensure_mysql_v1_statuses(connection)


async def ensure_database_schema(async_engine: AsyncEngine | None = None) -> None:
    target_engine = async_engine or engine
    async with target_engine.begin() as connection:
        await connection.run_sync(ensure_database_schema_sync)
