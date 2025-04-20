import React, { useContext } from 'react';
import PropTypes from 'prop-types';
import { DocumentContext } from '../context/DocumentContext';

/**
 * StatusNotification component for displaying status messages.
 */
const StatusNotification = () => {
    const { status } = useContext(DocumentContext);

    if (!status.message) return null;

    const statusStyles = {
        success: 'bg-green-100 text-green-800 border-green-300',
        error: 'bg-red-100 text-red-800 border-red-300',
        loading: 'bg-blue-100 text-blue-800 border-blue-300 flex items-center',
    };

    return (
        <div
            className={`
                mt-4 p-4 rounded-lg border
                ${statusStyles[status.type] || 'bg-gray-100 text-gray-800 border-gray-300'}
                animate-slide-in-bottom
            `}
            role="alert"
            data-testid="status-notification"
        >
            {status.type === 'loading' && (
                <span className="loading-spinner inline-block mr-2" aria-hidden="true"></span>
            )}
            {status.message}
        </div>
    );
};

StatusNotification.propTypes = {
    status: PropTypes.shape({
        type: PropTypes.string,
        message: PropTypes.string,
    }),
};

export default StatusNotification;