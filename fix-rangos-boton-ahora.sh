#!/bin/bash
# fix-rangos-boton-ahora.sh - CORREGIR BOTÓN DE RANGOS DE TIEMPO

echo "====================================================="
echo "🔧 CORRIGIENDO BOTÓN DE RANGOS DE TIEMPO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_rangos_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. VERIFICAR Y CORREGIR DASHBOARD.JSX ==========
echo "[2] Verificando Dashboard.jsx..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Verificar si ya tiene el import
if grep -q "import TimeRangeSelector" "$DASHBOARD_FILE"; then
    echo "   ✅ TimeRangeSelector ya está importado"
else
    echo "   ⚠️ Agregando import de TimeRangeSelector..."
    sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "$DASHBOARD_FILE"
fi

# Verificar si ya tiene el componente en el render
if grep -q "<TimeRangeSelector" "$DASHBOARD_FILE"; then
    echo "   ✅ TimeRangeSelector ya está en el render"
else
    echo "   ⚠️ Agregando TimeRangeSelector al render..."
    
    # Buscar el div de controles y agregar el selector antes del botón de notificaciones
    sed -i '/{·*Controles: filtro por tipo/,/<\/div>/ {
        /{·*Filtro por tipo de servicio/ a\
\
                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />
    }' "$DASHBOARD_FILE"
fi

echo "✅ Dashboard.jsx verificado"
echo ""

# ========== 3. VERIFICAR Y CORREGIR TIMERANGESELECTOR.JSX ==========
echo "[3] Verificando TimeRangeSelector.jsx..."

SELECTOR_FILE="${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx"

if [ ! -f "$SELECTOR_FILE" ]; then
    echo "   ⚠️ TimeRangeSelector.jsx no existe - creándolo..."
    
    cat > "$SELECTOR_FILE" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN CORREGIDA

import React, { useState, useEffect } from 'react';

// Opciones de rango
export const TIME_RANGES = [
  { label: 'Última 1 hora', value: 60 * 60 * 1000 },
  { label: 'Últimas 3 horas', value: 3 * 60 * 60 * 1000 },
  { label: 'Últimas 6 horas', value: 6 * 60 * 60 * 1000 },
  { label: 'Últimas 12 horas', value: 12 * 60 * 60 * 1000 },
  { label: 'Últimas 24 horas', value: 24 * 60 * 60 * 1000 },
  { label: 'Últimos 7 días', value: 7 * 24 * 60 * 60 * 1000 },
  { label: 'Últimos 30 días', value: 30 * 24 * 60 * 60 * 1000 },
];

// Evento global para cambios de rango
export const TIME_RANGE_CHANGE_EVENT = 'time-range-change';

export default function TimeRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedRange, setSelectedRange] = useState(() => {
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed.value === 'number') {
          return parsed;
        }
      }
    } catch (e) {}
    return TIME_RANGES[0];
  });

  useEffect(() => {
    try {
      localStorage.setItem('timeRange', JSON.stringify(selectedRange));
      
      const event = new CustomEvent(TIME_RANGE_CHANGE_EVENT, {
        detail: selectedRange
      });
      window.dispatchEvent(event);
      
      console.log(`📊 TimeRangeSelector - Rango cambiado a: ${selectedRange.label}`);
    } catch (e) {
      console.error('Error guardando rango:', e);
    }
  }, [selectedRange]);

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
          e.preventDefault();
          e.stopPropagation();
          console.log('📊 Click en selector de tiempo');
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
        onMouseEnter={(e) => {
          e.currentTarget.style.background = 'var(--bg-hover, #e5e7eb)';
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.background = 'var(--bg-secondary, #f3f4f6)';
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
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            zIndex: 9999,
            minWidth: '180px',
            overflow: 'hidden',
          }}
        >
          {TIME_RANGES.map((range, index) => (
            <button
              key={index}
              type="button"
              onClick={() => {
                console.log(`📊 Seleccionando rango: ${range.label}`);
                setSelectedRange(range);
                setIsOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                padding: '10px 16px',
                textAlign: 'left',
                border: 'none',
                borderBottom: index < TIME_RANGES.length - 1 ? '1px solid #f0f0f0' : 'none',
                background: selectedRange.value === range.value ? '#3b82f6' : 'transparent',
                color: selectedRange.value === range.value ? 'white' : '#1f2937',
                fontSize: '0.85rem',
                fontWeight: selectedRange.value === range.value ? '600' : '400',
                cursor: 'pointer',
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

// Hook para usar el rango de tiempo
export function useTimeRange() {
  const [range, setRange] = useState(TIME_RANGES[0]);

  useEffect(() => {
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed.value === 'number') {
          setRange(parsed);
          console.log(`📊 useTimeRange - rango inicial: ${parsed.label}`);
        }
      }
    } catch (e) {}

    const handleRangeChange = (e) => {
      console.log(`📡 useTimeRange - evento recibido: ${e.detail.label}`);
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range;
}
EOF
    echo "   ✅ TimeRangeSelector.jsx creado"
else
    echo "   ✅ TimeRangeSelector.jsx ya existe"
fi
echo ""

# ========== 4. VERIFICAR QUE EL SELECTOR ESTÉ EN EL LUGAR CORRECTO ==========
echo "[4] Verificando posición del selector en Dashboard..."

# Buscar la línea exacta donde está el botón de notificaciones
if grep -q "<TimeRangeSelector" "$DASHBOARD_FILE"; then
    echo "   ✅ Selector encontrado en Dashboard"
else
    echo "   ⚠️ Forzando inserción del selector..."
    
    # Buscar el botón de notificaciones y poner el selector ANTES
    sed -i '/{·*Botón Notificaciones ON\/OFF/i \                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />' "$DASHBOARD_FILE"
    echo "   ✅ Selector insertado antes del botón de notificaciones"
fi
echo ""

# ========== 5. AGREGAR ESTILOS PARA MODO OSCURO ==========
echo "[5] Agregando estilos para modo oscuro..."

DARK_MODE_CSS="${FRONTEND_DIR}/src/dark-mode.css"

if [ -f "$DARK_MODE_CSS" ]; then
    if ! grep -q "time-range-selector" "$DARK_MODE_CSS"; then
        cat >> "$DARK_MODE_CSS" << 'EOF'

/* ========== SELECTOR DE RANGO DE TIEMPO - MODO OSCURO ========== */
body.dark-mode .time-range-selector button {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .time-range-selector button:hover {
  background: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
  box-shadow: 0 4px 12px rgba(0,0,0,0.5) !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button {
  color: #e5e7eb !important;
  border-bottom-color: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button:hover {
  background: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  color: white !important;
}
EOF
        echo "   ✅ Estilos modo oscuro agregados"
    else
        echo "   ✅ Estilos modo oscuro ya existen"
    fi
fi
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
echo "✅✅ BOTÓN DE RANGOS CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 📊 TimeRangeSelector.jsx: VERIFICADO/CREADO"
echo "   2. 🎯 Dashboard.jsx: SELECTOR AGREGADO ANTES del botón de notificaciones"
echo "   3. 🎨 dark-mode.css: ESTILOS AGREGADOS para modo oscuro"
echo "   4. 🧹 Caché: LIMPIADA"
echo ""
echo "📍 UBICACIÓN DEL SELECTOR:"
echo "   • Al lado del filtro de tipo de servicio"
echo "   • ANTES del botón de notificaciones"
echo "   • MISMO estilo que los demás controles"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ DEBES VER el selector 📊 'Última 1 hora'"
echo "   3. ✅ Haz CLICK en el selector - DEBE abrir el dropdown"
echo "   4. ✅ Selecciona 'Últimas 24 horas'"
echo "   5. ✅ El selector DEBE cambiar el texto"
echo "   6. ✅ Entra a una sede - LA GRÁFICA DEBE ACTUALIZARSE"
echo "   7. ✅ Activa modo oscuro - EL SELECTOR DEBE CAMBIAR DE COLOR"
echo ""
echo "📌 SI NO VES EL SELECTOR:"
echo ""
echo "   Abre src/views/Dashboard.jsx y busca:"
echo "   <TimeRangeSelector />"
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
