"""add report workflow and user suspensions

Revision ID: 2026_05_01_reports_suspensions
Revises: 2026_05_01_saved_addresses
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa

revision = "2026_05_01_reports_suspensions"
down_revision = "2026_05_01_saved_addresses"
branch_labels = None
depends_on = None


REPORT_STATUSES = ("nouveau", "en_cours", "resolu", "classe_sans_suite")


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "is_suspended", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )
    op.add_column("users", sa.Column("suspended_until", sa.DateTime(), nullable=True))
    op.add_column("users", sa.Column("suspension_reason", sa.Text(), nullable=True))

    op.create_table(
        "user_suspensions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column(
            "suspended_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("suspended_until", sa.DateTime(), nullable=True),
        sa.Column("lifted_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_user_suspensions_user_id", "user_suspensions", ["user_id"])

    op.add_column("ride_reports", sa.Column("note_admin", sa.Text(), nullable=True))
    bind = op.get_bind()
    if bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE ride_reports MODIFY COLUMN status "
            "ENUM('ouvert','traite','nouveau','en_cours','resolu','classe_sans_suite') "
            "NOT NULL DEFAULT 'nouveau'"
        )
    op.execute("UPDATE ride_reports SET status='nouveau' WHERE status='ouvert'")
    op.execute("UPDATE ride_reports SET status='resolu' WHERE status='traite'")
    if bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE ride_reports MODIFY COLUMN status "
            "ENUM('nouveau','en_cours','resolu','classe_sans_suite') "
            "NOT NULL DEFAULT 'nouveau'"
        )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "mysql":
        op.execute(
            "ALTER TABLE ride_reports MODIFY COLUMN status "
            "ENUM('ouvert','traite') NOT NULL DEFAULT 'ouvert'"
        )
    op.execute("UPDATE ride_reports SET status='ouvert' WHERE status='nouveau'")
    op.execute("UPDATE ride_reports SET status='traite' WHERE status='resolu'")
    op.drop_column("ride_reports", "note_admin")

    op.drop_index("ix_user_suspensions_user_id", table_name="user_suspensions")
    op.drop_table("user_suspensions")

    op.drop_column("users", "suspension_reason")
    op.drop_column("users", "suspended_until")
    op.drop_column("users", "is_suspended")
