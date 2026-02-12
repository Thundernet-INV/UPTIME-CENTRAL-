// src/components/DarkModeCornerButton.jsx
// Botón de modo oscuro en la esquina superior derecha

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
        top: '20px',
        right: '24px',
        zIndex: 10000,
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '10px 20px',
        borderRadius: '999px',
        fontSize: '0.95rem',
        fontWeight: '600',
        background: isDark ? '#1a1e24' : '#ffffff',
        color: isDark ? '#ffffff' : '#1f2937',
        border: isDark ? '1px solid #3a3f47' : '1px solid #e5e7eb',
        boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
        cursor: 'pointer',
        transition: 'all 0.2s ease',
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = 'translateY(-2px)';
        e.currentTarget.style.boxShadow = '0 8px 16px rgba(0,0,0,0.15)';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = 'translateY(0)';
        e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.1)';
      }}
    >
      {isDark ? (
        <>
          <span style={{ fontSize: '1.3rem' }}>☀️</span>
          <span>Modo Claro</span>
        </>
      ) : (
        <>
          <span style={{ fontSize: '1.3rem' }}>🌙</span>
          <span>Modo Oscuro</span>
        </>
      )}
    </button>
  );
}
