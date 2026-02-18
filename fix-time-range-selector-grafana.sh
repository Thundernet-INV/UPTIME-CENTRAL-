#!/bin/bash
# fix-time-range-selector-grafana.sh - SELECTOR DE RANGO ESTILO GRAFANA

echo "====================================================="
echo "📊 CREANDO SELECTOR DE RANGO ESTILO GRAFANA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_grafana_selector_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CREAR EL NUEVO SELECTOR ESTILO GRAFANA ==========
echo "[2] Creando TimeRangeSelector.jsx estilo Grafana..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx - ESTILO GRAFANA
import React, { useState, useEffect, useRef } from 'react';

// Opciones de rango predefinidas (como en Grafana)
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

// Opciones para búsqueda rápida
const SEARCH_OPTIONS = QUICK_RANGES.map(r => r.label);

// Variable GLOBAL
window.__TIME_RANGE = QUICK_RANGES[3]; // 1 hora por defecto

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
    return QUICK_RANGES[3]; // 1 hora por defecto
  });
  
  const [showAbsolute, setShowAbsolute] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredRanges, setFilteredRanges] = useState(QUICK_RANGES);
  const [recentRanges, setRecentRanges] = useState([]);
  const [customFrom, setCustomFrom] = useState('now-6h');
  const [customTo, setCustomTo] = useState('now');
  
  const dropdownRef = useRef(null);
  const searchInputRef = useRef(null);

  // Cargar rangos recientes de localStorage
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
    
    // Agregar a recientes
    setRecentRanges(prev => {
      const newRecent = [selectedRange, ...prev.filter(r => r.label !== selectedRange.label)].slice(0, 5);
      localStorage.setItem('recentTimeRanges', JSON.stringify(newRecent));
      return newRecent;
    });
    
    if (onRangeChange) onRangeChange(selectedRange);
    console.log('📊 Rango Grafana:', selectedRange.label);
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

  const handleSelectRange = (range) => {
    setSelectedRange(range);
    setIsOpen(false);
    setShowAbsolute(false);
    setSearchTerm('');
  };

  const handleApplyCustom = () => {
    // Parsear customFrom y customTo (simplificado)
    let hours = 6; // default
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
    }
    
    const customRange = {
      label: `${customFrom} → ${customTo}`,
      value: hours * 60 * 60 * 1000,
      hours: hours,
      isCustom: true
    };
    
    setSelectedRange(customRange);
    setIsOpen(false);
    setShowAbsolute(false);
  };

  const selectedLabel = selectedRange?.label || '1 hora';

  return (
    <div style={{ position: 'relative', display: 'inline-block' }} ref={dropdownRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 14px',
          background: 'var(--bg-tertiary, #f3f4f6)',
          border: '1px solid var(--border, #e5e7eb)',
          borderRadius: '20px',
          fontSize: '0.85rem',
          color: 'var(--text-primary, #1f2937)',
          cursor: 'pointer',
          transition: 'all 0.2s ease',
        }}
      >
        <span style={{ fontSize: '1rem' }}>📊</span>
        <span style={{ fontWeight: '500' }}>{selectedLabel}</span>
        <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>▼</span>
      </button>
      
      {isOpen && (
        <div style={{
          position: 'absolute',
          top: '100%',
          right: 0,
          marginTop: '8px',
          background: 'white',
          border: '1px solid #e5e7eb',
          borderRadius: '8px',
          boxShadow: '0 10px 25px -5px rgba(0,0,0,0.2)',
          zIndex: 10000,
          width: '380px',
          maxHeight: '600px',
          overflow: 'hidden',
          display: 'flex',
          flexDirection: 'column',
        }}>
          {/* Tabs: Relative | Absolute */}
          <div style={{ display: 'flex', borderBottom: '1px solid #e5e7eb' }}>
            <button
              onClick={() => setShowAbsolute(false)}
              style={{
                flex: 1,
                padding: '12px',
                background: !showAbsolute ? '#f3f4f6' : 'transparent',
                border: 'none',
                borderBottom: !showAbsolute ? '2px solid #3b82f6' : 'none',
                fontWeight: !showAbsolute ? '600' : '400',
                cursor: 'pointer',
              }}
            >
              Rangos relativos
            </button>
            <button
              onClick={() => setShowAbsolute(true)}
              style={{
                flex: 1,
                padding: '12px',
                background: showAbsolute ? '#f3f4f6' : 'transparent',
                border: 'none',
                borderBottom: showAbsolute ? '2px solid #3b82f6' : 'none',
                fontWeight: showAbsolute ? '600' : '400',
                cursor: 'pointer',
              }}
            >
              Rango absoluto
            </button>
          </div>

          {!showAbsolute ? (
            /* VISTA DE RANGOS RELATIVOS */
            <div style={{ overflow: 'auto', maxHeight: '500px' }}>
              {/* Buscador */}
              <div style={{ padding: '12px', borderBottom: '1px solid #e5e7eb' }}>
                <input
                  ref={searchInputRef}
                  type="text"
                  placeholder="Buscar rangos rápidos..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    border: '1px solid #e5e7eb',
                    borderRadius: '6px',
                    fontSize: '0.9rem',
                    outline: 'none',
                  }}
                />
              </div>

              {/* Rangos recientes */}
              {recentRanges.length > 0 && searchTerm === '' && (
                <div style={{ padding: '12px' }}>
                  <div style={{ fontSize: '0.7rem', textTransform: 'uppercase', color: '#6b7280', marginBottom: '8px' }}>
                    Usados recientemente
                  </div>
                  {recentRanges.map((range, idx) => (
                    <button
                      key={idx}
                      onClick={() => handleSelectRange(range)}
                      style={{
                        display: 'block',
                        width: '100%',
                        padding: '8px 12px',
                        textAlign: 'left',
                        border: 'none',
                        background: 'transparent',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '0.9rem',
                      }}
                      onMouseEnter={(e) => e.currentTarget.style.background = '#f3f4f6'}
                      onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                    >
                      {range.label}
                    </button>
                  ))}
                </div>
              )}

              {/* Rangos rápidos */}
              <div style={{ padding: '12px' }}>
                <div style={{ fontSize: '0.7rem', textTransform: 'uppercase', color: '#6b7280', marginBottom: '8px' }}>
                  Rangos rápidos
                </div>
                {filteredRanges.map((range, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleSelectRange(range)}
                    style={{
                      display: 'block',
                      width: '100%',
                      padding: '8px 12px',
                      textAlign: 'left',
                      border: 'none',
                      background: selectedRange.value === range.value ? '#e6f0ff' : 'transparent',
                      borderRadius: '4px',
                      cursor: 'pointer',
                      fontSize: '0.9rem',
                      color: selectedRange.value === range.value ? '#3b82f6' : 'inherit',
                      fontWeight: selectedRange.value === range.value ? '600' : '400',
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

              {/* Footer */}
              <div style={{ padding: '12px', borderTop: '1px solid #e5e7eb', fontSize: '0.8rem', color: '#6b7280' }}>
                <div>Zona horaria: <strong>Venezuela (UTC-4)</strong></div>
                <button
                  onClick={() => window.open('https://grafana.com/docs/grafana/latest/dashboards/time-range-controls/', '_blank')}
                  style={{
                    marginTop: '8px',
                    background: 'transparent',
                    border: 'none',
                    color: '#3b82f6',
                    cursor: 'pointer',
                    fontSize: '0.8rem',
                    textDecoration: 'underline',
                  }}
                >
                  Cambiar configuración de tiempo
                </button>
              </div>
            </div>
          ) : (
            /* VISTA DE RANGO ABSOLUTO */
            <div style={{ padding: '16px' }}>
              <div style={{ fontSize: '0.9rem', fontWeight: '600', marginBottom: '16px' }}>
                Rango de tiempo absoluto
              </div>
              
              <div style={{ marginBottom: '12px' }}>
                <label style={{ display: 'block', fontSize: '0.8rem', color: '#6b7280', marginBottom: '4px' }}>
                  Desde
                </label>
                <input
                  type="text"
                  value={customFrom}
                  onChange={(e) => setCustomFrom(e.target.value)}
                  placeholder="now-6h"
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    border: '1px solid #e5e7eb',
                    borderRadius: '6px',
                    fontSize: '0.9rem',
                  }}
                />
              </div>
              
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', fontSize: '0.8rem', color: '#6b7280', marginBottom: '4px' }}>
                  Hasta
                </label>
                <input
                  type="text"
                  value={customTo}
                  onChange={(e) => setCustomTo(e.target.value)}
                  placeholder="now"
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    border: '1px solid #e5e7eb',
                    borderRadius: '6px',
                    fontSize: '0.9rem',
                  }}
                />
              </div>
              
              <button
                onClick={handleApplyCustom}
                style={{
                  width: '100%',
                  padding: '10px',
                  background: '#3b82f6',
                  color: 'white',
                  border: 'none',
                  borderRadius: '6px',
                  fontSize: '0.9rem',
                  fontWeight: '500',
                  cursor: 'pointer',
                  marginBottom: '16px',
                }}
              >
                Aplicar rango de tiempo
              </button>
              
              <div style={{ fontSize: '0.8rem', color: '#6b7280' }}>
                <p>Puedes usar expresiones como:</p>
                <ul style={{ paddingLeft: '20px', marginTop: '4px' }}>
                  <li><code>now-6h</code> - hace 6 horas</li>
                  <li><code>now-1d</code> - hace 1 día</li>
                  <li><code>now-30m</code> - hace 30 minutos</li>
                  <li><code>2024-01-01 00:00:00</code> - fecha específica</li>
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

echo "✅ TimeRangeSelector.jsx estilo Grafana creado"
echo ""

# ========== 3. ACTUALIZAR DARK-MODE.CSS PARA EL NUEVO SELECTOR ==========
echo "[3] Actualizando dark-mode.css para el selector estilo Grafana..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== SELECTOR ESTILO GRAFANA - MODO OSCURO ========== */
body.dark-mode .time-range-selector div[style*="background: white"] {
  background: #1f2937 !important;
  border-color: #374151 !important;
}

body.dark-mode .time-range-selector input[type="text"] {
  background: #111827 !important;
  border-color: #374151 !important;
  color: #e5e7eb !important;
}

body.dark-mode .time-range-selector input[type="text"]::placeholder {
  color: #6b7280 !important;
}

body.dark-mode .time-range-selector button[style*="background: #f3f4f6"] {
  background: #374151 !important;
  color: #e5e7eb !important;
}

body.dark-mode .time-range-selector div[style*="background: #e6f0ff"] {
  background: #1e3a5f !important;
}

body.dark-mode .time-range-selector code {
  background: #111827 !important;
  color: #60a5fa !important;
  padding: 2px 4px;
  border-radius: 4px;
}

body.dark-mode .time-range-selector button:hover {
  background: #374151 !important;
}
EOF

echo "✅ dark-mode.css actualizado"
echo ""

# ========== 4. ACTUALIZAR INSTANCEDETAIL.JSX ==========
echo "[4] Actualizando InstanceDetail.jsx para usar el nuevo selector..."

sed -i 's/import { useTimeRange } from ".*"/import { useTimeRange } from ".\/TimeRangeSelector.jsx"/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
sed -i 's/selectedHours/range.hours/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

echo "✅ InstanceDetail.jsx actualizado"
echo ""

# ========== 5. ACTUALIZAR MULTISERVICEVIEW.JSX ==========
echo "[5] Actualizando MultiServiceView.jsx para usar el nuevo selector..."

sed -i 's/import { useTimeRange } from ".*"/import { useTimeRange } from ".\/TimeRangeSelector.jsx"/g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
sed -i 's/selectedHours/range.hours/g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

echo "✅ MultiServiceView.jsx actualizado"
echo ""

# ========== 6. LIMPIAR CACHÉ ==========
echo "[6] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 7. REINICIAR FRONTEND ==========
echo "[7] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 8. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ SELECTOR ESTILO GRAFANA INSTALADO ✅✅"
echo "====================================================="
echo ""
echo "📋 CARACTERÍSTICAS:"
echo ""
echo "   1. 🎯 DOS PESTAÑAS:"
echo "      • Rangos relativos (predefinidos)"
echo "      • Rango absoluto (personalizado)"
echo ""
echo "   2. 🔍 BUSCADOR:"
echo "      • Filtra rangos rápidos en tiempo real"
echo ""
echo "   3. 📜 RECIENTES:"
echo "      • Guarda los últimos 5 rangos usados"
echo ""
echo "   4. ⏱️ RANGOS PREDEFINIDOS:"
echo "      • 5m, 15m, 30m, 1h, 3h, 6h, 12h, 24h, 2d, 7d, 30d"
echo ""
echo "   5. 🌙 MODO OSCURO:"
echo "      • Totalmente compatible"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Haz click en el selector 📊"
echo "   3. ✅ EXPLORA las dos pestañas"
echo "   4. ✅ USA el buscador para filtrar"
echo "   5. ✅ PRUEBA rangos absolutos (now-6h)"
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
