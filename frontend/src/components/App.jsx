import React, { useState, useContext } from 'react';
import { DocumentContext } from '../context/DocumentContext';
import FileUpload from './FileUpload';
import DocumentViewer from './DocumentViewer';
import ThreeDAnimation from './ThreeDAnimation';
import SettingsPanel from './SettingsPanel';
import StatusNotification from './StatusNotification';

/**
 * Main content component for the AI Document Assistant.
 * Manages the layout, conditional rendering, and user interactions.
 */
const AppContent = () => {
    const { originalText, resetDocument, user, login, logout } = useContext(DocumentContext);
    const [showSettings, setShowSettings] = useState(false);

    // Handle demo login for testing
    const handleDemoLogin = () => {
        login({ username: 'demo@example.com', password: 'password' });
    };

    return (
        <div className="container mx-auto px-4 py-8 max-w-7xl">
            {/* Header with title and user controls */}
            <header className="text-center mb-8">
                <h1 className="text-4xl font-bold gradient-blue text-transparent bg-clip-text">
                    AI Document Assistant
                </h1>
                <p className="mt-2 text-gray-600 dark:text-gray-300">
                    Enhance your documents with AI-powered suggestions
                </p>
                <div className="mt-4 flex justify-center space-x-4">
                    {user ? (
                        <div className="flex items-center space-x-2">
                            <span className="text-sm">
                                Welcome, <span className="font-medium">{user.name}</span> ({user.role})
                            </span>
                            <button
                                className="text-sm underline text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300"
                                onClick={logout}
                            >
                                Log out
                            </button>
                        </div>
                    ) : (
                        <button
                            className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 underline"
                            onClick={handleDemoLogin}
                        >
                            Login (Demo)
                        </button>
                    )}
                    <button
                        className="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 underline"
                        onClick={() => setShowSettings(!showSettings)}
                    >
                        {showSettings ? 'Hide Settings' : 'Show Settings'}
                    </button>
                </div>
            </header>

            {/* 3D animation for visual appeal */}
            <ThreeDAnimation />

            {/* Button to upload a different document */}
            {originalText && (
                <button
                    className="mb-4 px-4 py-2 bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded transition-colors flex items-center"
                    onClick={resetDocument}
                    aria-label="Upload a different document"
                >
                    <svg className="w-4 h-4 mr-2" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                        <path fillRule="evenodd" d="M9.707 14.707a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 1.414L7.414 9H15a1 1 0 110 2H7.414l2.293 2.293a1 1 0 010 1.414z" clipRule="evenodd" />
                    </svg>
                    Upload a different document
                </button>
            )}

            {/* Status notification for user feedback */}
            <StatusNotification />

            {/* Settings panel, shown conditionally */}
            {showSettings && <SettingsPanel />}

            {/* Conditional rendering of upload or viewer */}
            {!originalText ? <FileUpload /> : <DocumentViewer />}

            {/* Footer with attribution */}
            <footer className="mt-12 text-center text-sm text-gray-500 dark:text-gray-400">
                <p>AI Document Assistant © 2025 - Licensed by George Nyamema</p>
                <p className="mt-1">Version 1.0.0</p>
            </footer>
        </div>
    );
};

/**
 * Root App component, wrapping content with DocumentProvider.
 */
const App = () => (
    <DocumentProvider>
        <AppContent />
    </DocumentProvider>
);

export default App;