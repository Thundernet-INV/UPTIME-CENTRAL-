// src/components/ThemeToggle.jsx
import React from 'react';
import { useTheme } from '../contexts/ThemeContext';

export default function ThemeToggle({ className = '' }) {
  const { theme, toggleTheme, isDark } = useTheme();

  return (
    <button
      type="button"
      onClick={toggleTheme}
      className={`theme-toggle ${className}`}
      title={isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro'}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '6px',
        padding: '6px 12px',
        borderRadius: '999px',
        fontSize: '0.85rem',
        fontWeight: '500',
        background: isDark ? theme.bgTertiary : theme.bgSecondary,
        color: theme.textPrimary,
        border: `1px solid ${theme.border}`,
        cursor: 'pointer',
        transition: 'all 0.2s ease',
      }}
    >
      {isDark ? (
        <>
          <span style={{ fontSize: '1.1rem' }}>☀️</span>
          <span>Claro</span>
        </>
      ) : (
        <>
          <span style={{ fontSize: '1.1rem' }}>🌙</span>
          <span>Oscuro</span>
        </>
      )}
    </button>
  );
}
