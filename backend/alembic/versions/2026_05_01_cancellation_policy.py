"""add cancellation policy counters and blocked window

Revision ID: 2026_05_01_cancellation_policy
Revises: 2026_05_01_admin_notifications_broadcast
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_01_cancellation_policy"
down_revision = "2026_05_01_admin_notifications_broadcast"
branch_labels = None
depends_on = None


def _column_names(table_name: str) -> set[str]:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return {column["name"] for column in inspector.get_columns(table_name)}


def upgrade() -> None:
    user_columns = _column_names("users")
    if "cancellations_today" not in user_columns:
        op.add_column(
            "users",
            sa.Column(
                "cancellations_today",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )
    if "cancellations_last_24h" not in user_columns:
        op.add_column(
            "users",
            sa.Column(
                "cancellations_last_24h",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )
    if "cancellation_window_started_at" not in user_columns:
        op.add_column(
            "users",
            sa.Column("cancellation_window_started_at", sa.DateTime(), nullable=True),
        )
    if "ride_request_blocked_until" not in user_columns:
        op.add_column(
            "users",
            sa.Column("ride_request_blocked_until", sa.DateTime(), nullable=True),
        )

    bind = op.get_bind()
    ride_columns = _column_names("ride_requests")
    if "cancelled_by_role" in ride_columns and bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE ride_requests "
            "MODIFY COLUMN cancelled_by_role "
            "ENUM('client','passenger','driver','system') NULL"
        )
        op.execute(
            "UPDATE ride_requests "
            "SET cancelled_by_role = 'passenger' "
            "WHERE cancelled_by_role = 'client'"
        )
        op.execute(
            "ALTER TABLE ride_requests "
            "MODIFY COLUMN cancelled_by_role ENUM('passenger','driver','system') NULL"
        )
    else:
        op.execute(
            "UPDATE ride_requests "
            "SET cancelled_by_role = 'passenger' "
            "WHERE cancelled_by_role = 'client'"
        )


def downgrade() -> None:
    bind = op.get_bind()
    ride_columns = _column_names("ride_requests")
    if "cancelled_by_role" in ride_columns and bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE ride_requests "
            "MODIFY COLUMN cancelled_by_role "
            "ENUM('client','passenger','driver','system') NULL"
        )
        op.execute(
            "UPDATE ride_requests "
            "SET cancelled_by_role = 'client' "
            "WHERE cancelled_by_role = 'passenger'"
        )
        op.execute(
            "UPDATE ride_requests "
            "SET cancelled_by_role = NULL "
            "WHERE cancelled_by_role = 'system'"
        )
        op.execute(
            "ALTER TABLE ride_requests "
            "MODIFY COLUMN cancelled_by_role ENUM('driver','client') NULL"
        )
    elif "cancelled_by_role" in ride_columns:
        op.execute(
            "UPDATE ride_requests "
            "SET cancelled_by_role = 'client' "
            "WHERE cancelled_by_role = 'passenger'"
        )
        op.execute(
            "UPDATE ride_requests "
            "SET cancelled_by_role = NULL "
            "WHERE cancelled_by_role = 'system'"
        )

    user_columns = _column_names("users")
    if "ride_request_blocked_until" in user_columns:
        op.drop_column("users", "ride_request_blocked_until")
    if "cancellation_window_started_at" in user_columns:
        op.drop_column("users", "cancellation_window_started_at")
    if "cancellations_last_24h" in user_columns:
        op.drop_column("users", "cancellations_last_24h")
    if "cancellations_today" in user_columns:
        op.drop_column("users", "cancellations_today")
