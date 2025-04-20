import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import DocumentViewer from '../components/DocumentViewer';
import { DocumentContext } from '../context/DocumentContext';

const mockHandleSuggestion = jest.fn();
const mockSaveDocument = jest.fn();
const mockExportDocument = jest.fn();
const mockUndo = jest.fn();
const mockRedo = jest.fn();
const mockOriginalText = 'This is the original text.';
const mockImprovedText = 'This is teh improved text.';
const mockSuggestions = [
    {
        id: 1,
        start: 8,
        end: 11,
        original_text: 'teh',
        improved_text: 'the',
        reason: 'Corrected typo',
        status: 'pending',
    },
];
const mockFile = new File(['test content'], 'test.txt', { type: 'text/plain' });
const mockHistory = { past: [], future: [] };

const renderWithContext = (component, value = {}) => {
    const defaultValue = {
        originalText: mockOriginalText,
        improvedText: mockImprovedText,
        suggestions: mockSuggestions,
        handleSuggestion: mockHandleSuggestion,
        file: mockFile,
        saveDocument: mockSaveDocument,
        exportDocument: mockExportDocument,
        undo: mockUndo,
        redo: mockRedo,
        history: mockHistory,
        ...value,
    };
    return render(
        <DocumentContext.Provider value={defaultValue}>
            {component}
        </DocumentContext.Provider>
    );
};

describe('DocumentViewer Component', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('renders original and improved text', () => {
        renderWithContext(<DocumentViewer />);
        expect(screen.getByTestId('original-text')).toHaveTextContent(mockOriginalText);
        expect(screen.getByTestId('improved-text')).toHaveTextContent(mockImprovedText);
    });

    it('renders suggestions with highlights', () => {
        renderWithContext(<DocumentViewer />);
        const suggestionElement = screen.getByTestId('suggestion-1');
        expect(suggestionElement).toHaveTextContent('the');
        expect(suggestionElement).toHaveClass('bg-yellow-200');
    });

    it('displays suggestion tooltip on click', () => {
        renderWithContext(<DocumentViewer />);
        const suggestionElement = screen.getByTestId('suggestion-1');
        fireEvent.click(suggestionElement);
        expect(screen.getByRole('dialog')).toHaveTextContent('Corrected typo');
    });

    it('handles accept suggestion', async () => {
        renderWithContext(<DocumentViewer />);
        const suggestionElement = screen.getByTestId('suggestion-1');
        fireEvent.click(suggestionElement);
        const acceptButton = screen.getByTestId('accept-suggestion-1');
        fireEvent.click(acceptButton);
        await waitFor(() => {
            expect(mockHandleSuggestion).toHaveBeenCalledWith(1, 'accepted');
        });
    });

    it('handles reject suggestion', async () => {
        renderWithContext(<DocumentViewer />);
        const suggestionElement = screen.getByTestId('suggestion-1');
        fireEvent.click(suggestionElement);
        const rejectButton = screen.getByTestId('reject-suggestion-1');
        fireEvent.click(rejectButton);
        await waitFor(() => {
            expect(mockHandleSuggestion).toHaveBeenCalledWith(1, 'rejected');
        });
    });

    it('handles save document', () => {
        renderWithContext(<DocumentViewer />);
        const saveButton = screen.getByTestId('save-button');
        fireEvent.click(saveButton);
        expect(mockSaveDocument).toHaveBeenCalled();
    });

    it('handles export document', () => {
        renderWithContext(<DocumentViewer />);
        const exportButton = screen.getByTestId('export-button');
        fireEvent.click(exportButton);
        expect(mockExportDocument).toHaveBeenCalled();
    });

    it('handles undo and redo', () => {
        renderWithContext(<DocumentViewer />, {
            history: { past: [{}], future: [{}] },
        });
        const undoButton = screen.getByTestId('undo-button');
        const redoButton = screen.getByTestId('redo-button');
        fireEvent.click(undoButton);
        expect(mockUndo).toHaveBeenCalled();
        fireEvent.click(redoButton);
        expect(mockRedo).toHaveBeenCalled();
    });
});