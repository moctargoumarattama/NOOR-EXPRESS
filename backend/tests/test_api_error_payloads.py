from pathlib import Path
import sys
import unittest


BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from fastapi import HTTPException

from app.core.api_errors import ApiError, error_payload, normalize_http_exception


class ApiErrorPayloadsTest(unittest.TestCase):
    def test_domain_error_payload_uses_code_and_message(self) -> None:
        error = ApiError(
            status_code=409,
            code="ride_already_assigned",
            message="Ride already has a winning offer.",
        )

        self.assertEqual(
            error_payload(error.code, error.message),
            {
                "code": "ride_already_assigned",
                "message": "Ride already has a winning offer.",
            },
        )

    def test_http_exception_is_normalized_to_clean_payload(self) -> None:
        payload = normalize_http_exception(
            HTTPException(status_code=404, detail="Ride request not found"),
        )

        self.assertEqual(
            payload,
            {
                "code": "not_found",
                "message": "Ride request not found",
            },
        )


if __name__ == "__main__":
    unittest.main()
