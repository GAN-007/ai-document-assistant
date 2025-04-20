AI Document Assistant - Backend
A FastAPI-based backend for the AI Document Assistant, handling file uploads, document processing, user authentication, and suggestion generation.
Features

API endpoints for user registration, login, and token validation.
File upload and processing for multiple formats (PDF, DOCX, TXT, Excel, CSV, SQL, ZIP, RAR, images, media).
Document storage and retrieval using SQLite.
JWT-based authentication.
Unit tests for API endpoints and core functions.

Prerequisites

Python (>=3.8)
SQLite
Frontend running at http://localhost:3000 (see ../frontend/README.md)

Ollama Instance: Ensure your local Ollama instance is running with llama3.1:latest and llama2:latest available. Start Ollama with:
ollama run llama3.1
or
ollama run llama2

Installation

Navigate to the backend directory:cd backend


Create a virtual environment:python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate


Install dependencies:pip install -r requirements.txt


Start the server:uvicorn main:app --host 0.0.0.0 --port 8000



The API will be available at http://localhost:8000.
Testing
Run unit tests with:
pytest

Usage

Start the backend server.
Register a user via the frontend or POST to /api/register.
Log in via the frontend or POST to /api/login.
Upload a file via the frontend or POST to /api/upload.
Save documents via the frontend or POST to /api/save.

Directory Structure
backend/
├── app/
│   ├── api/              # API routes and models
│   ├── core/             # Authentication and document processing
│   ├── database/         # Database setup
│   ├── schemas/          # Pydantic schemas
│   ├── settings/         # Configuration settings
│   └── __init__.py
├── tests/                # Unit tests
├── main.py               # FastAPI entry point
├── requirements.txt      # Python dependencies
└── README.md             # This documentation

License
Licensed under the MIT License by George Nyamema © 2025
