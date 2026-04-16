"""
Application settings loaded from the `.env` file via pydantic-settings.

`debug_auth_enabled` bypasses Firebase JWT verification for local development and
integration testing. It must be False in any non-local environment.
"""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "VaultTracker API"
    database_url: str = "sqlite:///./vaulttracker.db"
    debug: bool = False
    # Set DEBUG_AUTH_ENABLED=true in .env to allow the iOS debug bypass token.
    # Must be False in staging/production.
    debug_auth_enabled: bool = False
    # Comma-separated browser origins for CORS (web app + /docs “Try it out”).
    # Native iOS URLSession does not send Origin.
    allowed_origins: str = (
        "http://localhost:3000,http://127.0.0.1:3000,"
        "http://localhost:8000,http://127.0.0.1:8000"
    )
    # Path to Firebase service account JSON. Empty = real JWT verification disabled
    # unless you use debug bypass only.
    firebase_credentials_path: str = ""
    # Used by PriceService for stock quotes (GLOBAL_QUOTE).
    alpha_vantage_api_key: str = ""
    # SlowAPI tier strings (e.g. "60/minute"); callable limits read at request time.
    rate_limit_read: str = "60/minute"
    rate_limit_write: str = "30/minute"
    rate_limit_external: str = "10/minute"

    class Config:
        env_file = ".env"


settings = Settings()
