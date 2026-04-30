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
            connection.execute(
                text(
                    """
                    CREATE TABLE ride_requests (
                        id INTEGER PRIMARY KEY,
                        estimated_price NUMERIC(10,2) NOT NULL,
                        final_price NUMERIC(10,2) NULL,
                        status VARCHAR(32) NOT NULL DEFAULT 'pending'
                    )
                    """
                )
            )

    def test_adds_missing_agreed_price_and_backfills_locked_price(self) -> None:
        self._create_legacy_ride_requests_table()

        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO ride_requests (id, estimated_price, final_price, status)
                    VALUES (1, 4200.00, 4500.00, 'accepted')
                    """
                )
            )

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        column_names = {column["name"] for column in inspector.get_columns("ride_requests")}
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
            connection.execute(
                text(
                    """
                    CREATE TABLE users (
                        id INTEGER PRIMARY KEY,
                        phone_number VARCHAR(20) NOT NULL,
                        role VARCHAR(20) NOT NULL
                    )
                    """
                )
            )

        with self.engine.begin() as connection:
            ensure_database_schema_sync(connection)

        inspector = inspect(self.engine)
        column_names = {column["name"] for column in inspector.get_columns("users")}
        self.assertIn("is_blocked", column_names)


if __name__ == "__main__":
    unittest.main()
