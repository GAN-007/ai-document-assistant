import React, { useContext } from 'react';
import PropTypes from 'prop-types';
import { DocumentContext } from '../context/DocumentContext';

/**
 * SettingsPanel component for customizing application settings.
 */
const SettingsPanel = () => {
    const {
        settings,
        updateSettings,
        colorGradients,
        setColorGradient,
        colorGradient,
        modelInfo,
    } = useContext(DocumentContext);

    // Handle toggle settings
    const handleToggle = (key) => {
        updateSettings({ [key]: !settings[key] });
    };

    // Handle export format change
    const handleExportFormatChange = (e) => {
        updateSettings({ exportFormat: e.target.value });
    };

    // Handle gradient change
    const handleGradientChange = (gradient) => {
        setColorGradient(gradient);
    };

    return (
        <div
            className="mt-8 bg-white dark:bg-gray-800 p-6 rounded-lg shadow animate-slide-in-bottom"
            data-testid="settings-panel"
        >
            <h2 className="text-xl font-semibold mb-4">Settings</h2>
            <div className="space-y-4">
                {/* Dark Mode */}
                <div className="flex items-center justify-between">
                    <label htmlFor="darkMode" className="text-gray-700 dark:text-gray-300">
                        Dark Mode
                    </label>
                    <input
                        type="checkbox"
                        id="darkMode"
                        checked={settings.darkMode}
                        onChange={() => handleToggle('darkMode')}
                        className="toggle-checkbox"
                        data-testid="dark-mode-toggle"
                    />
                </div>
                {/* Auto Save */}
                <div className="flex items-center justify-between">
                    <label htmlFor="autoSave" className="text-gray-700 dark:text-gray-300">
                        Auto Save
                    </label>
                    <input
                        type="checkbox"
                        id="autoSave"
                        checked={settings.autoSave}
                        onChange={() => handleToggle('autoSave')}
                        className="toggle-checkbox"
                        data-testid="auto-save-toggle"
                    />
                </div>
                {/* Notifications */}
                <div className="flex items-center justify-between">
                    <label htmlFor="notifications" className="text-gray-700 dark:text-gray-300">
                        Notifications
                    </label>
                    <input
                        type="checkbox"
                        id="notifications"
                        checked={settings.notifications}
                        onChange={() => handleToggle('notifications')}
                        className="toggle-checkbox"
                        data-testid="notifications-toggle"
                    />
                </div>
                {/* Export Format */}
                <div>
                    <label htmlFor="exportFormat" className="block text-gray-700 dark:text-gray-300 mb-1">
                        Export Format
                    </label>
                    <select
                        id="exportFormat"
                        value={settings.exportFormat}
                        onChange={handleExportFormatChange}
                        className="w-full p-2 border rounded dark:bg-gray-700 dark:border-gray-600 dark:text-gray-300"
                        data-testid="export-format-select"
                    >
                        <option value="txt">Text (.txt)</option>
                        <option value="pdf">PDF (.pdf)</option>
                        <option value="docx">Word (.docx)</option>
                    </select>
                </div>
                {/* Color Gradient */}
                <div>
                    <label className="block text-gray-700 dark:text-gray-300 mb-1">
                        Color Gradient
                    </label>
                    <div className="flex space-x-2">
                        {colorGradients.map((gradient) => (
                            <button
                                key={gradient.id}
                                className={`w-12 h-12 rounded ${gradient.class} ${
                                    colorGradient.id === gradient.id ? 'ring-2 ring-blue-500' : ''
                                }`}
                                onClick={() => handleGradientChange(gradient)}
                                title={gradient.name}
                                data-testid={`gradient-${gradient.id}`}
                            />
                        ))}
                    </div>
                </div>
                {/* Model Info */}
                {modelInfo && (
                    <div>
                        <h3 className="text-lg font-medium mb-2">Model Information</h3>
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                            <strong>Name:</strong> {modelInfo.name}
                        </p>
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                            <strong>Version:</strong> {modelInfo.version}
                        </p>
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                            <strong>Description:</strong> {modelInfo.description}
                        </p>
                    </div>
                )}
            </div>
        </div>
    );
};

SettingsPanel.propTypes = {
    settings: PropTypes.shape({
        darkMode: PropTypes.bool,
        autoSave: PropTypes.bool,
        notifications: PropTypes.bool,
        exportFormat: PropTypes.string,
    }),
    updateSettings: PropTypes.func,
    colorGradients: PropTypes.arrayOf(
        PropTypes.shape({
            id: PropTypes.number,
            name: PropTypes.string,
            start: PropTypes.string,
            end: PropTypes.string,
            class: PropTypes.string,
        })
    ),
    setColorGradient: PropTypes.func,
    colorGradient: PropTypes.shape({
        id: PropTypes.number,
        name: PropTypes.string,
        start: PropTypes.string,
        end: PropTypes.string,
        class: PropTypes.string,
    }),
    modelInfo: PropTypes.shape({
        name: PropTypes.string,
        version: PropTypes.string,
        description: PropTypes.string,
    }),
};

export default SettingsPanel;