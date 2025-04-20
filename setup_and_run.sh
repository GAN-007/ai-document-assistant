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

# Function to check if a port is in use
check_port() {
    local port=$1
    if $IS_WINDOWS; then
        if command_exists netstat && netstat -ano | grep -i "LISTEN" | grep -q ":$port "; then
            return 1
        fi
    else
        if command_exists lsof && lsof -i :"$port" -sTCP:LISTEN >/dev/null; then
            return 1
        elif command_exists netstat && netstat -tuln | grep -q ":$port "; then
            return 1
        elif command_exists ss && ss -tuln | grep -q ":$port "; then
            return 1
        fi
    fi
    # Fallback: Try connecting to the port (for Ollama)
    if [ "$port" -eq "$OLLAMA_PORT" ] && command_exists curl && curl -s --connect-timeout 2 http://localhost:$port >/dev/null; then
        return 1
    fi
    log "WARNING" "No reliable port-checking tools found. Assuming port $port is free, but this may cause conflicts."
    if $IS_WINDOWS; then
        log "INFO" "Run 'netstat -ano | findstr :$port' or install net-tools via MSYS2: pacman -S net-tools"
    else
        log "INFO" "Install tools: sudo apt-get install lsof net-tools || sudo yum install lsof net-tools"
    fi
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
            log "INFO" "Install curl/wget via MSYS2: pacman -S curl wget"
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
    # Check if Ollama is running by port or API
    OLLAMA_RUNNING=false
    if ! check_port "$OLLAMA_PORT"; then
        OLLAMA_RUNNING=true
        log "INFO" "Ollama service detected on port $OLLAMA_PORT."
    elif command_exists curl && curl -s --connect-timeout 2 http://localhost:$OLLAMA_PORT >/dev/null; then
        OLLAMA_RUNNING=true
        log "INFO" "Ollama API detected at http://localhost:$OLLAMA_PORT."
    fi

    # Try to get PID if running
    if $OLLAMA_RUNNING; then
        if $IS_WINDOWS && command_exists tasklist; then
            OLLAMA_PID=$(tasklist | grep -i "ollama" | awk '{print $2}' | head -1)
        elif command_exists ps; then
            OLLAMA_PID=$(ps aux | grep -i "[o]llama serve" | awk '{print $2}' | head -1)
        fi
        if [ -n "$OLLAMA_PID" ]; then
            log "INFO" "Ollama service is running (PID: $OLLAMA_PID)."
        else
            log "INFO" "Ollama service is running, but PID could not be determined."
            OLLAMA_PID=""
        fi
    fi

    # Start Ollama if not running
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

    # Verify Ollama API
    if command_exists curl && ! curl -s --connect-timeout 5 http://localhost:$OLLAMA_PORT >/dev/null; then
        log "WARNING" "Ollama API is not responsive. Models may not work correctly."
        if $IS_WINDOWS; then
            log "INFO" "Check if Ollama is running: netstat -ano | findstr :$OLLAMA_PORT"
            log "INFO" "Restart Ollama or stop the process on port $OLLAMA_PORT."
        fi
    fi

    # Check and pull Ollama models with timeout
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
        log "ERROR" "Port $port is already in use. Please specify a different port using --backend-port or --frontend-port."
        exit 1
    fi
done

# Install backend dependencies
log "INFO" "Installing backend dependencies..."
pushd "$BACKEND_DIR" >/dev/null || { log "ERROR" "Backend directory not found."; exit 1; }
$PYTHON_CMD -m pip install --upgrade pip >> "$LOG_FILE" 2>&1
if $PYTHON_CMD -m pip install -r requirements.txt >> "$LOG_FILE" 2>&1; then
    log "SUCCESS" "Backend dependencies installed successfully."
else
    log "ERROR" "Failed to install backend dependencies. Check $LOG_FILE for details."
    popd >/dev/null
    exit 1
fi
popd >/dev/null

# Install frontend dependencies
log "INFO" "Installing frontend dependencies..."
pushd "$FRONTEND_DIR" >/dev/null || { log "ERROR" "Frontend directory not found."; exit 1; }
if npm install >> "$LOG_FILE" 2>&1; then
    log "SUCCESS" "Frontend dependencies installed successfully."
else
    log "ERROR" "Failed to install frontend dependencies. Check $LOG_FILE for details."
    popd >/dev/null
    exit 1
fi
popd >/dev/null

# Start backend and frontend in background
log "INFO" "Starting backend and frontend servers..."

# Start backend
$PYTHON_CMD -m uvicorn --app-dir "$BACKEND_DIR/app" main:app --host 0.0.0.0 --port "$BACKEND_PORT" > "$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!
sleep 2
if ps -p $BACKEND_PID >/dev/null 2>&1; then
    log "SUCCESS" "Backend started successfully (PID: $BACKEND_PID)."
    check_service "http://localhost:$BACKEND_PORT" "Backend"
else
    log "ERROR" "Failed to start backend. Check $BACKEND_LOG for details."
    exit 1
fi

# Start frontend
pushd "$FRONTEND_DIR" >/dev/null
npm run dev -- --port "$FRONTEND_PORT" > "../$FRONTEND_LOG" 2>&1 &
FRONTEND_PID=$!
sleep 10 # Increased delay for Vite startup
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