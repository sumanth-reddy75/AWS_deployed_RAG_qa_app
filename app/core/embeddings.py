"""Embedding generation module using local Ollama or cloud embeddings."""

from functools import lru_cache

from langchain_core.embeddings import Embeddings

from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)


@lru_cache
def get_embeddings() -> Embeddings:
    """Get cached embeddings instance based on application settings.

    Returns:
        Configured Embeddings instance (OllamaEmbeddings by default)
    """
    settings = get_settings()
    logger.info(f"Initializing embeddings model: {settings.embedding_model}")

    if settings.model_provider == "openai" and settings.openai_api_key:
        from langchain_openai import OpenAIEmbeddings

        embeddings = OpenAIEmbeddings(
            model=settings.embedding_model,
            api_key=settings.openai_api_key,
        )
    elif settings.model_provider == "google" and settings.google_api_key:
        from langchain_google_genai import GoogleGenerativeAIEmbeddings

        embeddings = GoogleGenerativeAIEmbeddings(
            model=settings.embedding_model,
            google_api_key=settings.google_api_key,
        )
    else:
        from langchain_ollama import OllamaEmbeddings

        embeddings = OllamaEmbeddings(
            model=settings.embedding_model,
            base_url=settings.ollama_base_url,
        )

    logger.info("Embeddings model initialized successfully")
    return embeddings


class EmbeddingService:
    """Service for generating embeddings."""

    def __init__(self):
        """Initialize embedding service."""
        settings = get_settings()
        self.embeddings = get_embeddings()
        self.model_name = settings.embedding_model

    def embed_query(self, text: str) -> list[float]:
        """Generate embedding for a single query.

        Args:
            text: Query text

        Returns:
            Embedding vector as list of floats
        """
        logger.debug(f"Generating embedding for query: {text[:50]}...")
        return self.embeddings.embed_query(text)

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        """Generate embeddings for multiple documents.

        Args:
            texts: List of document texts

        Returns:
            List of embedding vectors
        """
        logger.debug(f"Generating embeddings for {len(texts)} documents")
        return self.embeddings.embed_documents(texts)