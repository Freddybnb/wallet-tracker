"""
Configuration management — charge .env et expose les paramètres.
"""
from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import Field, field_validator
from typing import Optional


class Settings(BaseSettings):
    """Configuration centralisée via variables d'environnement."""

    # Helius
    helius_api_key: str = Field(..., alias="HELIUS_API_KEY", description="Clé API Helius")

    # Webhook secret (pour validation Header X-Webhook-Secret)
    webhook_secret: str = Field(..., alias="WEBHOOK_SECRET", description="Secret entre Helius et ton serveur")

    # Server
    host: str = Field("0.0.0.0", alias="HOST")
    port: int = Field(8000, alias="PORT")
    debug: bool = Field(False, alias="DEBUG")

    # Database
    database_url: str = Field(
        "sqlite+aiosqlite:///./data/wallet_tracker.db",
        alias="DATABASE_URL"
    )

    # Logging
    log_level: str = Field("INFO", alias="LOG_LEVEL")

    # Default threshold (SOL)
    default_min_amount: float = Field(0.1, alias="DEFAULT_MIN_AMOUNT")

    # Termux (optionnel)
    termux_session_name: Optional[str] = Field(None, alias="TERMUX_SESSION_NAME")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @field_validator("port")
    @classmethod
    def port_must_be_valid(cls, v: int) -> int:
        if not (1024 <= v <= 65535):
            raise ValueError("Port must be 1024-65535")
        return v

    @field_validator("webhook_secret")
    @classmethod
    def secret_must_be_hex32(cls, v: str) -> str:
        if len(v) != 32:
            raise ValueError("WEBHOOK_SECRET must be 32 hex chars (16 bytes)")
        # Verifiable hex
        int(v, 16)
        return v.lower()


# Singleton global
settings = Settings()
