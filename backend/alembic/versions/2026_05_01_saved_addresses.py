"""add saved addresses for users

Revision ID: 2026_05_01_saved_addresses
Revises: 2026_05_01_ride_chat, 2026_05_01_ride_history_wallet
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa

revision = "2026_05_01_saved_addresses"
down_revision = ("2026_05_01_ride_chat", "2026_05_01_ride_history_wallet")
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "saved_addresses",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("label", sa.String(length=120), nullable=False),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lon", sa.Float(), nullable=False),
        sa.Column("address_display", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_saved_addresses_user_id", "saved_addresses", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_saved_addresses_user_id", table_name="saved_addresses")
    op.drop_table("saved_addresses")
