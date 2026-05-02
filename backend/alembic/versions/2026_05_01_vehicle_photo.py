"""add driver vehicle photo

Revision ID: 2026_05_01_vehicle_photo
Revises: 2026_05_01_driver_documents
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql


revision = "2026_05_01_vehicle_photo"
down_revision = "2026_05_01_driver_documents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("vehicle_photo", mysql.MEDIUMTEXT()))


def downgrade() -> None:
    op.drop_column("users", "vehicle_photo")
