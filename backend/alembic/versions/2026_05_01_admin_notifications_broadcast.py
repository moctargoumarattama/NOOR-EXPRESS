"""add admin notifications broadcast history

Revision ID: 2026_05_01_admin_notifications_broadcast
Revises: 2026_05_01_ride_share_links
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_01_admin_notifications_broadcast"
down_revision = "2026_05_01_ride_share_links"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "broadcast_history",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("target", sa.String(length=32), nullable=False),
        sa.Column("title", sa.String(length=60), nullable=False),
        sa.Column("message", sa.String(length=200), nullable=False),
        sa.Column("notification_type", sa.String(length=20), nullable=False),
        sa.Column(
            "sent_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "estimated_recipients",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.create_index(
        "ix_broadcast_history_sent_at",
        "broadcast_history",
        ["sent_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_broadcast_history_sent_at", table_name="broadcast_history")
    op.drop_table("broadcast_history")
