import React from 'react';
import { render, screen } from '@testing-library/react';
import StatusNotification from '../components/StatusNotification';
import { DocumentContext } from '../context/DocumentContext';

const renderWithContext = (component, value = {}) => {
    const defaultValue = {
        status: { type: 'idle', message: '' },
        ...value,
    };
    return render(
        <DocumentContext.Provider value={defaultValue}>
            {component}
        </DocumentContext.Provider>
    );
};

describe('StatusNotification Component', () => {
    it('does not render when no message', () => {
        renderWithContext(<StatusNotification />);
        expect(screen.queryByTestId('status-notification')).not.toBeInTheDocument();
    });

    it('renders success message', () => {
        renderWithContext(<StatusNotification />, {
            status: { type: 'success', message: 'Success!' },
        });
        const notification = screen.getByTestId('status-notification');
        expect(notification).toHaveTextContent('Success!');
        expect(notification).toHaveClass('bg-green-100');
    });

    it('renders error message', () => {
        renderWithContext(<StatusNotification />, {
            status: { type: 'error', message: 'Error occurred.' },
        });
        const notification = screen.getByTestId('status-notification');
        expect(notification).toHaveTextContent('Error occurred.');
        expect(notification).toHaveClass('bg-red-100');
    });

    it('renders loading message with spinner', () => {
        renderWithContext(<StatusNotification />, {
            status: { type: 'loading', message: 'Loading...' },
        });
        const notification = screen.getByTestId('status-notification');
        expect(notification).toHaveTextContent('Loading...');
        expect(notification).toHaveClass('bg-blue-100');
        expect(screen.getByRole('alert').querySelector('.loading-spinner')).toBeInTheDocument();
    });
});