import React, { useState, useCallback, useMemo, useEffect } from 'react';
import PropTypes from 'prop-types';
import { DocumentContext } from '../context/DocumentContext';

/**
 * DocumentViewer component for displaying original and improved documents with suggestions.
 */
const DocumentViewer = () => {
    const {
        originalText,
        improvedText,
        suggestions,
        handleSuggestion,
        file,
        saveDocument,
        exportDocument,
        undo,
        redo,
        history
    } = React.useContext(DocumentContext);
    const [activeSuggestion, setActiveSuggestion] = useState(null);

    // Memoize sorted suggestions for performance
    const sortedSuggestions = useMemo(() => {
        return [...suggestions].sort((a, b) => a.start - b.start);
    }, [suggestions]);

    // Render improved text with highlighted suggestions
    const renderImprovedTextWithHighlights = useCallback(() => {
        if (!improvedText) return null;
        let result = [];
        let lastIndex = 0;
        for (const suggestion of sortedSuggestions) {
            if (suggestion.start > lastIndex) {
                result.push(improvedText.substring(lastIndex, suggestion.start));
            }
            const highlightClass = {
                accepted: 'bg-green-200 dark:bg-green-800',
                rejected: 'bg-red-200 dark:bg-red-800',
                pending: 'bg-yellow-200 dark:bg-yellow-700 cursor-pointer',
            }[suggestion.status] || '';
            result.push(
                <span
                    key={suggestion.id}
                    className={`suggestion px-0.5 rounded ${highlightClass}`}
                    onClick={() =>
                        suggestion.status === 'pending' &&
                        setActiveSuggestion(activeSuggestion === suggestion.id ? null : suggestion.id)
                    }
                    role="button"
                    tabIndex={0}
                    aria-label={`Suggestion: ${suggestion.reason}`}
                    data-testid={`suggestion-${suggestion.id}`}
                >
                    {improvedText.substring(suggestion.start, suggestion.end)}
                    {activeSuggestion === suggestion.id && suggestion.status === 'pending' && (
                        <div
                            className="suggestion-tooltip absolute z-10 bg-white dark:bg-gray-800 shadow-lg rounded-md p-3 mt-1 border border-gray-200 dark:border-gray-700 text-sm fade-in"
                            role="dialog"
                            aria-labelledby={`suggestion-${suggestion.id}-title`}
                        >
                            <p id={`suggestion-${suggestion.id}-title`} className="font-medium mb-1">
                                Suggestion:
                            </p>
                            <p className="mb-2">{suggestion.reason}</p>
                            <div className="flex space-x-2">
                                <button
                                    className="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700 transition-colors"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        handleSuggestion(suggestion.id, 'accepted');
                                        setActiveSuggestion(null);
                                    }}
                                    data-testid={`accept-suggestion-${suggestion.id}`}
                                >
                                    Accept
                                </button>
                                <button
                                    className="px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        handleSuggestion(suggestion.id, 'rejected');
                                        setActiveSuggestion(null);
                                    }}
                                    data-testid={`reject-suggestion-${suggestion.id}`}
                                >
                                    Reject
                                </button>
                            </div>
                        </div>
                    )}
                </span>
            );
            lastIndex = suggestion.end;
        }
        if (lastIndex < improvedText.length) {
            result.push(improvedText.substring(lastIndex));
        }
        return result;
    }, [improvedText, sortedSuggestions, activeSuggestion, handleSuggestion]);

    // Close tooltip when clicking outside
    useEffect(() => {
        const handleClickOutside = (event) => {
            if (!event.target.closest('.suggestion-tooltip') && !event.target.closest('.suggestion')) {
                setActiveSuggestion(null);
            }
        };
        document.addEventListener('click', handleClickOutside);
        return () => document.removeEventListener('click', handleClickOutside);
    }, []);

    // Handle keyboard navigation for suggestions
    const handleKeyDown = useCallback((e, suggestionId) => {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            setActiveSuggestion(activeSuggestion === suggestionId ? null : suggestionId);
        }
    }, [activeSuggestion]);

    return (
        <div className="mt-8 animate-slide-in-bottom">
            <div className="flex justify-between items-center mb-4">
                <h2 className="text-2xl font-semibold">Document Viewer</h2>
                <div className="flex space-x-2">
                    <button
                        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors disabled:opacity-50"
                        onClick={undo}
                        disabled={history.past.length === 0}
                        data-testid="undo-button"
                    >
                        Undo
                    </button>
                    <button
                        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors disabled:opacity-50"
                        onClick={redo}
                        disabled={history.future.length === 0}
                        data-testid="redo-button"
                    >
                        Redo
                    </button>
                    <button
                        className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors"
                        onClick={saveDocument}
                        data-testid="save-button"
                    >
                        Save
                    </button>
                    <button
                        className="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 transition-colors"
                        onClick={exportDocument}
                        data-testid="export-button"
                    >
                        Export
                    </button>
                </div>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Original Text */}
                <div className="bg-white dark:bg-gray-800 p-4 rounded-lg shadow">
                    <h3 className="text-lg font-medium mb-2">Original Document</h3>
                    <div
                        className="document-text h-96 overflow-auto p-4 bg-gray-50 dark:bg-gray-900 rounded"
                        data-testid="original-text"
                    >
                        {originalText || 'No content available.'}
                    </div>
                </div>
                {/* Improved Text with Suggestions */}
                <div className="bg-white dark:bg-gray-800 p-4 rounded-lg shadow relative">
                    <h3 className="text-lg font-medium mb-2">Improved Document</h3>
                    <div
                        className="document-text h-96 overflow-auto p-4 bg-gray-50 dark:bg-gray-900 rounded"
                        data-testid="improved-text"
                    >
                        {renderImprovedTextWithHighlights() || 'No content available.'}
                    </div>
                </div>
            </div>
            {/* File Information */}
            {file && (
                <div className="mt-4 text-sm text-gray-600 dark:text-gray-400">
                    <p>File: {file.name}</p>
                    <p>Size: {(file.size / 1024).toFixed(2)} KB</p>
                    <p>Type: {file.type}</p>
                </div>
            )}
        </div>
    );
};

DocumentViewer.propTypes = {
    originalText: PropTypes.string,
    improvedText: PropTypes.string,
    suggestions: PropTypes.arrayOf(
        PropTypes.shape({
            id: PropTypes.number.isRequired,
            start: PropTypes.number.isRequired,
            end: PropTypes.number.isRequired,
            original_text: PropTypes.string.isRequired,
            improved_text: PropTypes.string.isRequired,
            reason: PropTypes.string.isRequired,
            status: PropTypes.string.isRequired,
        })
    ),
    handleSuggestion: PropTypes.func,
    file: PropTypes.instanceOf(File),
    saveDocument: PropTypes.func,
    exportDocument: PropTypes.func,
    undo: PropTypes.func,
    redo: PropTypes.func,
    history: PropTypes.shape({
        past: PropTypes.array,
        future: PropTypes.array,
    }),
};

export default DocumentViewer;