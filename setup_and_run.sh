#!/bin/bash

# AI Document Assistant Setup and Run Script
# Automates installation of dependencies and simultaneous running of backend and frontend
# Usage: ./setup_and_run.sh [--backend-port <port>] [--frontend-port <port>] [--help]

# Configuration
BACKEND_DIR="backend"
FRONTEND_DIR="frontend"
DEFAULT_BACKEND_PORT=8000
DEFAULT_FRONTEND_PORT=3000
OLLAMA_MODELS=("llama3.1:latest" "llama2:latest")
LOG_FILE="setup_and_run.log"
BACKEND_LOG="backend.log"
FRONTEND_LOG="frontend.log"
LOG_MAX_SIZE=$((10*1024*1024)) # 10MB
OLLAMA_PORT=11434

# Initialize ports from arguments
BACKEND_PORT=$DEFAULT_BACKEND_PORT
FRONTEND_PORT=$DEFAULT_FRONTEND_PORT

# Detect Windows environment (Git Bash)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || -n "$WINDIR" ]]; then
    IS_WINDOWS=true
else
    IS_WINDOWS=false
fi

# Display help message
show_help() {
    echo "AI Document Assistant Setup and Run Script"
    echo "Usage: $0 [--backend-port <port>] [--frontend-port <port>] [--help]"
    echo "Options:"
    echo "  --backend-port <port>  Specify backend port (default: $DEFAULT_BACKEND_PORT)"
    echo "  --frontend-port <port> Specify frontend port (default: $DEFAULT_FRONTEND_PORT)"
    echo "  --help                Display this help message"
    echo "Description:"
    echo "  Installs dependencies and runs the backend (FastAPI) and frontend (React/Vite)."
    echo "  Supports Llama3.1, Llama2 (Ollama), and T5 (Hugging Face) for AI document processing."
    echo "  Demo account: email: demo@example.com, password: password"
    echo "Logs:"
    echo "  Main log: $LOG_FILE"
    echo "  Backend log: $BACKEND_LOG"
    echo "  Frontend log: $FRONTEND_LOG"
    echo "Note for Windows/Git Bash users:"
    echo "  Install tools like net-tools, curl, wget via MSYS2: pacman -S net-tools curl wget"
    echo "  For Ollama port conflicts, use 'netstat -ano | findstr :$OLLAMA_PORT' or Task Manager."
    echo "  Use a virtual environment to avoid Python conflicts: python -m venv venv"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backend-port)
            BACKEND_PORT="$2"
            shift 2
            ;;
        --frontend-port)
            FRONTEND_PORT="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--backend-port <port>] [--frontend-port <port>] [--help]" >&2
            exit 1
            ;;
    esac
done

# Validate port numbers
for port in "$BACKEND_PORT" "$FRONTEND_PORT"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
        echo "ERROR: Port $port is invalid. Must be a number between 1024 and 65535." >&2
        exit 1
    fi
done

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $level: $message" | tee -a "$LOG_FILE"
    if [[ "$level" == "ERROR" ]]; then
        echo "ERROR: $message" >&2
    elif [[ "$level" == "INFO" || "$level" == "SUCCESS" ]]; then
        echo "$message"
    fi
}

# Rotate log file if too large
rotate_log() {
    local file="$1"
    if [ -f "$file" ]; then
        local size
        if stat -c %s "$file" >/dev/null 2>&1; then
            size=$(stat -c %s "$file")
        elif stat -f %z "$file" >/dev/null 2>&1; then
            size=$(stat -f %z "$file")
        else
            size=0
        fi
        if [ "$size" -gt "$LOG_MAX_SIZE" ]; then
            mv "$file" "${file}.$(date '+%Y%m%d%H%M%S').bak"
            log "INFO" "Rotated $file due to size exceeding $LOG_MAX_SIZE bytes."
        fi
    fi
}

# Initialize log files with a separator
for file in "$LOG_FILE" "$BACKEND_LOG" "$FRONTEND_LOG"; do
    rotate_log "$file"
    if [ -f "$file" ]; then
        echo -e "\n--- New Run: $timestamp ---\n" >> "$file"
    else
        touch "$file"
    fi
done
log "INFO" "Starting AI Document Assistant setup and run script"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check for null bytes in a file using Python
check_null_bytes() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 0
    fi
    if $PYTHON_CMD -c "with open('$file', 'rb') as f: content = f.read(); exit(0 if b'\x00' not in content else 1)" 2>/dev/null; then
        return 0
    else
        log "ERROR" "Null bytes detected in $file. Replacing with a clean version."
        return 1
    fi
}

# Function to check if a port is in use (exclude Ollama port during conflict checks)
check_port() {
    local port=$1
    local port_in_use=false
    if [ "$port" -eq "$OLLAMA_PORT" ]; then
        log "INFO" "Skipping conflict check for Ollama port $OLLAMA_PORT."
        return 0
    fi
    if $IS_WINDOWS; then
        if command_exists netstat && netstat -ano | findstr ":$port" | findstr "LISTENING" >/dev/null; then
            port_in_use=true
        elif command_exists netstat && netstat -ano | findstr ":$port" >/dev/null; then
            port_in_use=true
        fi
    else
        if command_exists lsof && lsof -i :"$port" -sTCP:LISTEN >/dev/null; then
            port_in_use=true
        elif command_exists netstat && netstat -tuln | grep -q ":$port "; then
            port_in_use=true
        elif command_exists ss && ss -tuln | grep -q ":$port "; then
            port_in_use=true
        fi
    fi
    if ! $port_in_use && command_exists curl && curl -s --connect-timeout 2 http://localhost:$port >/dev/null; then
        port_in_use=true
    fi
    if $port_in_use; then
        log "ERROR" "Port $port is already in use. Specify a different port with --backend-port or --frontend-port."
        return 1
    fi
    log "INFO" "Port $port is free."
    return 0
}

# Function to verify service accessibility
check_service() {
    local url=$1
    local name=$2
    local retries=5
    local delay=5
    if command_exists curl; then
        for ((i=1; i<=retries; i++)); do
            if curl -s --head --connect-timeout 5 "$url" >/dev/null; then
                log "INFO" "$name is accessible at $url"
                return 0
            fi
            log "INFO" "Waiting for $name to start (attempt $i/$retries)..."
            sleep $delay
        done
    elif command_exists wget; then
        for ((i=1; i<=retries; i++)); do
            if wget -q --spider --timeout=5 "$url" >/dev/null; then
                log "INFO" "$name is accessible at $url"
                return 0
            fi
            log "INFO" "Waiting for $name to start (attempt $i/$retries)..."
            sleep $delay
        done
    else
        log "WARNING" "Neither curl nor wget found, skipping $name accessibility check."
        if $IS_WINDOWS; then
            log "INFO" "Install curl/wget via MSYS2: pacman -S net-tools curl wget"
        else
            log "INFO" "Install curl/wget: sudo apt-get install curl wget || sudo yum install curl wget"
        fi
        return 0
    fi
    log "ERROR" "$name failed to start or is not accessible at $url. Check ${name,,}.log for details."
    return 1
}

# Check Git repository status
if command_exists git && [ -d ".git" ]; then
    log "INFO" "Checking Git repository status..."
    if git status --porcelain | grep -q .; then
        log "WARNING" "Uncommitted changes detected in Git repository. Consider committing before running."
        git status --short
        log "INFO" "To commit: git add . && git commit -m 'Update project files'"
    else
        log "INFO" "Git repository is clean."
    fi
else
    log "WARNING" "Not a Git repository or git not installed. Skipping Git status check."
fi

# Check prerequisites
log "INFO" "Checking prerequisites..."

# Check Python
PYTHON_CMD="python"
if ! command_exists "$PYTHON_CMD"; then
    PYTHON_CMD="python3"
    if ! command_exists "$PYTHON_CMD"; then
        log "ERROR" "Python not found. Please install Python 3.8 or higher."
        exit 1
    fi
fi
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | grep -oE '[0-9]+\.[0-9]+' | head -1)
PYTHON_MAJOR=${PYTHON_MAJOR_MINOR%%.*}
PYTHON_MINOR=${PYTHON_MAJOR_MINOR##*.}
if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]; }; then
    log "ERROR" "Python $PYTHON_VERSION is too old. Please install Python 3.8 or higher."
    exit 1
fi
log "INFO" "Python found: $PYTHON_VERSION"

# Check Node.js
if ! command_exists node; then
    log "ERROR" "Node.js not found. Please install Node.js 16 or higher."
    exit 1
fi
NODE_VERSION=$(node --version)
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1 | tr -d 'v')
if [ "$NODE_MAJOR" -lt 16 ]; then
    log "ERROR" "Node.js $NODE_VERSION is too old. Please install Node.js 16 or higher."
    exit 1
fi
log "INFO" "Node.js found: $NODE_VERSION"

# Check npm
if ! command_exists npm; then
    log "ERROR" "npm not found. Please install npm."
    exit 1
fi
NPM_VERSION=$(npm --version)
log "INFO" "npm found: $NPM_VERSION"

# Check and start Ollama
if command_exists ollama; then
    log "INFO" "Checking Ollama service..."
    OLLAMA_RUNNING=false
    if command_exists netstat && netstat -ano | findstr ":$OLLAMA_PORT" | findstr "LISTENING" >/dev/null; then
        OLLAMA_RUNNING=true
        log "INFO" "Ollama service detected on port $OLLAMA_PORT."
    elif command_exists curl && curl -s --connect-timeout 2 http://localhost:$OLLAMA_PORT >/dev/null; then
        OLLAMA_RUNNING=true
        log "INFO" "Ollama API detected at http://localhost:$OLLAMA_PORT."
    fi

    if $OLLAMA_RUNNING; then
        if $IS_WINDOWS && command_exists netstat; then
            OLLAMA_PID=$(netstat -ano | findstr ":$OLLAMA_PORT" | findstr "LISTENING" | awk '{print $5}' | head -1)
        elif command_exists ps; then
            OLLAMA_PID=$(ps aux | grep -i "[o]llama serve" | awk '{print $2}' | head -1)
        fi
        if [ -n "$OLLAMA_PID" ] && [[ "$OLLAMA_PID" =~ ^[0-9]+$ ]]; then
            log "INFO" "Ollama service is running (PID: $OLLAMA_PID)."
        else
            log "INFO" "Ollama service is running, but PID could not be determined."
            OLLAMA_PID=""
        fi
    fi

    if ! $OLLAMA_RUNNING; then
        log "INFO" "Ollama service not running, attempting to start..."
        ollama serve &
        OLLAMA_PID=$!
        sleep 5
        if ! ps -p $OLLAMA_PID >/dev/null 2>&1; then
            log "ERROR" "Failed to start Ollama service. Check if port $OLLAMA_PORT is in use."
            if $IS_WINDOWS; then
                log "INFO" "Run 'netstat -ano | findstr :$OLLAMA_PORT' or check Task Manager."
                log "INFO" "To stop the process (e.g., PID 1912): taskkill /PID 1912 /F"
            else
                log "INFO" "Run 'netstat -tuln | grep $OLLAMA_PORT' or 'lsof -i :$OLLAMA_PORT'."
            fi
            exit 1
        fi
        OLLAMA_RUNNING=true
        log "SUCCESS" "Ollama service started (PID: $OLLAMA_PID)."
    fi

    if command_exists curl && ! curl -s --connect-timeout 5 http://localhost:$OLLAMA_PORT >/dev/null; then
        log "WARNING" "Ollama API is not responsive. Models may not work correctly."
        if $IS_WINDOWS; then
            log "INFO" "Check if Ollama is running: netstat -ano | findstr :$OLLAMA_PORT"
            log "INFO" "Restart Ollama or stop the process on port $OLLAMA_PORT."
        fi
    fi

    for model in "${OLLAMA_MODELS[@]}"; do
        if ollama list | grep -q "$model"; then
            log "INFO" "Ollama model $model is available."
        else
            log "INFO" "Ollama model $model not found, pulling..."
            if command_exists timeout; then
                if timeout 300 ollama pull "$model" >> "$LOG_FILE" 2>&1; then
                    log "SUCCESS" "Ollama model $model pulled successfully."
                else
                    log "WARNING" "Failed to pull Ollama model $model after 5 minutes. T5 will be used as fallback."
                fi
            else
                if ollama pull "$model" >> "$LOG_FILE" 2>&1; then
                    log "SUCCESS" "Ollama model $model pulled successfully."
                else
                    log "WARNING" "Failed to pull Ollama model $model. T5 will be used as fallback."
                fi
            fi
        fi
    done
else
    log "WARNING" "Ollama not found. T5 will be used as fallback."
    if $IS_WINDOWS; then
        log "INFO" "Install Ollama from https://ollama.com and ensure it's in PATH."
    else
        log "INFO" "Install Ollama: curl https://ollama.com/install.sh | sh"
    fi
fi

# Check ports
for port in "$BACKEND_PORT" "$FRONTEND_PORT"; do
    if ! check_port "$port"; then
        exit 1
    fi
done

# Install backend dependencies
log "INFO" "Installing backend dependencies..."
pushd "$BACKEND_DIR" >/dev/null || { log "ERROR" "Backend directory not found."; exit 1; }
if [ ! -f "requirements.txt" ]; then
    log "INFO" "requirements.txt not found in $BACKEND_DIR. Creating a minimal version."
    cat > requirements.txt <<EOL
fastapi>=0.115.0
uvicorn>=0.32.0
pydantic>=2.9.2
pydantic-settings>=2.5.2
email-validator>=2.2.0
python-jose>=3.3.0
passlib>=1.7.4
bcrypt>=4.2.0
python-multipart>=0.0.12
sqlalchemy>=2.0.35
transformers>=4.45.2
torch>=2.4.1
requests>=2.32.3
EOL
else
    # Fix any malformed entries in requirements.txt
    if grep -q "pydanticpydantic-settings" requirements.txt; then
        log "WARNING" "Found malformed 'pydanticpydantic-settings' in requirements.txt. Correcting to 'pydantic-settings>=2.5.2'."
        sed -i 's/pydanticpydantic-settings.*/pydantic-settings>=2.5.2/' requirements.txt
    fi
fi
# Install build tools
$PYTHON_CMD -m pip install --upgrade pip setuptools wheel >> "$LOG_FILE" 2>&1
# Clear pip cache to avoid corrupted downloads
$PYTHON_CMD -m pip cache purge >> "$LOG_FILE" 2>&1
# Always use a virtual environment
log "INFO" "Setting up virtual environment to isolate dependencies."
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to create virtual environment. Ensure venv module is available."
        log "INFO" "Alternatively, install manually: python -m pip install -r requirements.txt"
        popd >/dev/null
        exit 1
    fi
fi
if $IS_WINDOWS; then
    source venv/Scripts/activate >> "$LOG_FILE" 2>&1
    PYTHON_CMD="$PWD/venv/Scripts/python"
    PIP_CMD="$PWD/venv/Scripts/pip"
else
    source venv/bin/activate >> "$LOG_FILE" 2>&1
    PYTHON_CMD="$PWD/venv/bin/python"
    PIP_CMD="$PWD/venv/bin/pip"
fi
if [ $? -eq 0 ]; then
    log "INFO" "Virtual environment activated. Upgrading pip and installing build tools."
    $PIP_CMD install --upgrade pip setuptools wheel >> "$LOG_FILE" 2>&1
else
    log "ERROR" "Failed to activate virtual environment. Ensure venv module is available."
    popd >/dev/null
    exit 1
fi
# Try installing dependencies with retries
for attempt in {1..3}; do
    if $PIP_CMD install -r requirements.txt > pip_install.log 2>&1; then
        log "SUCCESS" "Backend dependencies installed successfully."
        break
    else
        log "WARNING" "Attempt $attempt: Failed to install backend dependencies. Retrying..."
        sleep 2
    fi
done
if [ ! -f "pip_install.log" ] || grep -q "ERROR" pip_install.log; then
    log "ERROR" "Failed to install backend dependencies after retries. Check $LOG_FILE and pip_install.log for details."
    log "INFO" "Common fixes:"
    log "INFO" "- Ensure internet connectivity."
    log "INFO" "- Verify requirements.txt for compatible versions."
    log "INFO" "- Install build tools: $PIP_CMD install setuptools wheel"
    log "INFO" "- Clear pip cache: $PIP_CMD cache purge"
    log "INFO" "- Test manually: cd $BACKEND_DIR && $PIP_CMD install -r requirements.txt"
    if [ -f pip_install.log ]; then
        cat pip_install.log | grep -i "ERROR" | head -n 10 | tee -a "$LOG_FILE"
    fi
    popd >/dev/null
    exit 1
fi
# Ensure pydantic-settings and email-validator are installed
if ! grep -q "pydantic-settings" requirements.txt; then
    log "WARNING" "pydantic-settings not found in $BACKEND_DIR/requirements.txt. Adding pydantic-settings>=2.5.2."
    printf "pydantic-settings>=2.5.2\n" >> requirements.txt
    $PIP_CMD install pydantic-settings>=2.5.2 >> "$LOG_FILE" 2>&1
fi
if ! grep -q "email-validator" requirements.txt; then
    log "WARNING" "email-validator not found in $BACKEND_DIR/requirements.txt. Adding email-validator>=2.2.0."
    printf "email-validator>=2.2.0\n" >> requirements.txt
    $PIP_CMD install email-validator>=2.2.0 >> "$LOG_FILE" 2>&1
fi
if ! grep -q "bcrypt" requirements.txt; then
    log "WARNING" "bcrypt not found in $BACKEND_DIR/requirements.txt. Adding bcrypt>=4.2.0."
    printf "bcrypt>=4.2.0\n" >> requirements.txt
    $PIP_CMD install bcrypt>=4.2.0 >> "$LOG_FILE" 2>&1
fi
rm -f pip_install.log
popd >/dev/null

# Install frontend dependencies
log "INFO" "Installing frontend dependencies..."
pushd "$FRONTEND_DIR" >/dev/null || { log "ERROR" "Frontend directory not found."; exit 1; }
if ! npm install > npm_install.log 2>&1; then
    log "ERROR" "Failed to install frontend dependencies. Check $LOG_FILE and npm_install.log for details."
    log "INFO" "Common fixes:"
    log "INFO" "- Ensure internet connectivity."
    log "INFO" "- Clear npm cache: npm cache clean --force"
    log "INFO" "- Update npm: npm install -g npm"
    cat npm_install.log | grep -i "error" | tee -a "$LOG_FILE"
    popd >/dev/null
    exit 1
fi
log "SUCCESS" "Frontend dependencies installed successfully."
rm -f npm_install.log
popd >/dev/null

# Start backend and frontend in background
log "INFO" "Starting backend and frontend servers..."

# Check backend application
if [ ! -f "$BACKEND_DIR/main.py" ]; then
    log "ERROR" "Backend application file $BACKEND_DIR/main.py not found. Ensure the FastAPI application is correctly set up."
    log "INFO" "Check the repository (https://github.com/GAN-007/ai-document-assistant) for the correct file."
    exit 1
fi
# Validate main.py contents
if ! grep -q "from fastapi import FastAPI" "$BACKEND_DIR/main.py" || ! grep -q "app = FastAPI" "$BACKEND_DIR/main.py"; then
    log "WARNING" "$BACKEND_DIR/main.py does not appear to define a FastAPI app. Ensure it contains 'from fastapi import FastAPI' and 'app = FastAPI()'."
fi
# Check for settings module
if ! [ -f "$BACKEND_DIR/app/settings/config.py" ]; then
    log "WARNING" "Settings module $BACKEND_DIR/app/settings/config.py not found. Creating a comprehensive configuration."
    mkdir -p "$BACKEND_DIR/app/settings"
    cat > "$BACKEND_DIR/app/settings/config.py" <<EOL
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
EOL
    log "INFO" "Created $BACKEND_DIR/app/settings/config.py with default settings."
fi
# Validate critical files for null bytes
for file in "$BACKEND_DIR/app/settings/config.py" "$BACKEND_DIR/app/api/endpoints.py" "$BACKEND_DIR/app/core/auth.py" "$BACKEND_DIR/app/core/document_processor.py" "$BACKEND_DIR/app/database/db.py" "$BACKEND_DIR/app/api/models.py"; do
    if [ -f "$file" ] && ! check_null_bytes "$file"; then
        case $(basename "$file") in
            config.py)
                cat > "$file" <<EOL
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
EOL
                ;;
            endpoints.py)
                cat > "$file" <<EOL
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import List
from app.core.auth import create_access_token, get_current_user, verify_password, get_password_hash
from app.core.document_processor import process_document
from app.database.db import get_db
from app.schemas.document import DocumentResponse, Suggestion
from app.schemas.user import UserCreate, UserResponse
from app.api.models import User, Document
from app.settings.config import SUPPORTED_FILE_TYPES, MODEL_INFO
from datetime import timedelta
import os

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/login")

@router.post("/register", response_model=UserResponse)
async def register(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        hashed_password=hashed_password,
        role="user"
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
    return {"access_token": access_token, "token_type": "bearer", "user": UserResponse.from_orm(user)}

@router.post("/validate-token", response_model=UserResponse)
async def validate_token(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/upload", response_model=DocumentResponse)
async def upload_file(file: UploadFile = File(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if not any(file.content_type == ft["mime_type"] for ft in SUPPORTED_FILE_TYPES):
        raise HTTPException(status_code=400, detail="Unsupported file type")
    if file.size > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=400, detail="File too large")
    
    content = await file.read()
    original_text, improved_text, suggestions = await process_document(file.filename, content, file.content_type)
    
    db_document = Document(
        user_id=current_user.id,
        filename=file.filename,
        content=improved_text
    )
    db.add(db_document)
    db.commit()
    db.refresh(db_document)
    
    return DocumentResponse(
        originalText=original_text,
        improvedText=improved_text,
        suggestions=suggestions,
        filename=file.filename
    )

@router.post("/save")
async def save_document(document: DocumentResponse, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_document = db.query(Document).filter(Document.user_id == current_user.id, Document.filename == document.filename).first()
    if not db_document:
        db_document = Document(
            user_id=current_user.id,
            filename=document.filename,
            content=document.improvedText
        )
        db.add(db_document)
    else:
        db_document.content = document.improvedText
    db.commit()
    return {"message": "Document saved successfully"}

@router.get("/config/file-types")
async def get_file_types():
    return SUPPORTED_FILE_TYPES

@router.get("/model-info")
async def get_model_info():
    return MODEL_INFO
EOL
                ;;
            auth.py)
                cat > "$file" <<EOL
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta
from app.settings.config import config
from app.api.models import User
from app.database.db import get_db
from sqlalchemy.orm import Session

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/login")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, config.jwt_secret, algorithm="HS256")
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, config.jwt_secret, algorithms=["HS256"])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception
    return user
EOL
                ;;
            document_processor.py)
                cat > "$file" <<EOL
from app.schemas.document import Suggestion

async def process_document(filename: str, content: bytes, content_type: str):
    # Placeholder: Implement AI processing with Ollama or T5
    original_text = content.decode('utf-8', errors='ignore')
    improved_text = original_text.upper()  # Dummy improvement
    suggestions = [Suggestion(text="Example suggestion", type="style")]
    return original_text, improved_text, suggestions
EOL
                ;;
            db.py)
                cat > "$file" <<EOL
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.settings.config import config

engine = create_engine(config.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    from app.api.models import User, Document
    Base.metadata.create_all(bind=engine)
EOL
                ;;
            models.py)
                cat > "$file" <<EOL
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from app.database.db import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    role = Column(String, default="user")
    documents = relationship("Document", back_populates="user")

class Document(Base):
    __tablename__ = "documents"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    filename = Column(String, index=True)
    content = Column(String)
    user = relationship("User", back_populates="documents")
EOL
                ;;
        esac
        log "INFO" "Replaced $file with a clean version."
    fi
done
# Validate schema files
if [ -f "$BACKEND_DIR/app/schemas/user.py" ]; then
    if ! grep -q "UserResponse" "$BACKEND_DIR/app/schemas/user.py"; then
        log "WARNING" "UserResponse not found in $BACKEND_DIR/app/schemas/user.py. Adding UserResponse schema."
        cat > "$BACKEND_DIR/app/schemas/user.py" <<EOL
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    email: EmailStr
    password: str

    class Config:
        from_attributes = True

class UserResponse(BaseModel):
    id: int
    email: EmailStr
    role: str

    class Config:
        from_attributes = True
EOL
    fi
fi
if [ ! -f "$BACKEND_DIR/app/schemas/document.py" ]; then
    log "WARNING" "Document schema $BACKEND_DIR/app/schemas/document.py not found. Creating with DocumentResponse and Suggestion."
    mkdir -p "$BACKEND_DIR/app/schemas"
    cat > "$BACKEND_DIR/app/schemas/document.py" <<EOL
from pydantic import BaseModel
from typing import List

class Suggestion(BaseModel):
    text: str
    type: str

    class Config:
        from_attributes = True

class DocumentResponse(BaseModel):
    originalText: str
    improvedText: str
    suggestions: List[Suggestion]
    filename: str

    class Config:
        from_attributes = True
EOL
elif ! grep -q "from_attributes" "$BACKEND_DIR/app/schemas/document.py"; then
    log "WARNING" "Pydantic 'from_attributes' not found in $BACKEND_DIR/app/schemas/document.py. Updating to fix orm_mode warning."
    mv "$BACKEND_DIR/app/schemas/document.py" "$BACKEND_DIR/app/schemas/document.py.bak"
    cat > "$BACKEND_DIR/app/schemas/document.py" <<EOL
from pydantic import BaseModel
from typing import List

class Suggestion(BaseModel):
    text: str
    type: str

    class Config:
        from_attributes = True

class DocumentResponse(BaseModel):
    originalText: str
    improvedText: str
    suggestions: List[Suggestion]
    filename: str

    class Config:
        from_attributes = True
EOL
fi
# Test import of main module
if ! $PYTHON_CMD -c "import sys; sys.path.append('$BACKEND_DIR'); from main import app" > main_import.log 2>&1; then
    log "ERROR" "Failed to import $BACKEND_DIR/main.py module. Check $BACKEND_DIR/main.py for errors."
    log "INFO" "Common fixes:"
    log "INFO" "- Verify syntax and imports in $BACKEND_DIR/main.py."
    log "INFO" "- Ensure $BACKEND_DIR/app/settings/config.py exists and is correct."
    log "INFO" "- Reinstall dependencies: cd $BACKEND_DIR && $PIP_CMD install -r requirements.txt"
    log "INFO" "- Test manually: cd $BACKEND_DIR && $PYTHON_CMD -c 'from main import app'"
    cat main_import.log | tee -a "$BACKEND_LOG"
    rm -f main_import.log
    exit 1
fi
rm -f main_import.log

# Start backend
$PYTHON_CMD -m uvicorn --app-dir "$BACKEND_DIR" main:app --host 0.0.0.0 --port "$BACKEND_PORT" > uvicorn.log 2>&1 &
BACKEND_PID=$!
sleep 5
if ps -p $BACKEND_PID >/dev/null 2>&1; then
    log "SUCCESS" "Backend started successfully (PID: $BACKEND_PID)."
    check_service "http://localhost:$BACKEND_PORT" "Backend"
else
    log "ERROR" "Failed to start backend. Check $BACKEND_LOG for details."
    log "INFO" "Common fixes:"
    log "INFO" "- Verify $BACKEND_DIR/main.py has a valid FastAPI app."
    log "INFO" "- Check port $BACKEND_PORT: netstat -ano | findstr :$BACKEND_PORT"
    log "INFO" "- Ensure dependencies are compatible with Python $PYTHON_VERSION."
    log "INFO" "- Test manually: cd $BACKEND_DIR && $PYTHON_CMD -m uvicorn --app-dir . main:app --host 0.0.0.0 --port $BACKEND_PORT"
    cat uvicorn.log | grep -i "ERROR" | tee -a "$BACKEND_LOG"
    rm -f uvicorn.log
    exit 1
fi
mv uvicorn.log "$BACKEND_LOG"
popd >/dev/null 2>/dev/null || true

# Start frontend
pushd "$FRONTEND_DIR" >/dev/null
npm run dev -- --port "$FRONTEND_PORT" > "../$FRONTEND_LOG" 2>&1 &
FRONTEND_PID=$!
sleep 10
if ps -p $FRONTEND_PID >/dev/null 2>&1; then
    log "SUCCESS" "Frontend started successfully (PID: $FRONTEND_PID)."
    check_service "http://localhost:$FRONTEND_PORT" "Frontend"
else
    log "ERROR" "Failed to start frontend. Check $FRONTEND_LOG for details."
    popd >/dev/null
    exit 1
fi
popd >/dev/null

# Display access information
log "SUCCESS" "AI Document Assistant is running!"
log "INFO" "Frontend: http://localhost:$FRONTEND_PORT"
log "INFO" "Backend API: http://localhost:$BACKEND_PORT"
log "INFO" "Use Ctrl+C to stop the servers."
log "INFO" "Demo account: email: demo@example.com, password: password"
if command_exists git && [ -d ".git" ]; then
    log "INFO" "Setup complete. Consider committing changes with: git add . && git commit -m 'Setup AI Document Assistant'"
fi

# Trap Ctrl+C for cleanup
trap 'cleanup' SIGINT SIGTERM

cleanup() {
    log "INFO" "Stopping services..."
    for pid in "$BACKEND_PID" "$FRONTEND_PID" "$OLLAMA_PID"; do
        if [[ -n "$pid" ]]; then
            if $IS_WINDOWS && command_exists taskkill; then
                taskkill /PID "$pid" /F >/dev/null 2>&1
                log "INFO" "Stopped process (PID: $pid)."
            elif ps -p "$pid" >/dev/null 2>&1; then
                pkill -P "$pid" 2>/dev/null
                kill "$pid" 2>/dev/null
                wait "$pid" 2>/dev/null
                log "INFO" "Stopped process (PID: $pid)."
            fi
        fi
    done
    log "SUCCESS" "Services stopped."
    exit 0
}

# Monitor processes
while true; do
    if ! ps -p "$BACKEND_PID" >/dev/null 2>&1 || ! ps -p "$FRONTEND_PID" >/dev/null 2>&1; then
        log "ERROR" "One or more services stopped unexpectedly. Check $BACKEND_LOG or $FRONTEND_LOG."
        cleanup
    fi
    sleep 5
done