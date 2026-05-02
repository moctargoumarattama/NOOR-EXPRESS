from pathlib import Path
import sys
import tempfile
import unittest

from sqlalchemy import create_engine, inspect, text

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.schema_bootstrap import ensure_database_schema_sync


class SchemaBootstrapTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tempdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tempdir.name) / "schema_bootstrap.sqlite3"
        self.engine = create_engine(f"sqlite:///{self.db_path}")

    def tearDown(self) -> None:
        self.engine.dispose()
        self._tempdir.cleanup()

    def _create_legacy_ride_requests_table(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE ride_requests (
                        id INTEGER PRIMARY KEY,
                        estimated_price NUMERIC(10,2) NOT NULL,
                        final_price NUMERIC(10,2) NULL,
                        status VARCHAR(32) NOT NULL DEFAULT 'pending'
                    )
                    """))

    def test_adds_missing_agreed_price_and_backfills_locked_price(self) -> None:
        self._create_legacy_ride_requests_table()

        with self.engine.begin() as connection:
            connection.execute(text("""
                    INSERT INTO ride_requests (id, estimated_price, final_price, status)
                    VALUES (1, 4200.00, 4500.00, 'accepted')
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        column_names = {
            column["name"] for column in inspector.get_columns("ride_requests")
        }
        self.assertIn("agreed_price", column_names)

        with self.engine.begin() as connection:
            agreed_price = connection.execute(
                text("SELECT agreed_price FROM ride_requests WHERE id = 1")
            ).scalar_one()

        self.assertEqual(float(agreed_price), 4500.0)

    def test_schema_bootstrap_is_idempotent(self) -> None:
        self._create_legacy_ride_requests_table()

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        agreed_price_columns = [
            column["name"]
            for column in inspector.get_columns("ride_requests")
            if column["name"] == "agreed_price"
        ]
        self.assertEqual(agreed_price_columns, ["agreed_price"])

    def test_adds_missing_user_block_flag(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        column_names = {column["name"] for column in inspector.get_columns("users")}
        self.assertIn("is_blocked", column_names)

    def test_adds_suspension_columns_and_history_table(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        self.assertIn("is_suspended", user_columns)
        self.assertIn("suspended_until", user_columns)
        self.assertIn("suspension_reason", user_columns)
        self.assertIn("user_suspensions", inspector.get_table_names())

    def test_adds_account_deletion_columns_to_users(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        self.assertIn("deleted_at", user_columns)
        self.assertIn("deletion_reason", user_columns)

    def test_adds_cancellation_policy_columns_to_users(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        self.assertIn("cancellations_today", user_columns)
        self.assertIn("cancellations_last_24h", user_columns)
        self.assertIn("cancellation_window_started_at", user_columns)
        self.assertIn("ride_request_blocked_until", user_columns)

    def test_migrates_legacy_report_status_to_new_workflow(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))
            connection.execute(text("""
                    CREATE TABLE ride_requests (
                        id INTEGER PRIMARY KEY,
                        estimated_price NUMERIC(10,2) NOT NULL,
                        status VARCHAR(32) NOT NULL DEFAULT 'pending'
                    )
                    """))
            connection.execute(text("""
                    CREATE TABLE ride_reports (
                        id INTEGER PRIMARY KEY,
                        ride_request_id INTEGER NOT NULL,
                        reported_by_id INTEGER NOT NULL,
                        reason VARCHAR(32) NOT NULL,
                        description TEXT NULL,
                        status VARCHAR(32) NOT NULL DEFAULT 'ouvert',
                        created_at DATETIME NULL
                    )
                    """))
            connection.execute(text("""
                    INSERT INTO ride_reports (id, ride_request_id, reported_by_id, reason, status)
                    VALUES (1, 1, 1, 'autre', 'ouvert')
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        report_columns = {
            column["name"] for column in inspector.get_columns("ride_reports")
        }
        self.assertIn("note_admin", report_columns)

        with self.engine.begin() as connection:
            status_value = connection.execute(
                text("SELECT status FROM ride_reports WHERE id = 1")
            ).scalar_one()

        self.assertEqual(status_value, "nouveau")

    def test_adds_ride_share_tracking_columns_and_index(self) -> None:
        self._create_legacy_ride_requests_table()

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        ride_columns = {
            column["name"] for column in inspector.get_columns("ride_requests")
        }
        self.assertIn("share_token", ride_columns)
        self.assertIn("share_token_created_at", ride_columns)

        index_names = {
            index["name"] for index in inspector.get_indexes("ride_requests")
        }
        self.assertIn("ix_ride_requests_share_token", index_names)

    def test_ride_messages_created_at_is_backfilled_when_null(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))
            connection.execute(text("""
                    CREATE TABLE ride_requests (
                        id INTEGER PRIMARY KEY,
                        estimated_price NUMERIC(10,2) NOT NULL,
                        status VARCHAR(32) NOT NULL DEFAULT 'pending'
                    )
                    """))
            connection.execute(text("""
                    CREATE TABLE ride_messages (
                        id INTEGER PRIMARY KEY,
                        ride_id INTEGER NOT NULL,
                        sender_id INTEGER NOT NULL,
                        sender_role VARCHAR(20) NOT NULL,
                        content VARCHAR(500) NOT NULL,
                        is_read BOOLEAN NOT NULL DEFAULT 0,
                        created_at DATETIME NULL
                    )
                    """))
            connection.execute(text("""
                    INSERT INTO users (id, phone_number, role)
                    VALUES (1, '+22790000001', 'client')
                    """))
            connection.execute(text("""
                    INSERT INTO ride_requests (id, estimated_price, status)
                    VALUES (1, 2000.00, 'accepted')
                    """))
            connection.execute(text("""
                    INSERT INTO ride_messages (
                        id, ride_id, sender_id, sender_role, content, is_read, created_at
                    ) VALUES (1, 1, 1, 'client', 'Bonjour', 0, NULL)
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        with self.engine.begin() as connection:
            created_at = connection.execute(
                text("SELECT created_at FROM ride_messages WHERE id = 1")
            ).scalar_one()

        self.assertIsNotNone(created_at)

    def test_ride_messages_created_at_default_is_applied_on_insert(self) -> None:
        with self.engine.begin() as connection:
            connection.execute(text("""
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """))
            connection.execute(text("""
                    CREATE TABLE ride_requests (
                        id INTEGER PRIMARY KEY,
                        estimated_price NUMERIC(10,2) NOT NULL,
                        status VARCHAR(32) NOT NULL DEFAULT 'pending'
                    )
                    """))
            connection.execute(text("""
                    INSERT INTO users (id, phone_number, role)
                    VALUES (1, '+22790000001', 'client')
                    """))
            connection.execute(text("""
                    INSERT INTO ride_requests (id, estimated_price, status)
                    VALUES (1, 2000.00, 'accepted')
                    """))

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        with self.engine.begin() as connection:
            connection.execute(text("""
                    INSERT INTO ride_messages (
                        id, ride_id, sender_id, sender_role, content, is_read
                    ) VALUES (1, 1, 1, 'client', 'Test', 0)
                    """))
            created_at = connection.execute(
                text("SELECT created_at FROM ride_messages WHERE id = 1")
            ).scalar_one()

        self.assertIsNotNone(created_at)

    def test_adds_broadcast_history_table(self) -> None:
        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        self.assertIn("broadcast_history", inspector.get_table_names())
        column_names = {
            column["name"] for column in inspector.get_columns("broadcast_history")
        }
        self.assertIn("target", column_names)
        self.assertIn("title", column_names)
        self.assertIn("message", column_names)
        self.assertIn("notification_type", column_names)
        self.assertIn("sent_at", column_names)
        self.assertIn("estimated_recipients", column_names)

        index_names = {
            index["name"] for index in inspector.get_indexes("broadcast_history")
        }
        self.assertIn("ix_broadcast_history_sent_at", index_names)


if __name__ == "__main__":
    unittest.main()
