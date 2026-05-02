"""add private driver legal documents

Revision ID: 2026_05_01_driver_documents
Revises:
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql


revision = "2026_05_01_driver_documents"
down_revision = None
branch_labels = None
depends_on = None


document_status_enum = sa.Enum(
    "en_attente",
    "validé",
    "expiré",
    "rejeté",
    name="driver_document_status",
)


def upgrade() -> None:
    op.add_column(
        "driver_profiles",
        sa.Column("driver_license_file", mysql.MEDIUMTEXT(), nullable=True),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("driver_license_expires_at", sa.Date()),
    )
    op.add_column(
        "driver_profiles",
        sa.Column(
            "driver_license_status",
            document_status_enum,
            nullable=False,
            server_default="en_attente",
        ),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("vehicle_registration_file", mysql.MEDIUMTEXT(), nullable=True),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("vehicle_registration_expires_at", sa.Date()),
    )
    op.add_column(
        "driver_profiles",
        sa.Column(
            "vehicle_registration_status",
            document_status_enum,
            nullable=False,
            server_default="en_attente",
        ),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("vehicle_insurance_file", mysql.MEDIUMTEXT(), nullable=True),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("vehicle_insurance_expires_at", sa.Date()),
    )
    op.add_column(
        "driver_profiles",
        sa.Column(
            "vehicle_insurance_status",
            document_status_enum,
            nullable=False,
            server_default="en_attente",
        ),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("technical_inspection_file", mysql.MEDIUMTEXT(), nullable=True),
    )
    op.add_column(
        "driver_profiles",
        sa.Column("technical_inspection_expires_at", sa.Date()),
    )
    op.add_column(
        "driver_profiles",
        sa.Column(
            "technical_inspection_status",
            document_status_enum,
            nullable=False,
            server_default="en_attente",
        ),
    )


def downgrade() -> None:
    op.drop_column("driver_profiles", "technical_inspection_status")
    op.drop_column("driver_profiles", "technical_inspection_expires_at")
    op.drop_column("driver_profiles", "technical_inspection_file")
    op.drop_column("driver_profiles", "vehicle_insurance_status")
    op.drop_column("driver_profiles", "vehicle_insurance_expires_at")
    op.drop_column("driver_profiles", "vehicle_insurance_file")
    op.drop_column("driver_profiles", "vehicle_registration_status")
    op.drop_column("driver_profiles", "vehicle_registration_expires_at")
    op.drop_column("driver_profiles", "vehicle_registration_file")
    op.drop_column("driver_profiles", "driver_license_status")
    op.drop_column("driver_profiles", "driver_license_expires_at")
    op.drop_column("driver_profiles", "driver_license_file")
