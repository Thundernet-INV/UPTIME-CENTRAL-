// src/components/TimeRangeSelector.jsx - VERSIÓN ULTRA SIMPLE
import React, { useState, useEffect } from 'react';

// Opciones de rango
const TIME_RANGES = [
  { label: '1 hora', value: 60 * 60 * 1000 },
  { label: '3 horas', value: 3 * 60 * 60 * 1000 },
  { label: '6 horas', value: 6 * 60 * 60 * 1000 },
  { label: '12 horas', value: 12 * 60 * 60 * 1000 },
  { label: '24 horas', value: 24 * 60 * 60 * 1000 },
  { label: '7 días', value: 7 * 24 * 60 * 60 * 1000 },
];

// Variable GLOBAL
window.__TIME_RANGE = TIME_RANGES[0];

export default function TimeRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selected, setSelected] = useState(() => {
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        window.__TIME_RANGE = parsed;
        return parsed;
      }
    } catch (e) {}
    return TIME_RANGES[0];
  });

  useEffect(() => {
    localStorage.setItem('timeRange', JSON.stringify(selected));
    window.__TIME_RANGE = selected;
    window.dispatchEvent(new Event('time-range-change'));
    console.log('📊 Rango:', selected.label);
  }, [selected]);

  return (
    <div style={{ position: 'relative', display: 'inline-block' }}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          padding: '6px 12px',
          background: '#f3f4f6',
          border: '1px solid #e5e7eb',
          borderRadius: '6px',
          fontSize: '0.85rem',
          color: '#1f2937',
          cursor: 'pointer',
        }}
      >
        <span>📊</span>
        <span>{selected.label}</span>
        <span style={{ fontSize: '0.7rem' }}>▼</span>
      </button>
      
      {isOpen && (
        <div style={{
          position: 'absolute',
          top: '100%',
          right: 0,
          marginTop: '4px',
          background: 'white',
          border: '1px solid #e5e7eb',
          borderRadius: '6px',
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
          zIndex: 9999,
          minWidth: '120px',
        }}>
          {TIME_RANGES.map((range, idx) => (
            <button
              key={idx}
              onClick={() => {
                setSelected(range);
                setIsOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                padding: '8px 16px',
                textAlign: 'left',
                border: 'none',
                borderBottom: idx < TIME_RANGES.length - 1 ? '1px solid #f0f0f0' : 'none',
                background: selected.value === range.value ? '#3b82f6' : 'transparent',
                color: selected.value === range.value ? 'white' : '#1f2937',
                cursor: 'pointer',
              }}
            >
              {range.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// Hook SIMPLE - SIN DUPLICADOS
export function useTimeRange() {
  const [range, setRange] = useState(() => {
    if (window.__TIME_RANGE) return window.__TIME_RANGE;
    try {
      const saved = localStorage.getItem('timeRange');
      return saved ? JSON.parse(saved) : TIME_RANGES[0];
    } catch {
      return TIME_RANGES[0];
    }
  });

  useEffect(() => {
    const handler = () => {
      if (window.__TIME_RANGE) setRange(window.__TIME_RANGE);
    };
    window.addEventListener('time-range-change', handler);
    return () => window.removeEventListener('time-range-change', handler);
  }, []);

  return range;
}
