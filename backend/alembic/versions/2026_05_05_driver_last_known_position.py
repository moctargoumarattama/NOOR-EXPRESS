"""add last known driver position fields on users

Revision ID: 2026_05_05_driver_last_known_position
Revises: 2026_05_05_vehicle_photo_mediumtext_fix
Create Date: 2026-05-05
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_05_driver_last_known_position"
down_revision = "2026_05_05_vehicle_photo_mediumtext_fix"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("last_known_lat", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("last_known_lon", sa.Float(), nullable=True))
    op.add_column("users", sa.Column("last_position_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "last_position_at")
    op.drop_column("users", "last_known_lon")
    op.drop_column("users", "last_known_lat")
