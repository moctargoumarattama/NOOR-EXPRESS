"""add paused driver status and pause timestamp

Revision ID: 2026_05_02_driver_pause_status
Revises: 2026_05_01_driver_max_radius
Create Date: 2026-05-02
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_02_driver_pause_status"
down_revision = "2026_05_01_driver_max_radius"
branch_labels = None
depends_on = None


def _column_names(table_name: str) -> set[str]:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return {column["name"] for column in inspector.get_columns(table_name)}


def upgrade() -> None:
    user_columns = _column_names("users")
    if "pause_started_at" not in user_columns:
        op.add_column(
            "users",
            sa.Column("pause_started_at", sa.DateTime(), nullable=True),
        )

    if "driver_status" not in user_columns:
        return

    bind = op.get_bind()
    if bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE users "
            "MODIFY COLUMN driver_status "
            "ENUM('offline','online','busy','paused') NULL"
        )

    op.execute(
        "UPDATE users "
        "SET driver_status = 'online', is_available = 0 "
        "WHERE driver_status = 'busy'"
    )

    if bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE users "
            "MODIFY COLUMN driver_status "
            "ENUM('offline','online','paused') NULL"
        )


def downgrade() -> None:
    user_columns = _column_names("users")
    if "driver_status" in user_columns:
        bind = op.get_bind()
        if bind.dialect.name == "mysql":
            op.execute(
                "ALTER TABLE users "
                "MODIFY COLUMN driver_status "
                "ENUM('offline','online','busy','paused') NULL"
            )
        op.execute(
            "UPDATE users "
            "SET driver_status = 'busy' "
            "WHERE driver_status = 'online' AND is_available = 0"
        )
        if bind.dialect.name == "mysql":
            op.execute(
                "ALTER TABLE users "
                "MODIFY COLUMN driver_status "
                "ENUM('offline','online','busy') NULL"
            )

    if "pause_started_at" in user_columns:
        op.drop_column("users", "pause_started_at")
