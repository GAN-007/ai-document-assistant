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

# Initialize ports from arguments
BACKEND_PORT=$DEFAULT_BACKEND_PORT
FRONTEND_PORT=$DEFAULT_FRONTEND_PORT

# Display help message
show_help() {
    echo "Usage: $0 [--backend-port <port>] [--frontend-port <port>] [--help]"
    echo "Options:"
    echo "  --backend-port <port>  Specify backend port (default: $DEFAULT_BACKEND_PORT)"
    echo "  --frontend-port <port> Specify frontend port (default: $DEFAULT_FRONTEND_PORT)"
    echo "  --help                Display this help message"
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

# Append to log file with a separator for new run
if [ -f "$LOG_FILE" ]; then
    echo -e "\n--- New Run: $timestamp ---\n" >> "$LOG_FILE"
else
    touch "$LOG_FILE"
fi
log "INFO" "Starting AI Document Assistant setup and run script"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if command_exists lsof && lsof -i :"$port" -sTCP:LISTEN >/dev/null; then
        return 1
    elif command_exists netstat && netstat -tuln | grep -q ":$port "; then
        return 1
    elif command_exists ss && ss -tuln | grep -q ":$port "; then
        return 1
    else
        log "WARNING" "No port-checking tools (lsof, netstat, ss) found. Assuming port $port is free, but this may cause conflicts."
    fi
    return 0
}

# Function to verify service accessibility
check_service() {
    local url=$1
    local name=$2
    local retries=3
    local delay=5
    if command_exists curl; then
        for ((i=1; i<=retries; i++)); do
            if curl -s --head "$url" >/dev/null; then
                log "INFO" "$name is accessible at $url"
                return 0
            fi
            log "INFO" "Waiting for $name to start (attempt $i/$retries)..."
            sleep $delay
        done
    elif command_exists wget; then
        for ((i=1; i<=retries; i++)); do
            if wget -q --spider "$url" >/dev/null; then
                log "INFO" "$name is accessible at $url"
                return 0
            fi
            log "INFO" "Waiting for $name to start (attempt $i/$retries)..."
            sleep $delay
        done
    else
        log "WARNING" "Neither curl nor wget found, skipping $name accessibility check."
        return 0
    fi
    log "ERROR" "$name failed to start or is not accessible at $url"
    return 1
}

# Check prerequisites
log "INFO" "Checking prerequisites..."

# Check Python
PYTHON_CMD="python3"
if ! command_exists "$PYTHON_CMD"; then
    PYTHON_CMD="python"
    if ! command_exists "$PYTHON_CMD"; then
        log "ERROR" "Python not found. Please install Python 3.8 or higher."
        exit 1
    fi
fi
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
PYTHON_MAJOR_MINOR=$(echo "$PYTHON_VERSION" | grep -oE '[0-9]+\.[0-9]+' | head -1)
if [ "$(echo "$PYTHON_MAJOR_MINOR < 3.8" | bc -l)" -eq 1 ]; then
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
    # Check if Ollama service is running
    if ! pgrep -f "ollama serve" >/dev/null; then
        log "INFO" "Ollama service not running, attempting to start..."
        ollama serve &
        OLLAMA_PID=$!
        sleep 5
        if ! ps -p $OLLAMA_PID >/dev/null; then
            log "ERROR" "Failed to start Ollama service."
            exit 1
        fi
        log "SUCCESS" "Ollama service started (PID: $OLLAMA_PID)."
    else
        # Get PID of existing Ollama service
        OLLAMA_PID=$(pgrep -f "ollama serve" | head -1)
        log "INFO" "Ollama service is already running (PID: $OLLAMA_PID)."
    fi

    # Check and pull Ollama models
    for model in "${OLLAMA_MODELS[@]}"; do
        if ollama list | grep -q "$model"; then
            log "INFO" "Ollama model $model is available."
        else
            log "INFO" "Ollama model $model not found, pulling..."
            if ollama pull "$model" >> "$LOG_FILE" 2>&1; then
                log "SUCCESS" "Ollama model $model pulled successfully."
            else
                log "WARNING" "Failed to pull Ollama model $model. T5 will be used as fallback."
            fi
        fi
    done
else
    log "WARNING" "Ollama not found. T5 will be used as fallback."
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
if ps -p $BACKEND_PID >/dev/null; then
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
if ps -p $FRONTEND_PID >/dev/null; then
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

# Trap Ctrl+C for cleanup
trap 'cleanup' SIGINT SIGTERM

cleanup() {
    log "INFO" "Stopping services..."
    for pid in "$BACKEND_PID" "$FRONTEND_PID" "$OLLAMA_PID"; do
        if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null; then
            # Kill process and its children
            pkill -P "$pid" 2>/dev/null
            kill "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            log "INFO" "Stopped process (PID: $pid)."
        fi
    done
    log "SUCCESS" "Services stopped."
    exit 0
}

# Monitor processes
while true; do
    if ! ps -p "$BACKEND_PID" >/dev/null || ! ps -p "$FRONTEND_PID" >/dev/null; then
        log "ERROR" "One or more services stopped unexpectedly. Check $BACKEND_LOG or $FRONTEND_LOG."
        cleanup
    fi
    sleep 5
done