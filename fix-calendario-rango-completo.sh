#!/bin/bash
# fix-calendario-rango-completo.sh - CALENDARIO SELECCIONA DESDE Y HASTA

echo "====================================================="
echo "📅 CALENDARIO - SELECCIÓN DE RANGO COMPLETO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_calendario_rango_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR TIMERANGESELECTOR.JSX CON RANGO COMPLETO ==========
echo "[2] Actualizando calendario para seleccionar DESDE y HASTA..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx - CON CALENDARIO PARA RANGO COMPLETO
import React, { useState, useEffect, useRef } from 'react';

// Opciones de rango predefinidas
const QUICK_RANGES = [
  { label: 'Últimos 5 minutos', value: 5 * 60 * 1000, hours: 5/60 },
  { label: 'Últimos 15 minutos', value: 15 * 60 * 1000, hours: 15/60 },
  { label: 'Últimos 30 minutos', value: 30 * 60 * 1000, hours: 30/60 },
  { label: 'Última 1 hora', value: 60 * 60 * 1000, hours: 1 },
  { label: 'Últimas 3 horas', value: 3 * 60 * 60 * 1000, hours: 3 },
  { label: 'Últimas 6 horas', value: 6 * 60 * 60 * 1000, hours: 6 },
  { label: 'Últimas 12 horas', value: 12 * 60 * 60 * 1000, hours: 12 },
  { label: 'Últimas 24 horas', value: 24 * 60 * 60 * 1000, hours: 24 },
  { label: 'Últimos 2 días', value: 48 * 60 * 60 * 1000, hours: 48 },
  { label: 'Últimos 7 días', value: 7 * 24 * 60 * 60 * 1000, hours: 168 },
  { label: 'Últimos 30 días', value: 30 * 24 * 60 * 60 * 1000, hours: 720 },
];

// Variable GLOBAL
window.__TIME_RANGE = QUICK_RANGES[3];

export default function TimeRangeSelector({ onRangeChange }) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedRange, setSelectedRange] = useState(() => {
    try {
      const saved = localStorage.getItem('grafanaTimeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        window.__TIME_RANGE = parsed;
        return parsed;
      }
    } catch (e) {}
    return QUICK_RANGES[3];
  });
  
  const [showAbsolute, setShowAbsolute] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredRanges, setFilteredRanges] = useState(QUICK_RANGES);
  const [recentRanges, setRecentRanges] = useState([]);
  const [customFrom, setCustomFrom] = useState('now-6h');
  const [customTo, setCustomTo] = useState('now');
  
  // 🟢 ESTADO PARA SELECCIÓN DE RANGO EN CALENDARIO
  const [currentMonth, setCurrentMonth] = useState(() => {
    const now = new Date();
    return { month: now.getMonth(), year: now.getFullYear() };
  });
  const [startDate, setStartDate] = useState(null);
  const [endDate, setEndDate] = useState(null);
  const [selecting, setSelecting] = useState('from'); // 'from' o 'to'
  
  const dropdownRef = useRef(null);
  const searchInputRef = useRef(null);

  // Detectar modo oscuro
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return document.body.classList.contains('dark-mode');
    }
    return false;
  });

  useEffect(() => {
    const observer = new MutationObserver(() => {
      setIsDark(document.body.classList.contains('dark-mode'));
    });
    observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
    return () => observer.disconnect();
  }, []);

  // Cargar rangos recientes
  useEffect(() => {
    try {
      const saved = localStorage.getItem('recentTimeRanges');
      if (saved) {
        setRecentRanges(JSON.parse(saved).slice(0, 5));
      }
    } catch (e) {}
  }, []);

  // Guardar rango seleccionado
  useEffect(() => {
    localStorage.setItem('grafanaTimeRange', JSON.stringify(selectedRange));
    window.__TIME_RANGE = selectedRange;
    window.dispatchEvent(new Event('time-range-change'));
    
    setRecentRanges(prev => {
      const newRecent = [selectedRange, ...prev.filter(r => r.label !== selectedRange.label)].slice(0, 5);
      localStorage.setItem('recentTimeRanges', JSON.stringify(newRecent));
      return newRecent;
    });
    
    if (onRangeChange) onRangeChange(selectedRange);
  }, [selectedRange]);

  // Filtrar rangos por búsqueda
  useEffect(() => {
    if (searchTerm.trim() === '') {
      setFilteredRanges(QUICK_RANGES);
    } else {
      const filtered = QUICK_RANGES.filter(r => 
        r.label.toLowerCase().includes(searchTerm.toLowerCase())
      );
      setFilteredRanges(filtered);
    }
  }, [searchTerm]);

  // Cerrar dropdown al hacer click fuera
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setIsOpen(false);
        setShowAbsolute(false);
        setSearchTerm('');
        setSelecting('from');
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Enfocar búsqueda cuando se abre
  useEffect(() => {
    if (isOpen && searchInputRef.current) {
      setTimeout(() => searchInputRef.current.focus(), 100);
    }
  }, [isOpen]);

  // FUNCIONES DEL CALENDARIO
  const getDaysInMonth = (year, month) => {
    return new Date(year, month + 1, 0).getDate();
  };

  const getFirstDayOfMonth = (year, month) => {
    const day = new Date(year, month, 1).getDay();
    return day === 0 ? 6 : day - 1;
  };

  const handlePrevMonth = () => {
    setCurrentMonth(prev => {
      if (prev.month === 0) {
        return { month: 11, year: prev.year - 1 };
      }
      return { month: prev.month - 1, year: prev.year };
    });
  };

  const handleNextMonth = () => {
    setCurrentMonth(prev => {
      if (prev.month === 11) {
        return { month: 0, year: prev.year + 1 };
      }
      return { month: prev.month + 1, year: prev.year };
    });
  };

  // 🟢 FUNCIÓN PARA SELECCIONAR FECHA (DESDE O HASTA)
  const handleDateClick = (day) => {
    const selected = new Date(currentMonth.year, currentMonth.month, day);
    const formatted = `${currentMonth.year}-${String(currentMonth.month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    
    if (selecting === 'from') {
      // Seleccionando DESDE
      setStartDate(selected);
      setCustomFrom(formatted);
      // Cambiar automáticamente a seleccionar HASTA
      setSelecting('to');
    } else {
      // Seleccionando HASTA
      setEndDate(selected);
      setCustomTo(formatted);
      // Si ya tenemos DESDE y HASTA, volver a DESDE para próxima selección
      setSelecting('from');
    }
  };

  // 🟢 FUNCIÓN PARA INTERCAMBIAR DESDE Y HASTA
  const swapDates = () => {
    const tempFrom = customFrom;
    const tempTo = customTo;
    setCustomFrom(tempTo);
    setCustomTo(tempFrom);
    
    const tempStart = startDate;
    const tempEnd = endDate;
    setStartDate(tempEnd);
    setEndDate(tempStart);
  };

  // 🟢 FUNCIÓN PARA ESTABLECER "AHORA" EN HASTA
  const setNow = () => {
    setCustomTo('now');
    setEndDate(null);
  };

  const monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  const handleSelectRange = (range) => {
    setSelectedRange(range);
    setIsOpen(false);
    setShowAbsolute(false);
    setSearchTerm('');
  };

  const handleApplyCustom = () => {
    let hours = 6;
    if (customFrom === 'now-6h') hours = 6;
    else if (customFrom === 'now-12h') hours = 12;
    else if (customFrom === 'now-24h') hours = 24;
    else if (customFrom.startsWith('now-')) {
      const match = customFrom.match(/now-(\d+)([hmd])/);
      if (match) {
        const val = parseInt(match[1]);
        const unit = match[2];
        if (unit === 'h') hours = val;
        if (unit === 'm') hours = val / 60;
        if (unit === 'd') hours = val * 24;
      }
    } else {
      try {
        const fromDate = new Date(customFrom);
        const toDate = customTo === 'now' ? new Date() : new Date(customTo);
        const diffMs = toDate - fromDate;
        hours = diffMs / (60 * 60 * 1000);
      } catch (e) {}
    }
    
    const customRange = {
      label: `${customFrom} → ${customTo}`,
      value: Math.abs(hours) * 60 * 60 * 1000,
      hours: Math.abs(hours),
      isCustom: true
    };
    
    setSelectedRange(customRange);
    setIsOpen(false);
    setShowAbsolute(false);
  };

  const selectedLabel = selectedRange?.label || '1 hora';

  // Verificar si una fecha está en el rango seleccionado
  const isDateInRange = (date) => {
    if (!startDate || !endDate) return false;
    return date >= startDate && date <= endDate;
  };

  return (
    <div style={{ position: 'relative', display: 'inline-block' }} ref={dropdownRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 16px',
          background: isDark ? 'transparent' : 'var(--bg-tertiary, #f3f4f6)',
          border: `1px solid ${isDark ? '#374151' : 'var(--border, #e5e7eb)'}`,
          borderRadius: '30px',
          fontSize: '0.9rem',
          color: isDark ? '#e5e7eb' : 'var(--text-primary, #1f2937)',
          cursor: 'pointer',
          transition: 'all 0.2s ease',
          fontWeight: '500',
        }}
      >
        <span style={{ fontSize: '1.1rem' }}>📅</span>
        <span>{selectedLabel}</span>
        <span style={{ fontSize: '0.8rem', opacity: 0.7 }}>▼</span>
      </button>
      
      {isOpen && (
        <div style={{
          position: 'absolute',
          top: '100%',
          right: 0,
          marginTop: '8px',
          background: isDark ? '#1f2937' : 'white',
          border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
          borderRadius: '12px',
          boxShadow: isDark ? '0 20px 25px -5px rgba(0,0,0,0.5)' : '0 20px 25px -5px rgba(0,0,0,0.2)',
          zIndex: 10000,
          width: '550px',
          maxHeight: '650px',
          overflow: 'hidden',
          display: 'flex',
          flexDirection: 'column',
        }}>
          {/* Tabs */}
          <div style={{ display: 'flex', borderBottom: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`, padding: '4px' }}>
            <button
              onClick={() => setShowAbsolute(false)}
              style={{
                flex: 1,
                padding: '12px',
                background: !showAbsolute ? (isDark ? '#374151' : '#f3f4f6') : 'transparent',
                border: 'none',
                borderBottom: !showAbsolute ? `2px solid #3b82f6` : 'none',
                fontWeight: !showAbsolute ? '600' : '400',
                cursor: 'pointer',
                borderRadius: '8px 8px 0 0',
                color: isDark ? '#e5e7eb' : 'inherit',
              }}
            >
              Rangos rápidos
            </button>
            <button
              onClick={() => setShowAbsolute(true)}
              style={{
                flex: 1,
                padding: '12px',
                background: showAbsolute ? (isDark ? '#374151' : '#f3f4f6') : 'transparent',
                border: 'none',
                borderBottom: showAbsolute ? `2px solid #3b82f6` : 'none',
                fontWeight: showAbsolute ? '600' : '400',
                cursor: 'pointer',
                borderRadius: '8px 8px 0 0',
                color: isDark ? '#e5e7eb' : 'inherit',
              }}
            >
              Rango absoluto
            </button>
          </div>

          {!showAbsolute ? (
            /* VISTA DE RANGOS RÁPIDOS */
            <div style={{ overflow: 'auto', maxHeight: '500px' }}>
              {/* Buscador */}
              <div style={{ padding: '16px', borderBottom: `1px solid ${isDark ? '#374151' : '#e5e7eb'}` }}>
                <input
                  ref={searchInputRef}
                  type="text"
                  placeholder="Buscar rangos rápidos..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    background: isDark ? '#111827' : 'white',
                    border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
                    borderRadius: '8px',
                    fontSize: '0.9rem',
                    color: isDark ? '#e5e7eb' : 'inherit',
                    outline: 'none',
                  }}
                />
              </div>

              {/* Rangos recientes */}
              {recentRanges.length > 0 && searchTerm === '' && (
                <div style={{ padding: '16px' }}>
                  <div style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: isDark ? '#9ca3af' : '#6b7280', marginBottom: '8px', letterSpacing: '0.5px' }}>
                    Usados recientemente
                  </div>
                  {recentRanges.map((range, idx) => (
                    <button
                      key={idx}
                      onClick={() => handleSelectRange(range)}
                      style={{
                        display: 'block',
                        width: '100%',
                        padding: '10px 14px',
                        textAlign: 'left',
                        border: 'none',
                        background: 'transparent',
                        borderRadius: '6px',
                        cursor: 'pointer',
                        fontSize: '0.9rem',
                        color: isDark ? '#e5e7eb' : 'inherit',
                      }}
                      onMouseEnter={(e) => e.currentTarget.style.background = isDark ? '#374151' : '#f3f4f6'}
                      onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                    >
                      {range.label}
                    </button>
                  ))}
                </div>
              )}

              {/* Rangos rápidos */}
              <div style={{ padding: '16px' }}>
                <div style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: isDark ? '#9ca3af' : '#6b7280', marginBottom: '8px', letterSpacing: '0.5px' }}>
                  Rangos rápidos
                </div>
                {filteredRanges.map((range, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleSelectRange(range)}
                    style={{
                      display: 'block',
                      width: '100%',
                      padding: '10px 14px',
                      textAlign: 'left',
                      border: 'none',
                      background: selectedRange.value === range.value ? (isDark ? '#1e3a5f' : '#e6f0ff') : 'transparent',
                      borderRadius: '6px',
                      cursor: 'pointer',
                      fontSize: '0.9rem',
                      color: isDark 
                        ? (selectedRange.value === range.value ? '#60a5fa' : '#e5e7eb')
                        : (selectedRange.value === range.value ? '#3b82f6' : 'inherit'),
                      fontWeight: selectedRange.value === range.value ? '600' : '400',
                    }}
                    onMouseEnter={(e) => {
                      if (selectedRange.value !== range.value) {
                        e.currentTarget.style.background = isDark ? '#374151' : '#f3f4f6';
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
            </div>
          ) : (
            /* VISTA DE RANGO ABSOLUTO CON CALENDARIO */
            <div style={{ padding: '20px', overflow: 'auto', maxHeight: '500px' }}>
              <div style={{ fontSize: '1rem', fontWeight: '600', marginBottom: '16px', color: isDark ? '#e5e7eb' : 'inherit' }}>
                Seleccionar rango de tiempo
              </div>
              
              {/* 🟢 INDICADOR DE SELECCIÓN ACTUAL */}
              <div style={{ 
                display: 'flex', 
                gap: '12px', 
                marginBottom: '16px',
                padding: '12px',
                background: isDark ? '#111827' : '#f3f4f6',
                borderRadius: '8px',
                border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`
              }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '0.75rem', color: isDark ? '#9ca3af' : '#6b7280', marginBottom: '4px' }}>
                    {selecting === 'from' ? '🔵 SELECCIONANDO' : '✓'} DESDE
                  </div>
                  <div style={{ 
                    padding: '8px', 
                    background: isDark ? '#1f2937' : 'white', 
                    borderRadius: '6px',
                    border: selecting === 'from' ? `2px solid #3b82f6` : `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
                    fontWeight: selecting === 'from' ? '600' : '400',
                    color: isDark ? '#e5e7eb' : 'inherit'
                  }}>
                    {startDate ? startDate.toLocaleDateString('es-ES') : customFrom}
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center' }}>
                  <button
                    onClick={swapDates}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      fontSize: '1.2rem',
                      cursor: 'pointer',
                      padding: '4px 8px',
                      color: isDark ? '#9ca3af' : '#6b7280',
                    }}
                    title="Intercambiar fechas"
                  >
                    ⇄
                  </button>
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: '0.75rem', color: isDark ? '#9ca3af' : '#6b7280', marginBottom: '4px' }}>
                    {selecting === 'to' ? '🔵 SELECCIONANDO' : '✓'} HASTA
                  </div>
                  <div style={{ 
                    padding: '8px', 
                    background: isDark ? '#1f2937' : 'white', 
                    borderRadius: '6px',
                    border: selecting === 'to' ? `2px solid #3b82f6` : `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
                    fontWeight: selecting === 'to' ? '600' : '400',
                    color: isDark ? '#e5e7eb' : 'inherit',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}>
                    <span>{endDate ? endDate.toLocaleDateString('es-ES') : customTo}</span>
                    {customTo !== 'now' && (
                      <button
                        onClick={setNow}
                        style={{
                          background: 'transparent',
                          border: 'none',
                          color: '#3b82f6',
                          cursor: 'pointer',
                          fontSize: '0.8rem',
                        }}
                      >
                        Ahora
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* CALENDARIO */}
              <div style={{ 
                padding: '16px',
                background: isDark ? 'transparent' : '#f9fafb',
                borderRadius: '10px',
                marginBottom: '20px',
                border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`
              }}>
                {/* Selector de mes/año */}
                <div style={{ 
                  display: 'flex', 
                  justifyContent: 'space-between', 
                  alignItems: 'center',
                  marginBottom: '16px'
                }}>
                  <button
                    onClick={handlePrevMonth}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      fontSize: '1.2rem',
                      cursor: 'pointer',
                      padding: '4px 8px',
                      borderRadius: '4px',
                      color: isDark ? '#e5e7eb' : 'inherit',
                    }}
                    onMouseEnter={(e) => e.currentTarget.style.background = isDark ? '#374151' : '#e5e7eb'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                  >
                    ←
                  </button>
                  <span style={{ fontWeight: '600', fontSize: '1rem', color: isDark ? '#e5e7eb' : 'inherit' }}>
                    {monthNames[currentMonth.month]} {currentMonth.year}
                  </span>
                  <button
                    onClick={handleNextMonth}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      fontSize: '1.2rem',
                      cursor: 'pointer',
                      padding: '4px 8px',
                      borderRadius: '4px',
                      color: isDark ? '#e5e7eb' : 'inherit',
                    }}
                    onMouseEnter={(e) => e.currentTarget.style.background = isDark ? '#374151' : '#e5e7eb'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                  >
                    →
                  </button>
                </div>

                {/* Días de la semana */}
                <div style={{ 
                  display: 'grid', 
                  gridTemplateColumns: 'repeat(7, 1fr)',
                  textAlign: 'center',
                  marginBottom: '8px',
                  fontSize: '0.8rem',
                  fontWeight: '600',
                  color: isDark ? '#9ca3af' : '#6b7280'
                }}>
                  <span>Lu</span><span>Ma</span><span>Mi</span><span>Ju</span><span>Vi</span><span>Sá</span><span>Do</span>
                </div>

                {/* Días del mes */}
                <div style={{ 
                  display: 'grid', 
                  gridTemplateColumns: 'repeat(7, 1fr)',
                  gap: '4px',
                  textAlign: 'center'
                }}>
                  {Array.from({ length: getFirstDayOfMonth(currentMonth.year, currentMonth.month) }, (_, i) => (
                    <div key={`empty-${i}`} style={{ padding: '8px' }}></div>
                  ))}
                  
                  {Array.from({ length: getDaysInMonth(currentMonth.year, currentMonth.month) }, (_, i) => {
                    const day = i + 1;
                    const date = new Date(currentMonth.year, currentMonth.month, day);
                    const today = new Date();
                    const isToday = today.getDate() === day && 
                                   today.getMonth() === currentMonth.month &&
                                   today.getFullYear() === currentMonth.year;
                    const isStart = startDate && 
                                   startDate.getDate() === day &&
                                   startDate.getMonth() === currentMonth.month &&
                                   startDate.getFullYear() === currentMonth.year;
                    const isEnd = endDate && 
                                 endDate.getDate() === day &&
                                 endDate.getMonth() === currentMonth.month &&
                                 endDate.getFullYear() === currentMonth.year;
                    const isInRange = startDate && endDate && date > startDate && date < endDate;
                    
                    let background = 'transparent';
                    if (isStart || isEnd) background = '#3b82f6';
                    else if (isInRange) background = isDark ? '#1e3a5f' : '#e6f0ff';
                    else if (isToday) background = isDark ? '#374151' : '#e5e7eb';
                    
                    return (
                      <button
                        key={day}
                        onClick={() => handleDateClick(day)}
                        style={{
                          padding: '8px',
                          border: 'none',
                          background: background,
                          color: (isStart || isEnd) ? 'white' : (isDark ? '#e5e7eb' : 'inherit'),
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '0.85rem',
                          fontWeight: (isStart || isEnd || isToday) ? '600' : '400',
                          position: 'relative',
                        }}
                        onMouseEnter={(e) => {
                          if (!isStart && !isEnd && !isInRange && !isToday) {
                            e.currentTarget.style.background = isDark ? '#374151' : '#f3f4f6';
                          }
                        }}
                        onMouseLeave={(e) => {
                          if (!isStart && !isEnd && !isInRange && !isToday) {
                            e.currentTarget.style.background = 'transparent';
                          }
                        }}
                      >
                        {day}
                        {isStart && <span style={{ position: 'absolute', bottom: '2px', left: '50%', transform: 'translateX(-50%)', fontSize: '0.6rem' }}>▼</span>}
                        {isEnd && <span style={{ position: 'absolute', bottom: '2px', left: '50%', transform: 'translateX(-50%)', fontSize: '0.6rem' }}>▲</span>}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div style={{ fontSize: '0.9rem', fontWeight: '600', marginBottom: '12px', color: isDark ? '#e5e7eb' : 'inherit' }}>
                Rango de tiempo absoluto
              </div>
              
              <div style={{ marginBottom: '12px' }}>
                <label style={{ display: 'block', fontSize: '0.8rem', color: isDark ? '#9ca3af' : '#6b7280', marginBottom: '4px' }}>
                  Desde
                </label>
                <input
                  type="text"
                  value={customFrom}
                  onChange={(e) => setCustomFrom(e.target.value)}
                  placeholder="now-6h o 2024-01-01"
                  style={{
                    width: '100%',
                    padding: '10px 12px',
                    background: isDark ? '#111827' : 'white',
                    border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
                    borderRadius: '8px',
                    fontSize: '0.9rem',
                    color: isDark ? '#e5e7eb' : 'inherit',
                  }}
                />
              </div>
              
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', fontSize: '0.8rem', color: isDark ? '#9ca3af' : '#6b7280', marginBottom: '4px' }}>
                  Hasta
                </label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <input
                    type="text"
                    value={customTo}
                    onChange={(e) => setCustomTo(e.target.value)}
                    placeholder="now"
                    style={{
                      flex: 1,
                      padding: '10px 12px',
                      background: isDark ? '#111827' : 'white',
                      border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
                      borderRadius: '8px',
                      fontSize: '0.9rem',
                      color: isDark ? '#e5e7eb' : 'inherit',
                    }}
                  />
                  <button
                    onClick={setNow}
                    style={{
                      padding: '10px 16px',
                      background: 'transparent',
                      border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`,
                      borderRadius: '8px',
                      color: isDark ? '#e5e7eb' : '#1f2937',
                      cursor: 'pointer',
                      fontSize: '0.9rem',
                    }}
                    onMouseEnter={(e) => e.currentTarget.style.background = isDark ? '#374151' : '#f3f4f6'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                  >
                    Ahora
                  </button>
                </div>
              </div>
              
              <button
                onClick={handleApplyCustom}
                style={{
                  width: '100%',
                  padding: '12px',
                  background: '#3b82f6',
                  color: 'white',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '0.9rem',
                  fontWeight: '500',
                  cursor: 'pointer',
                  marginBottom: '16px',
                }}
                onMouseEnter={(e) => e.currentTarget.style.background = '#2563eb'}
                onMouseLeave={(e) => e.currentTarget.style.background = '#3b82f6'}
              >
                Aplicar rango de tiempo
              </button>
              
              <div style={{ 
                fontSize: '0.8rem', 
                color: isDark ? '#9ca3af' : '#6b7280', 
                background: isDark ? '#111827' : '#f9fafb', 
                padding: '12px', 
                borderRadius: '8px',
                border: `1px solid ${isDark ? '#374151' : 'transparent'}`
              }}>
                <p style={{ margin: '0 0 8px 0', fontWeight: '600', color: isDark ? '#e5e7eb' : 'inherit' }}>Formatos aceptados:</p>
                <ul style={{ margin: '0', paddingLeft: '20px' }}>
                  <li><code style={{ background: isDark ? '#1f2937' : '#e5e7eb', padding: '2px 4px', borderRadius: '4px' }}>now-6h</code> - hace 6 horas</li>
                  <li><code style={{ background: isDark ? '#1f2937' : '#e5e7eb', padding: '2px 4px', borderRadius: '4px' }}>now-1d</code> - hace 1 día</li>
                  <li><code style={{ background: isDark ? '#1f2937' : '#e5e7eb', padding: '2px 4px', borderRadius: '4px' }}>2024-02-13</code> - fecha específica</li>
                </ul>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// Hook para usar el rango de tiempo
export function useTimeRange() {
  const [range, setRange] = useState(() => {
    if (window.__TIME_RANGE) return window.__TIME_RANGE;
    try {
      const saved = localStorage.getItem('grafanaTimeRange');
      return saved ? JSON.parse(saved) : { label: '1 hora', value: 3600000, hours: 1 };
    } catch {
      return { label: '1 hora', value: 3600000, hours: 1 };
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
EOF

echo "✅ TimeRangeSelector.jsx actualizado - calendario selecciona DESDE y HASTA"
echo ""

# ========== 3. LIMPIAR CACHÉ ==========
echo "[3] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 4. REINICIAR FRONTEND ==========
echo "[4] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 5. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CALENDARIO - RANGO COMPLETO ✅✅"
echo "====================================================="
echo ""
echo "📅 NUEVAS CARACTERÍSTICAS:"
echo ""
echo "   1. 🔵 INDICADOR VISUAL: Muestra si estás seleccionando DESDE o HASTA"
echo "   2. 📆 RANGO COMPLETO: Selecciona DESDE y luego HASTA en el calendario"
echo "   3. 🎨 COLORES:"
echo "      • Inicio/Fin: AZUL"
echo "      • Rango intermedio: AZUL CLARO"
echo "      • Hoy: GRIS"
echo "   4. 🔄 INTERCAMBIAR: Botón ⇄ para intercambiar fechas"
echo "   5. ⏰ AHORA: Botón para poner 'now' en HASTA"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Haz click en el selector 📅"
echo "   3. ✅ Ve a 'Rango absoluto'"
echo "   4. ✅ SELECCIONA UNA FECHA (se pondrá en DESDE)"
echo "   5. ✅ SELECCIONA OTRA FECHA (se pondrá en HASTA)"
echo "   6. ✅ EL RANGO SE ILUMINA entre las dos fechas"
echo ""
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
