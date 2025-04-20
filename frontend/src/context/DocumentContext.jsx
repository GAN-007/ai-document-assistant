import React, { createContext, useReducer, useEffect, useCallback, useMemo } from 'react';
import axios from 'axios';
import JSZip from 'jszip';
import { debounce } from 'lodash';
import { saveAs } from 'file-saver';
import PropTypes from 'prop-types';

// Lazy-load heavy dependencies for performance
const PDFDocument = React.lazy(() => import('pdf-lib').then(module => ({ default: module.PDFDocument })));
const mammoth = React.lazy(() => import('mammoth'));
const XLSX = React.lazy(() => import('xlsx'));

// Create DocumentContext for state management
export const DocumentContext = createContext();

// Initial state for the context
const initialState = {
    file: null,
    originalText: '',
    improvedText: '',
    suggestions: [],
    status: { type: 'idle', message: '' },
    colorGradient: {
        id: 1,
        name: 'Blue',
        start: '#4567b7',
        end: '#6495ed',
        class: 'gradient-blue',
    },
    user: null,
    settings: {
        darkMode: window.matchMedia('(prefers-color-scheme: dark)').matches,
        autoSave: true,
        notifications: true,
        exportFormat: 'txt',
    },
    history: { past: [], future: [] },
    supportedFileTypes: [],
    modelInfo: null,
};

// Reducer to manage state updates
const documentReducer = (state, action) => {
    switch (action.type) {
        case 'SET_FILE':
            return { ...state, file: action.payload, history: { past: [], future: [] } };
        case 'SET_TEXT':
            return {
                ...state,
                originalText: action.payload.original,
                improvedText: action.payload.improved,
                suggestions: action.payload.suggestions,
            };
        case 'SET_STATUS':
            return { ...state, status: action.payload };
        case 'SET_COLOR_GRADIENT':
            return { ...state, colorGradient: action.payload };
        case 'SET_USER':
            return { ...state, user: action.payload };
        case 'SET_SETTINGS':
            return { ...state, settings: { ...state.settings, ...action.payload } };
        case 'APPLY_SUGGESTION':
            const { id, action: suggestionAction } = action.payload;
            const suggestion = state.suggestions.find(s => s.id === id);
            if (!suggestion) return state;
            const newSuggestions = state.suggestions.map(s =>
                s.id === id ? { ...s, status: suggestionAction } : s
            );
            let newImprovedText = state.improvedText;
            if (suggestionAction === 'accepted') {
                newImprovedText = newImprovedText.replace(suggestion.original_text, suggestion.improved_text);
            } else if (suggestionAction === 'rejected') {
                newImprovedText = newImprovedText.replace(suggestion.improved_text, suggestion.original_text);
            }
            return {
                ...state,
                improvedText: newImprovedText,
                suggestions: newSuggestions,
                history: {
                    past: [...state.history.past, { improvedText: state.improvedText, suggestions: state.suggestions }],
                    future: [],
                },
            };
        case 'UNDO':
            if (state.history.past.length === 0) return state;
            const lastState = state.history.past[state.history.past.length - 1];
            return {
                ...state,
                improvedText: lastState.improvedText,
                suggestions: lastState.suggestions,
                history: {
                    past: state.history.past.slice(0, -1),
                    future: [...state.history.future, { improvedText: state.improvedText, suggestions: state.suggestions }],
                },
            };
        case 'REDO':
            if (state.history.future.length === 0) return state;
            const nextState = state.history.future[state.history.future.length - 1];
            return {
                ...state,
                improvedText: nextState.improvedText,
                suggestions: nextState.suggestions,
                history: {
                    past: [...state.history.past, { improvedText: state.improvedText, suggestions: state.suggestions }],
                    future: state.history.future.slice(0, -1),
                },
            };
        case 'SET_FILE_TYPES':
            return { ...state, supportedFileTypes: action.payload };
        case 'SET_MODEL_INFO':
            return { ...state, modelInfo: action.payload };
        case 'RESET_DOCUMENT':
            return {
                ...state,
                file: null,
                originalText: '',
                improvedText: '',
                suggestions: [],
                status: { type: 'idle', message: '' },
                history: { past: [], future: [] },
            };
        default:
            return state;
    }
};

// DocumentProvider component to wrap the app
export const DocumentProvider = ({ children }) => {
    const [state, dispatch] = useReducer(documentReducer, initialState);

    // Define color gradients for UI customization
    const colorGradients = useMemo(() => [
        { id: 1, name: 'Blue', start: '#4567b7', end: '#6495ed', class: 'gradient-blue' },
        { id: 2, name: 'Green', start: '#34c759', end: '#8bc34a', class: 'gradient-green' },
        { id: 3, name: 'Red', start: '#ff9800', end: '#e51c23', class: 'gradient-red' },
        { id: 4, name: 'Purple', start: '#9c27b0', end: '#673ab7', class: 'gradient-purple' },
        { id: 5, name: 'Teal', start: '#009688', end: '#4db6ac', class: 'gradient-teal' },
    ], []);

    // Axios instance with retry logic and token handling
    const axiosInstance = useMemo(() => {
        const instance = axios.create({
            baseURL: 'http://localhost:8000/api',
            timeout: 10000,
        });
        instance.interceptors.request.use(config => {
            const token = localStorage.getItem('token');
            if (token) {
                config.headers.Authorization = `Bearer ${token}`;
            }
            return config;
        });
        instance.interceptors.response.use(
            response => response,
            async error => {
                const { config: originalRequest, response } = error;
                if (response?.status === 401 && !originalRequest._retry) {
                    originalRequest._retry = true;
                    localStorage.removeItem('token');
                    dispatch({ type: 'SET_USER', payload: null });
                    dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: 'Session expired. Please log in again.' } });
                }
                return Promise.reject(error);
            }
        );
        return instance;
    }, []);

    // Fetch supported file types and model info on mount
    useEffect(() => {
        const fetchConfig = async () => {
            try {
                const [fileTypesResponse, modelInfoResponse] = await Promise.all([
                    axiosInstance.get('/config/file-types'),
                    axiosInstance.get('/model-info'),
                ]);
                dispatch({ type: 'SET_FILE_TYPES', payload: fileTypesResponse.data });
                dispatch({ type: 'SET_MODEL_INFO', payload: modelInfoResponse.data });
            } catch (error) {
                console.error('Failed to fetch config:', error);
                dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: 'Failed to load configuration' } });
            }
        };
        fetchConfig();
    }, [axiosInstance]);

    // Validate stored token on mount
    useEffect(() => {
        const token = localStorage.getItem('token');
        if (token) {
            axiosInstance.post('/validate-token', { token })
                .then(response => dispatch({ type: 'SET_USER', payload: response.data }))
                .catch(() => {
                    localStorage.removeItem('token');
                    dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: 'Session expired. Please log in again.' } });
                });
        }
    }, [axiosInstance]);

    // Load and apply saved settings
    useEffect(() => {
        const savedSettings = JSON.parse(localStorage.getItem('settings') || '{}');
        dispatch({ type: 'SET_SETTINGS', payload: savedSettings });
        document.documentElement.classList.toggle('dark', savedSettings.darkMode || state.settings.darkMode);
    }, []);

    // Handle file upload
    const handleFileUpload = useCallback(async (file) => {
        if (!state.supportedFileTypes.some(ft => ft.mime_type === file.type)) {
            dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: 'Unsupported file type' } });
            return;
        }
        dispatch({ type: 'SET_FILE', payload: file });
        dispatch({ type: 'SET_STATUS', payload: { type: 'loading', message: 'Processing document...' } });
        try {
            const formData = new FormData();
            formData.append('file', file);
            const response = await axiosInstance.post('/upload', formData, {
                headers: { 'Content-Type': 'multipart/form-data' },
            });
            dispatch({
                type: 'SET_TEXT',
                payload: {
                    original: response.data.originalText,
                    improved: response.data.improvedText,
                    suggestions: response.data.suggestions,
                },
            });
            dispatch({ type: 'SET_STATUS', payload: { type: 'success', message: 'Document processed successfully!' } });
            if (state.settings.autoSave) await saveDocument();
        } catch (error) {
            dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: `Error processing document: ${error.message}` } });
            console.error(error);
        }
    }, [state.supportedFileTypes, state.settings.autoSave, axiosInstance]);

    // Process file locally for preview or fallback
    const processFile = useCallback(async (file) => {
        try {
            if (file.type === 'application/pdf') {
                const pdfDoc = await PDFDocument.load(await file.arrayBuffer());
                const pdfText = await pdfDoc.getTextContent();
                return pdfText.items.map(item => item.str).join(' ');
            } else if (file.type === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
                const result = await mammoth.convertToHtml({ arrayBuffer: await file.arrayBuffer() });
                return result.value.replace(/<[^>]+>/g, '');
            } else if (file.type === 'text/plain' || file.type === 'text/csv' || file.type === 'application/sql') {
                return await file.text();
            } else if (file.type === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
                const arrayBuffer = await file.arrayBuffer();
                const workbook = XLSX.read(arrayBuffer, { type: 'array' });
                const sheetName = workbook.SheetNames[0];
                const sheet = workbook.Sheets[sheetName];
                return XLSX.utils.sheet_to_csv(sheet);
            } else if (file.type === 'application/zip' || file.type === 'application/x-rar-compressed') {
                const zip = new JSZip();
                const zipContent = await zip.loadAsync(await file.arrayBuffer());
                const firstTextFile = Object.values(zipContent.files).find(f =>
                    f.name.endsWith('.txt') || f.name.endsWith('.csv') || f.name.endsWith('.sql')
                );
                if (firstTextFile) return await firstTextFile.async('string');
                return 'No text-based file found in archive.';
            } else if (file.type.startsWith('image/') || file.type.startsWith('audio/') || file.type.startsWith('video/')) {
                return `Media file: ${file.name} (Processed by backend)`;
            }
            throw new Error('Unsupported file type');
        } catch (error) {
            throw new Error(`File processing failed: ${error.message}`);
        }
    }, []);

    // Handle suggestion actions
    const handleSuggestion = useCallback((id, action) => {
        dispatch({ type: 'APPLY_SUGGESTION', payload: { id, action } });
        if (state.settings.autoSave) saveDocument();
    }, [state.settings.autoSave]);

    // Undo/redo actions
    const undo = useCallback(() => {
        dispatch({ type: 'UNDO' });
    }, []);

    const redo = useCallback(() => {
        dispatch({ type: 'REDO' });
    }, []);

    // Reset document state
    const resetDocument = useCallback(() => {
        dispatch({ type: 'RESET_DOCUMENT' });
    }, []);

    // Save document (debounced to prevent excessive API calls)
    const saveDocument = useCallback(debounce(async () => {
        if (!state.user) {
            dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: 'Please log in to save documents' } });
            return;
        }
        dispatch({ type: 'SET_STATUS', payload: { type: 'loading', message: 'Saving document...' } });
        try {
            await axiosInstance.post('/save', {
                text: state.improvedText,
                filename: state.file?.name || 'unnamed_document',
            });
            dispatch({ type: 'SET_STATUS', payload: { type: 'success', message: 'Document saved successfully!' } });
            setTimeout(() => dispatch({ type: 'SET_STATUS', payload: { type: 'idle', message: '' } }), 3000);
        } catch (error) {
            dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: `Error saving document: ${error.message}` } });
        }
    }, 1000), [state.user, state.improvedText, state.file, axiosInstance]);

    // Export document in selected format
    const exportDocument = useCallback(async () => {
        try {
            const format = state.settings.exportFormat;
            let blob;
            if (format === 'txt') {
                blob = new Blob([state.improvedText], { type: 'text/plain' });
            } else if (format === 'pdf') {
                const pdfDoc = await PDFDocument.create();
                const page = pdfDoc.addPage();
                const { width, height } = page.getSize();
                page.drawText(state.improvedText, { x: 50, y: height - 50, size: 12 });
                const pdfBytes = await pdfDoc.save();
                blob = new Blob([pdfBytes], { type: 'application/pdf' });
            } else if (format === 'docx') {
                const { default: docx } = await import('docx');
                const doc = new docx.Document({
                    sections: [{ properties: {}, children: [new docx.Paragraph(state.improvedText)] }],
                });
                const buffer = await docx.Packer.toBlob(doc);
                blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' });
            }
            saveAs(blob, `${state.file?.name.split('.')[0] || 'document'}.${format}`);
            dispatch({ type: 'SET_STATUS', payload: { type: 'success', message: 'Document exported!' } });
            setTimeout(() => dispatch({ type: 'SET_STATUS', payload: { type: 'idle', message: '' } }), 3000);
        } catch (error) {
            dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: `Export failed: ${error.message}` } });
        }
    }, [state.improvedText, state.file, state.settings.exportFormat]);

    // Login function
    const login = useCallback(async (credentials) => {
        dispatch({ type: 'SET_STATUS', payload: { type: 'loading', message: 'Logging in...' } });
        try {
            const response = await axiosInstance.post('/login', credentials);
            dispatch({ type: 'SET_USER', payload: response.data.user });
            localStorage.setItem('token', response.data.access_token);
            dispatch({ type: 'SET_STATUS', payload: { type: 'success', message: 'Logged in successfully!' } });
            setTimeout(() => dispatch({ type: 'SET_STATUS', payload: { type: 'idle', message: '' } }), 3000);
            return true;
        } catch (error) {
            dispatch({ type: 'SET_STATUS', payload: { type: 'error', message: 'Login failed: Invalid credentials' } });
            return false;
        }
    }, [axiosInstance]);

    // Logout function
    const logout = useCallback(() => {
        dispatch({ type: 'SET_USER', payload: null });
        localStorage.removeItem('token');
        dispatch({ type: 'SET_STATUS', payload: { type: 'success', message: 'Logged out successfully!' } });
        setTimeout(() => dispatch({ type: 'SET_STATUS', payload: { type: 'idle', message: '' } }), 3000);
    }, []);

    // Update settings
    const updateSettings = useCallback((newSettings) => {
        dispatch({ type: 'SET_SETTINGS', payload: newSettings });
        localStorage.setItem('settings', JSON.stringify({ ...state.settings, ...newSettings }));
        if (newSettings.darkMode !== undefined) {
            document.documentElement.classList.toggle('dark', newSettings.darkMode);
        }
    }, [state.settings]);

    // Set color gradient
    const setColorGradient = useCallback((gradient) => {
        dispatch({ type: 'SET_COLOR_GRADIENT', payload: gradient });
    }, []);

    // Context value with all state and functions
    const contextValue = useMemo(() => ({
        ...state,
        colorGradients,
        handleFileUpload,
        processFile,
        handleSuggestion,
        undo,
        redo,
        resetDocument,
        saveDocument,
        exportDocument,
        login,
        logout,
        updateSettings,
        setColorGradient,
    }), [state, colorGradients, handleFileUpload, processFile, handleSuggestion, undo, redo, resetDocument, saveDocument, exportDocument, login, logout, updateSettings, setColorGradient]);

    return (
        <DocumentContext.Provider value={contextValue}>
            {children}
        </DocumentContext.Provider>
    );
};

// PropTypes for type checking
DocumentProvider.propTypes = {
    children: PropTypes.node.isRequired,
};