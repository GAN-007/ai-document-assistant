AI Document Assistant
A full-stack web application for uploading, processing, and enhancing documents using AI-powered suggestions.
Overview
The AI Document Assistant allows users to:

Upload various file types (PDF, DOCX, TXT, Excel, CSV, SQL, ZIP, RAR).
View original and improved document versions side by side.
Accept or reject AI-generated suggestions using Llama3.1, Llama2, or T5 models.
Customize the UI with settings (dark mode, auto-save, notifications, export formats).
Enjoy 3D animations for visual appeal.
Authenticate securely with JWT.

Tech Stack

Frontend: React 18, Tailwind CSS, Three.js, Axios, Jest, Vite
Backend: FastAPI, SQLAlchemy, PyPDF2, python-docx, pandas, JWT, Pytest
AI Models: Llama3.1, Llama2 (Ollama), T5 (Hugging Face Transformers)
Database: SQLite
Deployment: Docker (optional)

Directory Structure
ai-document-assistant/
├── backend/              # FastAPI backend
├── frontend/             # React frontend
├── docker-compose.yml    # Docker configuration
├── setup_and_run.sh      # Bash script to install and run
├── .gitignore            # Git ignore rules
└── README.md             # This documentation

Prerequisites

Bash: Available on Linux, macOS, or Windows (via WSL, Git Bash, or Cygwin)
Node.js: >=16
Python: >=3.8
Ollama: Optional, for Llama3.1 and Llama2 models
Docker: Optional, for containerized deployment

Installation and Running

Clone the repository:git clone https://github.com/GAN-007/ai-document-assistant
cd ai-document-assistant


Make the setup script executable (Linux/macOS):chmod +x setup_and_run.sh


Run the setup script:./setup_and_run.sh

Or with custom ports:./setup_and_run.sh --backend-port 8080 --frontend-port 3001


Access the application:
Frontend: http://localhost:<frontend-port>
Backend API: http://localhost:<backend-port>



Running with Docker

Ensure Docker and Docker Compose are installed.
Run:docker-compose up --build


Access the frontend at http://localhost:3000 and backend at http://localhost:8000.

Testing

Backend tests: cd backend && pytest
Frontend tests: cd frontend && npm test

Usage

Run the setup script or Docker.
Log in using the demo account (email: demo@example.com, password: password).
Upload a document to view improvements and suggestions.
Customize settings, save, or export the document.

License
Licensed under the MIT License by George Nyamema © 2025
