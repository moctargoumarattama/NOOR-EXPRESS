"""add ride history fields and driver wallets

Revision ID: 2026_05_01_ride_history_wallet
Revises: 2026_05_01_vehicle_photo
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_01_ride_history_wallet"
down_revision = "2026_05_01_vehicle_photo"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("ride_requests", sa.Column("distance_km", sa.Float(), nullable=True))
    op.add_column(
        "ride_requests",
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
    )
    op.add_column(
        "ride_requests",
        sa.Column("completed_at", sa.DateTime(), nullable=True),
    )
    op.create_table(
        "driver_wallets",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "total_completed_rides",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "total_gross_earnings",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0.00",
        ),
        sa.Column(
            "total_commission",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0.00",
        ),
        sa.Column(
            "total_net_earnings",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0.00",
        ),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("driver_id", name="uq_driver_wallets_driver_id"),
    )


def downgrade() -> None:
    op.drop_table("driver_wallets")
    op.drop_column("ride_requests", "completed_at")
    op.drop_column("ride_requests", "duration_minutes")
    op.drop_column("ride_requests", "distance_km")
