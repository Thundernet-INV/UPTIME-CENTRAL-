// src/components/DarkModeCornerButton.jsx
// Botón de modo oscuro en la esquina inferior izquierda

import React, { useState, useEffect } from 'react';

export default function DarkModeCornerButton() {
  const [isDark, setIsDark] = useState(() => {
    try {
      return localStorage.getItem('uptime-theme') === 'dark';
    } catch {
      return false;
    }
  });

  useEffect(() => {
    if (isDark) {
      document.body.classList.add('dark-mode');
      localStorage.setItem('uptime-theme', 'dark');
    } else {
      document.body.classList.remove('dark-mode');
      localStorage.setItem('uptime-theme', 'light');
    }
  }, [isDark]);

  const toggleTheme = () => {
    setIsDark(prev => !prev);
  };

  return (
    <button
      type="button"
      onClick={toggleTheme}
      style={{
        position: 'fixed',
        bottom: '20px',
        left: '20px',
        zIndex: 99999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: '48px',
        height: '48px',
        borderRadius: '50%',
        fontSize: '1.5rem',
        background: isDark ? '#1a1e24' : '#ffffff',
        color: isDark ? '#ffffff' : '#1f2937',
        border: isDark ? '1px solid #3a3f47' : '1px solid #e5e7eb',
        boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
        cursor: 'pointer',
        transition: 'all 0.2s ease',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = 'scale(1.1)';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = 'scale(1)';
      }}
      title={isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
    >
      {isDark ? '☀️' : '🌙'}
    </button>
  );
}
