from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "VaultTracker API"
    database_url: str = "sqlite:///./vaulttracker.db"
    debug: bool = True

    class Config:
        env_file = ".env"


settings = Settings()
