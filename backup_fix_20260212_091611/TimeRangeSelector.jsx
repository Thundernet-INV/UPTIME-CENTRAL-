// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN SIMPLE Y ESTABLE

import React, { useState, useEffect } from 'react';

// Opciones de rango
const TIME_RANGES = [
  { label: 'Última 1 hora', value: 60 * 60 * 1000 },
  { label: 'Últimas 3 horas', value: 3 * 60 * 60 * 1000 },
  { label: 'Últimas 6 horas', value: 6 * 60 * 60 * 1000 },
  { label: 'Últimas 12 horas', value: 12 * 60 * 60 * 1000 },
  { label: 'Últimas 24 horas', value: 24 * 60 * 60 * 1000 },
  { label: 'Últimos 7 días', value: 7 * 24 * 60 * 60 * 1000 },
];

// Evento global para cambios de rango
export const TIME_RANGE_CHANGE_EVENT = 'time-range-change';

export default function TimeRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedRange, setSelectedRange] = useState(() => {
    // Intentar cargar desde localStorage
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        return JSON.parse(saved);
      }
    } catch (e) {}
    return TIME_RANGES[0]; // 1 hora por defecto
  });

  // Guardar en localStorage y emitir evento
  useEffect(() => {
    try {
      localStorage.setItem('timeRange', JSON.stringify(selectedRange));
      
      // Emitir evento global para que otros componentes se actualicen
      const event = new CustomEvent(TIME_RANGE_CHANGE_EVENT, {
        detail: selectedRange
      });
      window.dispatchEvent(event);
      
      console.log(`📊 Rango cambiado: ${selectedRange.label}`);
    } catch (e) {
      console.error('Error guardando rango:', e);
    }
  }, [selectedRange]);

  // Cerrar dropdown al hacer click fuera
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (isOpen && !e.target.closest('.time-range-selector')) {
        setIsOpen(false);
      }
    };
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, [isOpen]);

  return (
    <div className="time-range-selector" style={{ position: 'relative', display: 'inline-block' }}>
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          setIsOpen(!isOpen);
        }}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 12px',
          background: 'var(--bg-secondary, #f3f4f6)',
          border: '1px solid var(--border, #e5e7eb)',
          borderRadius: '6px',
          fontSize: '0.85rem',
          color: 'var(--text-primary, #1f2937)',
          cursor: 'pointer',
          transition: 'all 0.2s ease',
        }}
      >
        <span style={{ fontSize: '1.1rem' }}>📊</span>
        <span>{selectedRange.label}</span>
        <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>▼</span>
      </button>

      {isOpen && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            right: '0',
            marginTop: '4px',
            background: 'white',
            border: '1px solid #e5e7eb',
            borderRadius: '6px',
            boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)',
            zIndex: 1000,
            minWidth: '160px',
          }}
        >
          {TIME_RANGES.map((range, index) => (
            <button
              key={index}
              type="button"
              onClick={() => {
                setSelectedRange(range);
                setIsOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                padding: '8px 12px',
                textAlign: 'left',
                border: 'none',
                background: selectedRange.value === range.value ? '#3b82f6' : 'transparent',
                color: selectedRange.value === range.value ? 'white' : '#1f2937',
                fontSize: '0.85rem',
                cursor: 'pointer',
                transition: 'background 0.2s ease',
              }}
              onMouseEnter={(e) => {
                if (selectedRange.value !== range.value) {
                  e.currentTarget.style.background = '#f3f4f6';
                }
              }}
              onMouseLeave={(e) => {
                if (selectedRange.value !== range.value) {
                  e.currentTarget.style.background = 'transparent';
                }
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

// Hook personalizado para usar el rango de tiempo
export function useTimeRange() {
  const [range, setRange] = useState(TIME_RANGES[0]);

  useEffect(() => {
    // Cargar rango inicial desde localStorage
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        setRange(JSON.parse(saved));
      }
    } catch (e) {}

    // Escuchar cambios
    const handleRangeChange = (e) => {
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range;
}
