#!/bin/bash
# fix-imports-ahora.sh - CORREGIR IMPORTS DUPLICADOS Y SELECTOR DE RANGOS

echo "====================================================="
echo "🔧 CORRIGIENDO IMPORTS DUPLICADOS - VERSIÓN SIMPLE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_imports_ahora_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CORREGIR TIMERANGESELECTOR.JSX - VERSIÓN ULTRA SIMPLE ==========
echo "[2] Creando TimeRangeSelector.jsx - VERSIÓN ULTRA SIMPLE..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
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
EOF

echo "✅ TimeRangeSelector.jsx creado"
echo ""

# ========== 3. CORREGIR MULTISERVICEVIEW.JSX ==========
echo "[3] Corrigiendo MultiServiceView.jsx - ELIMINAR IMPORT DUPLICADO..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

# Hacer backup
cp "$MULTI_FILE" "$BACKUP_DIR/MultiServiceView.jsx.bak"

# ELIMINAR TODOS los imports de useTimeRange y TIME_RANGE_CHANGE_EVENT
sed -i '/import { useTimeRange/d' "$MULTI_FILE"
sed -i '/TIME_RANGE_CHANGE_EVENT/d' "$MULTI_FILE"

# Agregar UN SOLO import al principio
sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "$MULTI_FILE"

# Verificar que solo haya UNO
COUNT=$(grep -c "import { useTimeRange }" "$MULTI_FILE")
echo "   📊 Imports de useTimeRange: $COUNT (debe ser 1)"

echo "✅ MultiServiceView.jsx corregido"
echo ""

# ========== 4. CORREGIR INSTANCEDETAIL.JSX ==========
echo "[4] Corrigiendo InstanceDetail.jsx..."

INSTANCE_FILE="${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

if [ -f "$INSTANCE_FILE" ]; then
    cp "$INSTANCE_FILE" "$BACKUP_DIR/InstanceDetail.jsx.bak"
    
    # Eliminar TODOS los imports de useTimeRange
    sed -i '/import { useTimeRange/d' "$INSTANCE_FILE"
    sed -i '/TIME_RANGE_CHANGE_EVENT/d' "$INSTANCE_FILE"
    
    # Agregar UN SOLO import
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "$INSTANCE_FILE"
    
    # Agregar el hook DENTRO del componente
    sed -i '/export default function InstanceDetail({/a \ \ const range = useTimeRange();' "$INSTANCE_FILE"
    
    # Reemplazar valores fijos
    sed -i 's/60 \* 60 \* 1000/range.value/g' "$INSTANCE_FILE"
    
    echo "✅ InstanceDetail.jsx corregido"
fi
echo ""

# ========== 5. CORREGIR DASHBOARD.JSX ==========
echo "[5] Corrigiendo Dashboard.jsx..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

if [ -f "$DASHBOARD_FILE" ]; then
    cp "$DASHBOARD_FILE" "$BACKUP_DIR/Dashboard.jsx.bak"
    
    # Eliminar TODOS los imports de TimeRangeSelector
    sed -i '/import TimeRangeSelector/d' "$DASHBOARD_FILE"
    
    # Agregar UN SOLO import
    sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "$DASHBOARD_FILE"
    
    # Eliminar TODAS las instancias del selector
    sed -i '/<TimeRangeSelector/d' "$DASHBOARD_FILE"
    
    # Agregar UNA SOLA instancia ANTES del botón de notificaciones
    sed -i '/{·*Botón Notificaciones/i \                <TimeRangeSelector />' "$DASHBOARD_FILE"
    
    echo "✅ Dashboard.jsx corregido"
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
echo "✅✅ IMPORTS CORREGIDOS - SELECTOR LISTO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 📊 TimeRangeSelector: VERSIÓN ULTRA SIMPLE"
echo "   2. 🚫 MultiServiceView: IMPORTS DUPLICADOS ELIMINADOS"
echo "   3. 🚫 InstanceDetail: IMPORTS DUPLICADOS ELIMINADOS"
echo "   4. 🚫 Dashboard: IMPORTS DUPLICADOS ELIMINADOS"
echo "   5. ✅ TODOS los componentes tienen 1 SOLO import"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ DEBES VER el selector 📊 en el dashboard"
echo "   3. ✅ HAZ CLICK - debe abrir el dropdown"
echo "   4. ✅ SELECCIONA '24 horas'"
echo "   5. ✅ ENTRA a Caracas - la gráfica debe mostrar 24h"
echo "   6. ✅ Ve a 'Comparar' - debe funcionar sin errores"
echo ""
echo "📌 VERIFICACIÓN EN CONSOLA:"
echo ""
echo "   Abre F12 → Console y escribe:"
echo "   window.__TIME_RANGE  // Muestra el rango actual"
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
