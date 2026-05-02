"""add ride share tracking token fields

Revision ID: 2026_05_01_ride_share_links
Revises: 2026_05_01_reports_suspensions
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_01_ride_share_links"
down_revision = "2026_05_01_reports_suspensions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("ride_requests", sa.Column("share_token", sa.String(length=36), nullable=True))
    op.add_column("ride_requests", sa.Column("share_token_created_at", sa.DateTime(), nullable=True))
    op.create_index(
        "ix_ride_requests_share_token",
        "ride_requests",
        ["share_token"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_ride_requests_share_token", table_name="ride_requests")
    op.drop_column("ride_requests", "share_token_created_at")
    op.drop_column("ride_requests", "share_token")
