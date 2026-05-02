"""add driver max radius setting

Revision ID: 2026_05_01_driver_max_radius
Revises: 2026_05_01_cancellation_policy
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_01_driver_max_radius"
down_revision = "2026_05_01_cancellation_policy"
branch_labels = None
depends_on = None


def _column_names(table_name: str) -> set[str]:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return {column["name"] for column in inspector.get_columns(table_name)}


def upgrade() -> None:
    user_columns = _column_names("users")
    if "max_radius_km" not in user_columns:
        op.add_column(
            "users",
            sa.Column(
                "max_radius_km",
                sa.Integer(),
                nullable=True,
                server_default="5",
            ),
        )

    op.execute(
        "UPDATE users "
        "SET max_radius_km = 5 "
        "WHERE role = 'driver' AND max_radius_km IS NULL"
    )


def downgrade() -> None:
    user_columns = _column_names("users")
    if "max_radius_km" in user_columns:
        op.drop_column("users", "max_radius_km")
