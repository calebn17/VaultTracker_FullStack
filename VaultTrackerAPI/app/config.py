from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "VaultTracker API"
    database_url: str = "sqlite:///./vaulttracker.db"
    debug: bool = True
    # Set DEBUG_AUTH_ENABLED=true in .env to allow the iOS debug bypass token.
    # Must be False in staging/production.
    debug_auth_enabled: bool = False

    class Config:
        env_file = ".env"


settings = Settings()
