# SimpleRAG Q&A System

A FastAPI-based RAG service using LangChain, local Ollama models (or optional cloud models), and Qdrant vector store.

## Architecture at a Glance
- **API**: FastAPI app with routes for health, document upload, and querying ([app/main.py](app/main.py)).
- **Document ingestion**: PDF/TXT/CSV loaders + recursive character splitter ([app/core/document_processor.py](app/core/document_processor.py)).
- **Embeddings**: Local Ollama via `OllamaEmbeddings` with model `nomic-embed-text` (or optional Google/OpenAI embeddings) ([app/core/embeddings.py](app/core/embeddings.py)).
- **Vector store**: Qdrant (local file storage, in-memory `:memory:`, or Qdrant Cloud) via `QdrantVectorStore` ([app/core/vector_store.py](app/core/vector_store.py)).
- **Retriever**: Similarity retriever with `k=4` ([app/core/vector_store.py](app/core/vector_store.py)).
- **LLM**: Local Ollama via `ChatOllama` with model `qwen2.5-coder:7b` (or optional Google/OpenAI models) ([app/core/rag_chain.py](app/core/rag_chain.py)).
- **RAG chain**: LCEL pipeline → retriever → prompt → LLM → string output ([app/core/rag_chain.py](app/core/rag_chain.py)).
- **Evaluation (optional)**: RAGAS with `faithfulness` and `answer_relevancy` ([app/core/ragas_evaluator.py](app/core/ragas_evaluator.py)).
- **Logging**: Central logger setup ([app/utils/logger.py](app/utils/logger.py)).

## Environment Variables
Configure your `.env` file for local Ollama usage:

```env
# Model Provider ("ollama", "google", "openai")
MODEL_PROVIDER=ollama

# Local Ollama Configuration
OLLAMA_BASE_URL=http://localhost:11434
LLM_MODEL=qwen2.5-coder:7b
EMBEDDING_MODEL=nomic-embed-text
EMBEDDING_DIMENSIONS=768
LLM_TEMPERATURE=0.0

# Vector Database (Qdrant)
# Use ":memory:" for in-memory, "./qdrant_db" for local disk, or cloud endpoint
QDRANT_URL=http://localhost:6333
# QDRANT_API_KEY=your_key_if_using_cloud
COLLECTION_NAME=rag_documents

# Chunking
CHUNK_SIZE=1000
CHUNK_OVERLAP=200

# Retrieval
RETRIEVAL_K=4

# API
API_HOST=0.0.0.0
API_PORT=8000

# Logging
LOG_LEVEL=INFO
```

## Installation
```bash
python -m venv .venv
source .venv/Scripts/activate  # on Windows PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## Run the API
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Visit `http://localhost:8000/docs` for Swagger UI.

## Pipeline Details (replicable)
1. **Loaders**: `PyPDFLoader`, `TextLoader`, `CSVLoader` read PDFs/TXTs/CSVs. Source metadata is preserved.
2. **Chunking**: `RecursiveCharacterTextSplitter` with `chunk_size=1000`, `chunk_overlap=200`, separators `['\n\n', '\n', '. ', ' ', '']`.
3. **Embeddings**: `GoogleGenerativeAIEmbeddings` model `text-embedding-005`; vectors sent to Qdrant.
4. **Vector store**: `QdrantVectorStore` with cosine distance; collection auto-created with dimension 1536.
5. **Retriever**: `.as_retriever(search_type="similarity", k=4)` used in the chain.
6. **Prompt**: See `RAG_PROMPT_TEMPLATE` in [app/core/rag_chain.py](app/core/rag_chain.py) — direct context-grounded QA, no hallucinations.
7. **LLM**: `ChatOpenAI` with `LLM_MODEL` and `LLM_TEMPERATURE`; `OPENAI_API_KEY` required.
8. **Evaluation (optional)**: `RAGASEvaluator` uses Gemini chat + embeddings for RAGAS `faithfulness` and `answer_relevancy`.

## API Routes (FastAPI)
- **Documents** ([app/api/routes/documents.py](app/api/routes/documents.py))
  - `POST /documents/upload`: upload PDF/TXT/CSV → chunks via `DocumentProcessor` → stored in Qdrant via `VectorStoreService.add_documents`.
  - `GET /documents/info`: collection stats from Qdrant.
  - `DELETE /documents/collection`: drop the entire collection (use with caution).
- **Query** ([app/api/routes/query.py](app/api/routes/query.py))
  - `POST /query`: RAG answer using `RAGChain` with options `include_sources` and `enable_evaluation`.
  - `POST /query/stream`: streaming RAG answer via `RAGChain.stream`.
  - `POST /query/search`: vector search only (no generation) with scores.
- **Health** ([app/api/routes/health.py](app/api/routes/health.py))
  - `GET /health`: basic liveness.
  - `GET /health/ready`: readiness + Qdrant connectivity and collection info.

## Typical Flows
- **Ingest documents**: Use the documents API (see `app/api/routes/documents.py`) or call `DocumentProcessor.process_file()` to load and split, then `VectorStoreService.add_documents()` to index.
- **Query**: `RAGChain.query(question)` for plain text; `query_with_sources` to include source chunks.
- **Stream**: `RAGChain.stream(question)` yields chunks for incremental responses.
- **Evaluate**: `RAGChain.aquery_with_evaluation(question)` returns answer + RAGAS scores (requires Google API key).

## Key LangChain Components Used
- Loaders: `PyPDFLoader`, `TextLoader`, `CSVLoader`
- Splitter: `RecursiveCharacterTextSplitter`
- Embeddings: `GoogleGenerativeAIEmbeddings` (`text-embedding-005`)
- Vector store: `QdrantVectorStore` (cosine, dim 1536)
- LLM: `ChatOpenAI` (model from `LLM_MODEL`)
- Chain assembly: LCEL dictionary routing → prompt → LLM → `StrOutputParser`

## Replicating in Another Project
1. Copy the core modules:
   - [app/core/document_processor.py](app/core/document_processor.py)
   - [app/core/embeddings.py](app/core/embeddings.py)
   - [app/core/vector_store.py](app/core/vector_store.py)
   - [app/core/rag_chain.py](app/core/rag_chain.py)
   - [app/core/ragas_evaluator.py](app/core/ragas_evaluator.py) (optional)
   - [app/utils/logger.py](app/utils/logger.py)
2. Bring over the `.env` keys above and ensure `requirements.txt` includes LangChain, Qdrant, Google GenAI, FastAPI, Uvicorn, RAGAS (if used).
3. Wire a FastAPI (or CLI) entry point that initializes logging, creates `VectorStoreService`, and exposes endpoints to add docs and query.
4. Keep the same chunking and retrieval parameters to match behavior: chunk size 1000, overlap 200, retriever k=4, cosine distance.

## Operational Notes
- Qdrant collection is auto-created if missing; adjust dimension if you change embedding model.
- LangSmith tracing is enabled via env; disable by omitting `LANGSMITH_TRACING`.
- For strict Gemini-only stacks, swap `ChatOpenAI` with `ChatGoogleGenerativeAI` and remove the OpenAI key requirement.
- Logging defaults to INFO; use `LOG_LEVEL=DEBUG` for troubleshooting.

## Quick Smoke Test
After starting the API and setting env vars, hit the health endpoint:
```bash
curl http://localhost:8000/health
```
Upload a PDF via the documents endpoint (see docs), then query:
```bash
curl -X POST "http://localhost:8000/query" \
  -H "Content-Type: application/json" \
  -d '{"question": "What is this document about?"}'
```
You should receive an answer plus source excerpts (if using `query_with_sources`).
