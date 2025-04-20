import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import FileUpload from '../components/FileUpload';
import { DocumentContext } from '../context/DocumentContext';

const mockHandleFileUpload = jest.fn();
const mockSupportedFileTypes = [
    { mime_type: 'text/plain', name: 'TXT', icon: '📝' },
    { mime_type: 'application/pdf', name: 'PDF', icon: '📄' },
];
const mockStatus = { type: 'idle', message: '' };

const renderWithContext = (component, value = {}) => {
    const defaultValue = {
        handleFileUpload: mockHandleFileUpload,
        supportedFileTypes: mockSupportedFileTypes,
        status: mockStatus,
        ...value,
    };
    return render(
        <DocumentContext.Provider value={defaultValue}>
            {component}
        </DocumentContext.Provider>
    );
};

describe('FileUpload Component', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('renders drag-and-drop area and supported file types', () => {
        renderWithContext(<FileUpload />);
        expect(screen.getByTestId('drag-drop-area')).toBeInTheDocument();
        expect(screen.getByTestId('file-type-TXT')).toHaveTextContent('📝 TXT');
        expect(screen.getByTestId('file-type-PDF')).toHaveTextContent('📄 PDF');
    });

    it('handles file input change with valid file', async () => {
        renderWithContext(<FileUpload />);
        const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
        const input = screen.getByTestId('file-input');
        fireEvent.change(input, { target: { files: [file] } });
        await waitFor(() => {
            expect(mockHandleFileUpload).toHaveBeenCalledWith(file);
        });
    });

    it('displays error for unsupported file type', async () => {
        renderWithContext(<FileUpload />);
        const file = new File(['test content'], 'test.jpg', { type: 'image/jpeg' });
        const input = screen.getByTestId('file-input');
        fireEvent.change(input, { target: { files: [file] } });
        await waitFor(() => {
            expect(screen.getByTestId('file-error')).toHaveTextContent('Invalid file type');
        });
    });

    it('displays error for file too large', async () => {
        renderWithContext(<FileUpload />);
        const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
        Object.defineProperty(file, 'size', { value: 15 * 1024 * 1024 }); // 15MB
        const input = screen.getByTestId('file-input');
        fireEvent.change(input, { target: { files: [file] } });
        await waitFor(() => {
            expect(screen.getByTestId('file-error')).toHaveTextContent('File is too large');
        });
    });

    it('handles drag and drop', async () => {
        renderWithContext(<FileUpload />);
        const file = new File(['test content'], 'test.txt', { type: 'text/plain' });
        const area = screen.getByTestId('drag-drop-area');
        fireEvent.dragEnter(area);
        fireEvent.drop(area, { dataTransfer: { files: [file] } });
        await waitFor(() => {
            expect(mockHandleFileUpload).toHaveBeenCalledWith(file);
        });
    });

    it('triggers file input on button click', () => {
        renderWithContext(<FileUpload />);
        const button = screen.getByTestId('browse-button');
        const input = screen.getByTestId('file-input');
        const clickSpy = jest.spyOn(input, 'click');
        fireEvent.click(button);
        expect(clickSpy).toHaveBeenCalled();
    });
});