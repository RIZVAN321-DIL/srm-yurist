from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator

class Settings(BaseSettings):
    BOT_TOKEN: str = ""
    DATABASE_URL: str = "sqlite+aiosqlite:////app/data/crm_yurist.db"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 10000
    BASE_URL: str = ""
    ADMIN_IDS: list[int] = []
    SECRET_KEY: str = "change-me"
    BOT_USERNAME: str = ""
    UPLOAD_DIR: str = "app/static/uploads"
    JWT_SECRET: str = "jwt-secret"
    JWT_EXPIRE_HOURS: int = 24
    MAX_FILE_SIZE_MB: int = 20
    ENCRYPTION_KEY: str = "kWjF7Q2mX9pL4vR8yN1cB5sH3tE6uA0dG7oI9wS2fK="
    CSRF_SECRET: str = "csrf-secret"
    LOGIN_MAX_ATTEMPTS: int = 5
    LOGIN_TIMEOUT_MINUTES: int = 15
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    @field_validator("ADMIN_IDS", mode="before")
    @classmethod
    def parse_admins(cls, value):
        if isinstance(value, str): return [int(x.strip()) for x in value.split(",") if x.strip()]
        if isinstance(value, list): return value
        if isinstance(value, int): return [value]
        return []

settings = Settings()
