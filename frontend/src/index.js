import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './components/App';
import './styles/index.css';

// Create a root for React rendering
const root = createRoot(document.getElementById('root'));
// Render the App component
root.render(<App />);