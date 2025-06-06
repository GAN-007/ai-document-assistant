from pydantic_settings import BaseSettings

class Config(BaseSettings):
    # Application metadata
    app_name: str = "AI Document Assistant"
    api_version: str = "1.0.0"
    jwt_secret: str = "your-secret-key-here"

    # File processing settings
    max_file_size: int = 10 * 1024 * 1024  # 10MB
    supported_file_types: list = [
        {"mime_type": "application/pdf", "name": "PDF", "icon": "📄"},
        {"mime_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "name": "DOCX", "icon": "📝"},
        {"mime_type": "text/plain", "name": "TXT", "icon": "📝"},
        {"mime_type": "text/csv", "name": "CSV", "icon": "📊"},
        {"mime_type": "application/vnd.ms-excel", "name": "XLS", "icon": "📊"},
        {"mime_type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "name": "XLSX", "icon": "📊"},
        {"mime_type": "application/sql", "name": "SQL", "icon": "🗄️"},
        {"mime_type": "application/zip", "name": "ZIP", "icon": "📦"},
        {"mime_type": "application/x-rar", "name": "RAR", "icon": "📦"},
    ]

    # AI model settings
    ai: dict = {
        "model_type": "multi-model",
        "ollama_model_primary": "llama3.1:latest",
        "ollama_model_secondary": "llama2:latest",
        "t5_model_name": "t5-small"
    }

    # Model metadata
    model_info: dict = {
        "name": "Multi-Model Document Enhancer",
        "version": "1.0.0",
        "description": "Supports Llama3.1, Llama2 (Ollama), and T5 (Hugging Face) for text improvement."
    }

    # Ollama and database settings
    OLLAMA_API_URL: str = "http://localhost:11434"
    DATABASE_URL: str = "sqlite:///documents.db"

config = Config()
SUPPORTED_FILE_TYPES = config.supported_file_types
MODEL_INFO = config.model_info
