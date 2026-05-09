"""add passenger ready timestamp on rides

Revision ID: 2026_05_05_passenger_ready_at
Revises: 2026_05_05_withdrawal_requests
Create Date: 2026-05-05
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_05_passenger_ready_at"
down_revision = "2026_05_05_withdrawal_requests"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ride_requests",
        sa.Column("passenger_ready_at", sa.DateTime(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("ride_requests", "passenger_ready_at")
