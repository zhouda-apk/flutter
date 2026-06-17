from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables or .env."""

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        extra="ignore",
    )

    # Provider selection: google/gemini | openai
    llm_provider: str = "google"

    # Google Gemini settings
    google_api_key: str | None = None
    google_model: str = "gemini-2.5-flash"
    google_max_tokens: int = 4096

    # Optional OpenAI fallback
    openai_api_key: str | None = None
    openai_model: str = "gpt-4o"
    openai_max_tokens: int = 4096

    # FastAPI settings
    host: str = "0.0.0.0"
    port: int = 5000
    debug: bool = True

    @property
    def provider(self) -> str:
        provider = self.llm_provider.lower().strip()
        return "google" if provider == "gemini" else provider

    @property
    def active_model(self) -> str:
        if self.provider == "openai":
            return self.openai_model
        return self.google_model

    @property
    def active_max_tokens(self) -> int:
        if self.provider == "openai":
            return self.openai_max_tokens
        return self.google_max_tokens


settings = Settings()
