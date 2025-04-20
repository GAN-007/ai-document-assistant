import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import SettingsPanel from '../components/SettingsPanel';
import { DocumentContext } from '../context/DocumentContext';

const mockUpdateSettings = jest.fn();
const mockSetColorGradient = jest.fn();
const mockSettings = {
    darkMode: false,
    autoSave: true,
    notifications: true,
    exportFormat: 'txt',
};
const mockColorGradients = [
    { id: 1, name: 'Blue', start: '#4567b7', end: '#6495ed', class: 'gradient-blue' },
];
const mockColorGradient = mockColorGradients[0];
const mockModelInfo = {
    name: 'AI Document Enhancer',
    version: '1.0.0',
    description: 'AI model for document improvement.',
};

const renderWithContext = (component, value = {}) => {
    const defaultValue = {
        settings: mockSettings,
        updateSettings: mockUpdateSettings,
        colorGradients: mockColorGradients,
        setColorGradient: mockSetColorGradient,
        colorGradient: mockColorGradient,
        modelInfo: mockModelInfo,
        ...value,
    };
    return render(
        <DocumentContext.Provider value={defaultValue}>
            {component}
        </DocumentContext.Provider>
    );
};

describe('SettingsPanel Component', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('renders all settings options', () => {
        renderWithContext(<SettingsPanel />);
        expect(screen.getByTestId('dark-mode-toggle')).toBeInTheDocument();
        expect(screen.getByTestId('auto-save-toggle')).toBeChecked();
        expect(screen.getByTestId('notifications-toggle')).toBeChecked();
        expect(screen.getByTestId('export-format-select')).toHaveValue('txt');
        expect(screen.getByTestId('gradient-1')).toBeInTheDocument();
        expect(screen.getByText('Model Information')).toBeInTheDocument();
    });

    it('toggles dark mode', () => {
        renderWithContext(<SettingsPanel />);
        const toggle = screen.getByTestId('dark-mode-toggle');
        fireEvent.click(toggle);
        expect(mockUpdateSettings).toHaveBeenCalledWith({ darkMode: true });
    });

    it('changes export format', () => {
        renderWithContext(<SettingsPanel />);
        const select = screen.getByTestId('export-format-select');
        fireEvent.change(select, { target: { value: 'pdf' } });
        expect(mockUpdateSettings).toHaveBeenCalledWith({ exportFormat: 'pdf' });
    });

    it('changes color gradient', () => {
        renderWithContext(<SettingsPanel />);
        const gradientButton = screen.getByTestId('gradient-1');
        fireEvent.click(gradientButton);
        expect(mockSetColorGradient).toHaveBeenCalledWith(mockColorGradient);
    });
});