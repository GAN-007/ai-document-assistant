import React, { useState, useRef, useCallback, useMemo } from 'react';
import PropTypes from 'prop-types';
import { DocumentContext } from '../context/DocumentContext';

/**
 * FileUpload component for uploading documents with drag-and-drop or file input.
 */
const FileUpload = () => {
    const { handleFileUpload, status, supportedFileTypes } = React.useContext(DocumentContext);
    const fileInputRef = useRef(null);
    const [dragActive, setDragActive] = useState(false);
    const [fileError, setFileError] = useState('');

    // Memoize supported file types for performance
    const validTypes = useMemo(() => supportedFileTypes.map(type => type.mime_type), [supportedFileTypes]);
    const maxSize = 10 * 1024 * 1024; // 10MB

    // Validate file type and size
    const validateFile = useCallback((file) => {
        if (!file) {
            setFileError('No file selected.');
            return false;
        }
        if (!validTypes.includes(file.type)) {
            setFileError(`Invalid file type. Supported types: ${supportedFileTypes.map(t => t.name).join(', ')}`);
            return false;
        }
        if (file.size > maxSize) {
            setFileError('File is too large. Maximum size is 10MB.');
            return false;
        }
        setFileError('');
        return true;
    }, [validTypes, supportedFileTypes]);

    // Process uploaded file
    const handleFile = useCallback((file) => {
        if (validateFile(file) && handleFileUpload) {
            handleFileUpload(file);
        }
    }, [validateFile, handleFileUpload]);

    // Handle file input change
    const handleChange = useCallback((e) => {
        setFileError('');
        const file = e.target.files?.[0];
        if (file) handleFile(file);
    }, [handleFile]);

    // Handle drag events
    const handleDrag = useCallback((e) => {
        e.preventDefault();
        e.stopPropagation();
        if (e.type === 'dragenter' || e.type === 'dragover') {
            setDragActive(true);
        } else if (e.type === 'dragleave') {
            setDragActive(false);
        }
    }, []);

    // Handle file drop
    const handleDrop = useCallback((e) => {
        e.preventDefault();
        e.stopPropagation();
        setDragActive(false);
        setFileError('');
        const file = e.dataTransfer.files?.[0];
        if (file) handleFile(file);
    }, [handleFile]);

    // Trigger file input click
    const handleButtonClick = useCallback(() => {
        fileInputRef.current?.click();
    }, []);

    // Handle keyboard navigation
    const handleKeyDown = useCallback((e) => {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            handleButtonClick();
        }
    }, [handleButtonClick]);

    return (
        <div className="w-full max-w-lg mx-auto mt-8 animate-slide-in-bottom">
            <div
                className={`
                    border-2 border-dashed rounded-lg p-8 text-center
                    transition-colors duration-200
                    ${dragActive
                        ? 'border-blue-600 bg-blue-50 dark:bg-blue-900'
                        : 'border-gray-300 dark:border-gray-600 hover:border-blue-600 dark:hover:border-blue-400 focus:border-blue-600'
                    }
                `}
                role="region"
                aria-label="File upload area"
                tabIndex={0}
                onDragEnter={handleDrag}
                onDragLeave={handleDrag}
                onDragOver={handleDrag}
                onDrop={handleDrop}
                onKeyDown={handleKeyDown}
                data-testid="drag-drop-area"
            >
                <input
                    ref={fileInputRef}
                    type="file"
                    className="hidden"
                    onChange={handleChange}
                    accept={validTypes.join(',')}
                    aria-label="Upload document"
                    data-testid="file-input"
                />
                <svg
                    className="w-12 h-12 mx-auto text-gray-400 dark:text-gray-500"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                >
                    <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                        d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
                    />
                </svg>
                <p className="mt-2 text-base text-gray-700 dark:text-gray-300">
                    Drag and drop your document here, or{' '}
                    <button
                        type="button"
                        className="text-blue-600 hover:underline focus:outline-none focus:ring-2 focus:ring-blue-500"
                        onClick={handleButtonClick}
                        data-testid="browse-button"
                    >
                        click to browse
                    </button>
                </p>
                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                    Supports multiple file types (max 10MB)
                </p>
                <div className="mt-4 flex flex-wrap justify-center gap-2">
                    {supportedFileTypes.map((type, index) => (
                        <span
                            key={index}
                            className="px-2 py-1 bg-gray-100 dark:bg-gray-800 rounded text-xs flex items-center"
                            data-testid={`file-type-${type.name}`}
                        >
                            <span className="mr-1">{type.icon}</span>
                            {type.name}
                        </span>
                    ))}
                </div>
            </div>
            {fileError && (
                <p
                    className="mt-2 text-sm text-red-600 dark:text-red-400"
                    data-testid="file-error"
                >
                    {fileError}
                </p>
            )}
            {status.message && (
                <p
                    className="mt-2 text-sm text-gray-600 dark:text-gray-400"
                    data-testid="upload-status"
                >
                    {status.message}
                </p>
            )}
        </div>
    );
};

FileUpload.propTypes = {
    handleFileUpload: PropTypes.func,
    status: PropTypes.shape({
        type: PropTypes.string,
        message: PropTypes.string,
    }),
    supportedFileTypes: PropTypes.arrayOf(
        PropTypes.shape({
            mime_type: PropTypes.string.isRequired,
            name: PropTypes.string.isRequired,
            icon: PropTypes.string.isRequired,
        })
    ),
};

export default FileUpload;