"""force users.vehicle_photo to mediumtext

Revision ID: 2026_05_05_vehicle_photo_mediumtext_fix
Revises: 2026_05_05_passenger_ready_at
Create Date: 2026-05-05
"""

from alembic import op


revision = "2026_05_05_vehicle_photo_mediumtext_fix"
down_revision = "2026_05_05_passenger_ready_at"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE users MODIFY COLUMN vehicle_photo MEDIUMTEXT NULL"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE users MODIFY COLUMN vehicle_photo VARCHAR(255) NULL"
    )
