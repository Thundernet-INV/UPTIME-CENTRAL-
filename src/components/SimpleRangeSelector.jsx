// src/components/SimpleRangeSelector.jsx
// SELECTOR DE RANGO ULTRA SIMPLE - SIN DEPENDENCIAS COMPLEJAS
import React, { useState, useEffect } from 'react';

// Opciones de rango
const RANGES = [
  { label: '1 hora', value: 1, hours: 1 },
  { label: '3 horas', value: 3, hours: 3 },
  { label: '6 horas', value: 6, hours: 6 },
  { label: '12 horas', value: 12, hours: 12 },
  { label: '24 horas', value: 24, hours: 24 },
  { label: '7 días', value: 168, hours: 168 },
  { label: '30 días', value: 720, hours: 720 },
];

// Variable GLOBAL simple
window.__RANGO_ACTUAL = RANGES[0];

// Evento GLOBAL simple
const RANGO_CHANGE_EVENT = 'rango-change';

export default function SimpleRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selected, setSelected] = useState(() => {
    try {
      const saved = localStorage.getItem('rango-seleccionado');
      if (saved) {
        const parsed = JSON.parse(saved);
        window.__RANGO_ACTUAL = parsed;
        return parsed;
      }
    } catch (e) {}
    return RANGES[0];
  });

  useEffect(() => {
    // Guardar en localStorage
    localStorage.setItem('rango-seleccionado', JSON.stringify(selected));
    
    // Actualizar variable GLOBAL
    window.__RANGO_ACTUAL = selected;
    
    // Disparar evento SIMPLE
    const event = new Event(RANGO_CHANGE_EVENT);
    window.dispatchEvent(event);
    
    console.log('🕒 RANGO CAMBIADO A:', selected.label);
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
        <span>🕒</span>
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
          zIndex: 99999,
          minWidth: '120px',
        }}>
          {RANGES.map((range, idx) => (
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
                borderBottom: idx < RANGES.length - 1 ? '1px solid #f0f0f0' : 'none',
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

// Hook SIMPLE para obtener el rango
export function useSimpleRange() {
  const [range, setRange] = useState(() => {
    if (window.__RANGO_ACTUAL) return window.__RANGO_ACTUAL;
    try {
      const saved = localStorage.getItem('rango-seleccionado');
      return saved ? JSON.parse(saved) : { label: '1 hora', value: 1, hours: 1 };
    } catch {
      return { label: '1 hora', value: 1, hours: 1 };
    }
  });

  useEffect(() => {
    const handler = () => {
      if (window.__RANGO_ACTUAL) {
        setRange(window.__RANGO_ACTUAL);
      }
    };
    
    window.addEventListener(RANGO_CHANGE_EVENT, handler);
    return () => window.removeEventListener(RANGO_CHANGE_EVENT, handler);
  }, []);

  return range;
}
