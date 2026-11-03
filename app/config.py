"""Application configuration using pydantic-settings."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Model Provider ("ollama", "google", "openai")
    model_provider: str = "openai"

    # Ollama Configuration
    ollama_base_url: str = "http://localhost:11434"

    # Cloud API Keys (Optional - only needed if using cloud models)
    google_api_key: str | None = None
    openai_api_key: str | None = None

    # Qdrant Configuration
    qdrant_url: str = "http://localhost:6333"
    qdrant_api_key: str | None = None

    # Collection Settings
    collection_name: str = "rag_documents"

    # Document Processing Settings
    chunk_size: int = 1000
    chunk_overlap: int = 200

    # Model Configuration
    embedding_model: str = "text-embedding-3-small"
    embedding_dimensions: int = 1536
    llm_model: str = "gpt-4o-mini"
    llm_temperature: float = 0.0

    # Retrieval Settings
    retrieval_k: int = 4

    # Logging
    log_level: str = "INFO"

    # RAGAS Evaluation Settings
    enable_ragas_evaluation: bool = False
    ragas_timeout_seconds: float = 30.0
    ragas_log_results: bool = True
    ragas_llm_model: str | None = None  # Defaults to llm_model if not set
    ragas_llm_temperature: float | None = None  # Defaults to llm_temperature if not set
    ragas_embedding_model: str | None = None  # Defaults to embedding_model if not set

    # API Settings
    api_host: str = "0.0.0.0"
    api_port: int = 8000

    # Application Info
    app_name: str = "RAG Q&A System"
    app_version: str = "0.1.0"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()