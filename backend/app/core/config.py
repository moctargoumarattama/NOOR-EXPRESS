from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    ENV: str = "development"
    DATABASE_URL: str
    SECRET_KEY: str
    ADMIN_SECRET_KEY: str
    ENABLE_DEV_SIMULATIONS: bool = False
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    OTP_CODE_DEV: str = "1234"
    REDIS_URL: str = "redis://localhost:6379/0"
    REALTIME_STORE_BACKEND: str = "memory"
    UPSTASH_REDIS_REST_URL: str | None = None
    UPSTASH_REDIS_REST_TOKEN: str | None = None
    FIREBASE_CREDENTIALS_PATH: str = "firebase_credentials.json"

    class Config:
        env_file = Path(__file__).resolve().parents[2] / ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()
