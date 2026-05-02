"""add ride chat messages

Revision ID: 2026_05_01_ride_chat
Revises: 2026_05_01_vehicle_photo
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_01_ride_chat"
down_revision = "2026_05_01_vehicle_photo"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ride_messages",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("ride_id", sa.Integer(), sa.ForeignKey("ride_requests.id"), nullable=False),
        sa.Column("sender_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "sender_role",
            sa.Enum("driver", "client", name="userrole"),
            nullable=False,
        ),
        sa.Column("content", sa.String(length=500), nullable=False),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_ride_messages_ride_id", "ride_messages", ["ride_id"])
    op.create_index("ix_ride_messages_sender_id", "ride_messages", ["sender_id"])
    op.create_index("ix_ride_messages_created_at", "ride_messages", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_ride_messages_created_at", table_name="ride_messages")
    op.drop_index("ix_ride_messages_sender_id", table_name="ride_messages")
    op.drop_index("ix_ride_messages_ride_id", table_name="ride_messages")
    op.drop_table("ride_messages")
