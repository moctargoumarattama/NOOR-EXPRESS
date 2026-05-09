"""add fcm delivery status fields to broadcast history

Revision ID: 2026_05_05_broadcast_history_fcm_status
Revises: 2026_05_05_driver_last_known_position
Create Date: 2026-05-05
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_05_broadcast_history_fcm_status"
down_revision = "2026_05_05_driver_last_known_position"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    table_names = set(inspector.get_table_names())

    if "broadcast_history" not in table_names:
        op.create_table(
            "broadcast_history",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("target", sa.String(length=32), nullable=False),
            sa.Column("title", sa.String(length=60), nullable=False),
            sa.Column("message", sa.String(length=200), nullable=False),
            sa.Column("notification_type", sa.String(length=20), nullable=False),
            sa.Column(
                "sent_at",
                sa.DateTime(),
                nullable=False,
                server_default=sa.text("CURRENT_TIMESTAMP"),
            ),
            sa.Column(
                "estimated_recipients",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
            sa.Column(
                "fcm_sent_count",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
            sa.Column(
                "fcm_failed_count",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
            sa.Column(
                "fcm_status",
                sa.String(length=32),
                nullable=False,
                server_default="failed",
            ),
            sa.Column("fcm_error_reason", sa.Text(), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(
            "ix_broadcast_history_sent_at",
            "broadcast_history",
            ["sent_at"],
            unique=False,
        )
        return

    history_columns = {
        column["name"] for column in inspector.get_columns("broadcast_history")
    }
    if "fcm_sent_count" not in history_columns:
        op.add_column(
            "broadcast_history",
            sa.Column(
                "fcm_sent_count",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )
    if "fcm_failed_count" not in history_columns:
        op.add_column(
            "broadcast_history",
            sa.Column(
                "fcm_failed_count",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )
    if "fcm_status" not in history_columns:
        op.add_column(
            "broadcast_history",
            sa.Column(
                "fcm_status",
                sa.String(length=32),
                nullable=False,
                server_default="sent",
            ),
        )
    if "fcm_error_reason" not in history_columns:
        op.add_column(
            "broadcast_history",
            sa.Column("fcm_error_reason", sa.Text(), nullable=True),
        )

    op.execute(
        "UPDATE broadcast_history "
        "SET fcm_sent_count = estimated_recipients "
        "WHERE fcm_sent_count = 0 "
        "AND estimated_recipients > 0 "
        "AND fcm_status = 'sent'"
    )
    op.execute(
        "UPDATE broadcast_history "
        "SET fcm_status = 'failed' "
        "WHERE fcm_status IS NULL OR fcm_status = ''"
    )


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    table_names = set(inspector.get_table_names())
    if "broadcast_history" not in table_names:
        return

    history_columns = {
        column["name"] for column in inspector.get_columns("broadcast_history")
    }
    if "fcm_error_reason" in history_columns:
        op.drop_column("broadcast_history", "fcm_error_reason")
    if "fcm_status" in history_columns:
        op.drop_column("broadcast_history", "fcm_status")
    if "fcm_failed_count" in history_columns:
        op.drop_column("broadcast_history", "fcm_failed_count")
    if "fcm_sent_count" in history_columns:
        op.drop_column("broadcast_history", "fcm_sent_count")
