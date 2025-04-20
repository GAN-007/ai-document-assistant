AI Document Assistant - Frontend
A React-based frontend for the AI Document Assistant, providing a user interface for uploading documents, viewing improvements, managing suggestions, and customizing settings.
Features

Drag-and-drop file upload with support for multiple file types.
Side-by-side document viewer for original and improved text.
Interactive suggestion management (accept/reject).
3D animation with Three.js for visual appeal.
Settings panel for dark mode, auto-save, notifications, and export formats.
Status notifications for user feedback.
Unit tests for all components.

Prerequisites

Node.js (>=16)
Backend running at http://localhost:8000 (see ../backend/README.md)

Installation

Navigate to the frontend directory:cd frontend


Install dependencies:npm install


Start the development server:npm run dev



The application will be available at http://localhost:3000.
Testing
Run unit tests with:
npm test

Usage

Start the backend server (see ../backend/README.md).
Start the frontend development server.
Log in using the demo account (email: demo@example.com, password: password).
Upload a document to view original and improved versions.
Manage suggestions, save documents, and export in your preferred format.

Directory Structure
frontend/
├── public/               # Static assets
├── src/
│   ├── components/       # React components
│   ├── context/          # React Context for state management
│   ├── styles/           # CSS styles with Tailwind
│   ├── tests/            # Unit tests
│   ├── utils/            # Utility functions
│   └── index.js          # Entry point
├── package.json          # Dependencies and scripts
├── vite.config.js        # Vite configuration
├── tailwind.config.js    # Tailwind CSS configuration
└── README.md             # This documentation

License
Licensed under the MIT License by George Nyamema © 2025
