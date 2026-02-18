// src/contexts/ThemeContext.jsx
import React, { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext();

export const themes = {
  light: {
    name: 'light',
    // Backgrounds
    bgPrimary: '#ffffff',
    bgSecondary: '#f9fafb',
    bgTertiary: '#f3f4f6',
    bgCard: '#ffffff',
    bgHover: '#f9fafb',
    
    // Text
    textPrimary: '#111827',
    textSecondary: '#4b5563',
    textTertiary: '#6b7280',
    textInverse: '#ffffff',
    
    // Borders
    border: '#e5e7eb',
    borderHover: '#d1d5db',
    
    // Status colors (mantenemos los mismos)
    success: '#16a34a',
    successBg: '#dcfce7',
    warning: '#f59e0b',
    warningBg: '#fef3c7',
    danger: '#dc2626',
    dangerBg: '#fee2e2',
    info: '#3b82f6',
    infoBg: '#dbeafe',
    
    // Charts
    chartGrid: '#e5e7eb',
    chartText: '#6b7280',
    chartLine: '#3b82f6',
    
    // Shadows
    shadow: '0 1px 3px rgba(0,0,0,0.1)',
    shadowLg: '0 10px 25px -5px rgba(0,0,0,0.1)',
    
    // Cards
    cardBg: '#ffffff',
    cardBorder: '#e5e7eb',
    
    // Inputs
    inputBg: '#ffffff',
    inputBorder: '#e5e7eb',
    inputPlaceholder: '#9ca3af',
    
    // Buttons
    btnGhostBg: 'transparent',
    btnGhostHover: '#f3f4f6',
    btnGhostBorder: '#e5e7eb',
    btnGhostText: '#374151',
  },
  dark: {
    name: 'dark',
    // Backgrounds
    bgPrimary: '#0f172a',  // slate-900
    bgSecondary: '#1e293b', // slate-800
    bgTertiary: '#334155',  // slate-700
    bgCard: '#1e293b',      // slate-800
    bgHover: '#2d3b4f',     // slate-700/80
    
    // Text
    textPrimary: '#f1f5f9', // slate-100
    textSecondary: '#cbd5e1', // slate-300
    textTertiary: '#94a3b8', // slate-400
    textInverse: '#0f172a',
    
    // Borders
    border: '#334155',      // slate-700
    borderHover: '#475569', // slate-600
    
    // Status colors (mantenemos igual pero con fondos adaptados)
    success: '#4ade80',     // green-400
    successBg: '#166534',   // green-800
    warning: '#fbbf24',     // amber-400
    warningBg: '#854d0e',   // amber-800
    danger: '#f87171',      // red-400
    dangerBg: '#991b1b',    // red-800
    info: '#60a5fa',        // blue-400
    infoBg: '#1e40af',      // blue-800
    
    // Charts
    chartGrid: '#334155',
    chartText: '#94a3b8',
    chartLine: '#60a5fa',
    
    // Shadows
    shadow: '0 1px 3px rgba(0,0,0,0.5)',
    shadowLg: '0 20px 25px -5px rgba(0,0,0,0.7)',
    
    // Cards
    cardBg: '#1e293b',
    cardBorder: '#334155',
    
    // Inputs
    inputBg: '#0f172a',
    inputBorder: '#334155',
    inputPlaceholder: '#64748b',
    
    // Buttons
    btnGhostBg: 'transparent',
    btnGhostHover: '#334155',
    btnGhostBorder: '#475569',
    btnGhostText: '#e2e8f0',
  }
};

export const ThemeProvider = ({ children }) => {
  const [theme, setTheme] = useState(() => {
    const saved = localStorage.getItem('uptime-theme');
    return saved ? themes[saved] : themes.light;
  });

  useEffect(() => {
    localStorage.setItem('uptime-theme', theme.name);
    
    // Actualizar CSS variables
    const root = document.documentElement;
    Object.entries(theme).forEach(([key, value]) => {
      if (typeof value === 'string' && key !== 'name') {
        root.style.setProperty(`--${key}`, value);
      }
    });
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev.name === 'light' ? themes.dark : themes.light);
  };

  const setLightTheme = () => setTheme(themes.light);
  const setDarkTheme = () => setTheme(themes.dark);

  return (
    <ThemeContext.Provider value={{
      theme,
      toggleTheme,
      setLightTheme,
      setDarkTheme,
      isDark: theme.name === 'dark',
      isLight: theme.name === 'light'
    }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme debe usarse dentro de ThemeProvider');
  }
  return context;
};
