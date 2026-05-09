"""fix driver document columns to mediumtext

Revision ID: 2026_05_04_driver_documents_mediumtext_fix
Revises: 2026_05_02_driver_pause_status
Create Date: 2026-05-04
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql


revision = "2026_05_04_driver_documents_mediumtext_fix"
down_revision = "2026_05_02_driver_pause_status"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "driver_profiles",
        "driver_license_file",
        existing_type=sa.String(length=255),
        type_=mysql.MEDIUMTEXT(),
        existing_nullable=True,
    )
    op.alter_column(
        "driver_profiles",
        "vehicle_registration_file",
        existing_type=sa.String(length=255),
        type_=mysql.MEDIUMTEXT(),
        existing_nullable=True,
    )
    op.alter_column(
        "driver_profiles",
        "vehicle_insurance_file",
        existing_type=sa.String(length=255),
        type_=mysql.MEDIUMTEXT(),
        existing_nullable=True,
    )
    op.alter_column(
        "driver_profiles",
        "technical_inspection_file",
        existing_type=sa.String(length=255),
        type_=mysql.MEDIUMTEXT(),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "driver_profiles",
        "technical_inspection_file",
        existing_type=mysql.MEDIUMTEXT(),
        type_=sa.String(length=255),
        existing_nullable=True,
    )
    op.alter_column(
        "driver_profiles",
        "vehicle_insurance_file",
        existing_type=mysql.MEDIUMTEXT(),
        type_=sa.String(length=255),
        existing_nullable=True,
    )
    op.alter_column(
        "driver_profiles",
        "vehicle_registration_file",
        existing_type=mysql.MEDIUMTEXT(),
        type_=sa.String(length=255),
        existing_nullable=True,
    )
    op.alter_column(
        "driver_profiles",
        "driver_license_file",
        existing_type=mysql.MEDIUMTEXT(),
        type_=sa.String(length=255),
        existing_nullable=True,
    )
