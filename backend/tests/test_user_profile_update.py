from datetime import datetime
from io import BytesIO
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import UploadFile
from PIL import Image

BACKEND_DIR = Path(__file__).resolve().parents[1]

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.api_errors import ApiError
from app.services import user_service


class UserProfileUpdateServiceTest(unittest.IsolatedAsyncioTestCase):
    async def test_first_name_too_short_is_rejected(self) -> None:
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )
        user = _build_user()

        with self.assertRaises(ApiError) as context:
            await user_service.update_current_user_profile(
                session,
                user,
                first_name="A",
            )

        self.assertEqual(context.exception.status_code, 422)
        self.assertEqual(context.exception.code, "invalid_first_name")
        session.commit.assert_not_awaited()

    async def test_profile_photo_too_large_is_rejected(self) -> None:
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )
        user = _build_user()
        oversized_bytes = b"x" * (user_service.MAX_PROFILE_PHOTO_SIZE_BYTES + 1)
        upload_file = UploadFile(
            filename="heavy.jpg",
            file=BytesIO(oversized_bytes),
        )

        with self.assertRaises(ApiError) as context:
            await user_service.update_current_user_profile(
                session,
                user,
                profile_photo=upload_file,
            )

        self.assertEqual(context.exception.status_code, 422)
        self.assertEqual(context.exception.code, "profile_photo_too_large")
        session.commit.assert_not_awaited()

    async def test_phone_number_is_ignored_when_sent(self) -> None:
        session = SimpleNamespace(
            commit=AsyncMock(),
            refresh=AsyncMock(),
            rollback=AsyncMock(),
        )
        user = _build_user(phone_number="+22790000000")

        updated_user = await user_service.update_current_user_profile(
            session,
            user,
            phone_number="+22712345678",
        )

        self.assertEqual(updated_user.phone_number, "+22790000000")
        session.commit.assert_awaited_once()

    async def test_old_profile_photo_is_deleted_after_update(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            storage_dir = Path(temp_dir)
            old_file = storage_dir / "old_photo.jpg"
            old_file.write_bytes(b"legacy")
            user = _build_user(
                profile_photo=f"{user_service.PROFILE_PHOTO_PUBLIC_PREFIX}old_photo.jpg"
            )
            session = SimpleNamespace(
                commit=AsyncMock(),
                refresh=AsyncMock(),
                rollback=AsyncMock(),
            )
            upload_file = UploadFile(
                filename="new.png",
                file=BytesIO(_valid_png_bytes()),
            )

            with patch.object(
                user_service,
                "PROFILE_PHOTO_STORAGE_DIR",
                storage_dir,
            ):
                updated_user = await user_service.update_current_user_profile(
                    session,
                    user,
                    profile_photo=upload_file,
                )

            self.assertFalse(old_file.exists())
            self.assertIsNotNone(updated_user.profile_photo)
            self.assertTrue(
                updated_user.profile_photo.startswith(
                    user_service.PROFILE_PHOTO_PUBLIC_PREFIX
                )
            )
            new_filename = updated_user.profile_photo.replace(
                user_service.PROFILE_PHOTO_PUBLIC_PREFIX,
                "",
                1,
            )
            new_file = storage_dir / new_filename
            self.assertTrue(new_file.exists())
            with Image.open(new_file) as saved_image:
                self.assertEqual(saved_image.size, (400, 400))


def _build_user(
    *,
    phone_number: str = "+22790000001",
    profile_photo: str | None = None,
) -> SimpleNamespace:
    return SimpleNamespace(
        id=1,
        name="Ali",
        phone_number=phone_number,
        profile_photo=profile_photo,
        created_at=datetime.utcnow(),
    )


def _valid_png_bytes() -> bytes:
    image = Image.new("RGB", (640, 480), color=(32, 160, 92))
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


if __name__ == "__main__":
    unittest.main()
