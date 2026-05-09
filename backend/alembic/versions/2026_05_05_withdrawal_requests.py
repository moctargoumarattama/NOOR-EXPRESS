"""add withdrawal requests table

Revision ID: 2026_05_05_withdrawal_requests
Revises: 2026_05_04_driver_documents_mediumtext_fix
Create Date: 2026-05-05
"""

from alembic import op
import sqlalchemy as sa


revision = "2026_05_05_withdrawal_requests"
down_revision = "2026_05_04_driver_documents_mediumtext_fix"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "withdrawal_requests",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("driver_id", sa.Integer(), nullable=False),
        sa.Column("amount_due", sa.Numeric(12, 2), nullable=False),
        sa.Column("commission_rate_snapshot", sa.Numeric(5, 2), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("driver_note", sa.String(length=200), nullable=True),
        sa.Column("admin_note", sa.String(length=200), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("confirmed_at", sa.DateTime(), nullable=True),
        sa.Column("confirmed_by", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["driver_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["confirmed_by"], ["admins.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_withdrawal_requests_driver_id",
        "withdrawal_requests",
        ["driver_id"],
        unique=False,
    )
    op.create_index(
        "ix_withdrawal_requests_status",
        "withdrawal_requests",
        ["status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_withdrawal_requests_status", table_name="withdrawal_requests")
    op.drop_index("ix_withdrawal_requests_driver_id", table_name="withdrawal_requests")
    op.drop_table("withdrawal_requests")
