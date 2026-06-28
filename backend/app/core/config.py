"""Application configuration loaded from environment variables.

Every external integration is optional: if its credentials are absent the
corresponding feature degrades gracefully (manual add + CSV import always work).
"""
from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # --- Core ---
    app_name: str = "Yagl"
    environment: str = "development"
    # Postgres in Docker; tests override with SQLite.
    database_url: str = "postgresql+psycopg2://yagl:yagl@db:5432/yagl"
    # CHANGE in production. Used to sign JWTs and encrypt stored store credentials.
    secret_key: str = "dev-insecure-change-me"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days
    cors_origins: str = "*"

    # --- Photo storage ---
    # "local" writes under media_root; an S3-compatible backend can be added later.
    storage_backend: str = "local"
    media_root: str = "/data/media"
    media_url_base: str = "/media"

    # --- IGDB (Twitch) ---
    igdb_client_id: str | None = None
    igdb_client_secret: str | None = None

    # --- Barcode resolution ---
    gameupc_api_key: str | None = None
    upcitemdb_api_key: str | None = None  # optional; trial endpoint works without one

    # --- Digital library import ---
    steam_api_key: str | None = None

    @field_validator("database_url")
    @classmethod
    def _normalize_db_url(cls, v: str) -> str:
        # Managed hosts (Render, Heroku, Railway) hand out `postgres://` or
        # `postgresql://` URLs; SQLAlchemy needs the psycopg2 driver spelled out.
        if v.startswith("postgres://"):
            return "postgresql+psycopg2://" + v[len("postgres://"):]
        if v.startswith("postgresql://"):
            return "postgresql+psycopg2://" + v[len("postgresql://"):]
        return v

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def igdb_enabled(self) -> bool:
        return bool(self.igdb_client_id and self.igdb_client_secret)

    @property
    def steam_enabled(self) -> bool:
        return bool(self.steam_api_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
