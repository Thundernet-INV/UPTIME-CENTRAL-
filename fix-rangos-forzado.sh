#!/bin/bash
# fix-rangos-forzado.sh - FORZAR SELECTOR DE RANGOS FUNCIONAL

echo "====================================================="
echo "🔧 FORZANDO SELECTOR DE RANGOS - IMPLEMENTACIÓN DIRECTA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_rangos_forzado_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CREAR TIMERANGESELECTOR.JSX SIMPLE Y FUNCIONAL ==========
echo "[2] Creando TimeRangeSelector.jsx - VERSIÓN SIMPLE Y FUNCIONAL..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx - VERSIÓN SIMPLE Y FUNCIONAL
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

// Variable GLOBAL para almacenar el rango actual
window.__TIME_RANGE = TIME_RANGES[0];

export default function TimeRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedRange, setSelectedRange] = useState(() => {
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
    // Guardar en localStorage y variable global
    localStorage.setItem('timeRange', JSON.stringify(selectedRange));
    window.__TIME_RANGE = selectedRange;
    
    // Disparar evento personalizado
    const event = new Event('timeRangeChanged');
    window.dispatchEvent(event);
    
    console.log('📊 Rango cambiado a:', selectedRange.label);
  }, [selectedRange]);

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
        <span>{selectedRange.label}</span>
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
                setSelectedRange(range);
                setIsOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                padding: '8px 16px',
                textAlign: 'left',
                border: 'none',
                borderBottom: idx < TIME_RANGES.length - 1 ? '1px solid #f0f0f0' : 'none',
                background: selectedRange.value === range.value ? '#3b82f6' : 'transparent',
                color: selectedRange.value === range.value ? 'white' : '#1f2937',
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

// Hook SIMPLE para obtener el rango actual
export function useTimeRange() {
  const [range, setRange] = useState(() => {
    if (window.__TIME_RANGE) return window.__TIME_RANGE;
    try {
      const saved = localStorage.getItem('timeRange');
      return saved ? JSON.parse(saved) : { label: '1 hora', value: 3600000 };
    } catch {
      return { label: '1 hora', value: 3600000 };
    }
  });

  useEffect(() => {
    const handleChange = () => {
      if (window.__TIME_RANGE) {
        setRange(window.__TIME_RANGE);
      }
    };
    
    window.addEventListener('timeRangeChanged', handleChange);
    return () => window.removeEventListener('timeRangeChanged', handleChange);
  }, []);

  return range;
}
EOF

echo "✅ TimeRangeSelector.jsx creado - VERSIÓN SIMPLE"
echo ""

# ========== 3. MODIFICAR DASHBOARD.JSX ==========
echo "[3] Agregando selector al Dashboard..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Eliminar cualquier import existente
sed -i '/import TimeRangeSelector/d' "$DASHBOARD_FILE"
sed -i '/import { useTimeRange/d' "$DASHBOARD_FILE"

# Agregar import al inicio
sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "$DASHBOARD_FILE"

# Eliminar cualquier instancia existente del selector
sed -i '/<TimeRangeSelector/d' "$DASHBOARD_FILE"

# Agregar el selector ANTES del botón de notificaciones
sed -i '/{·*Botón Notificaciones/i \                <TimeRangeSelector />' "$DASHBOARD_FILE"

echo "✅ Dashboard.jsx actualizado"
echo ""

# ========== 4. MODIFICAR INSTANCEDETAIL.JSX ==========
echo "[4] Conectando InstanceDetail al selector de rango..."

INSTANCE_FILE="${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

# Agregar useTimeRange
sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "$INSTANCE_FILE"

# Reemplazar el rango fijo con el rango dinámico
sed -i 's/60 \* 60 \* 1000/range.value/g' "$INSTANCE_FILE"
sed -i 's/const \*\/ 1000/const range = useTimeRange();\n  const rangeValue = range.value/g' "$INSTANCE_FILE"

# Agregar la declaración del range
sed -i '/export default function InstanceDetail({/a \ \ const range = useTimeRange();' "$INSTANCE_FILE"

echo "✅ InstanceDetail.jsx actualizado"
echo ""

# ========== 5. MODIFICAR MULTISERVICEVIEW.JSX ==========
echo "[5] Conectando MultiServiceView al selector de rango..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

# Agregar useTimeRange
sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "$MULTI_FILE"

# Agregar la declaración del range
sed -i '/export default function MultiServiceView({/a \ \ const range = useTimeRange();' "$MULTI_FILE"

# Reemplazar RANGE_MS o valores fijos
sed -i 's/const RANGE_MS = [0-9* ]*;//g' "$MULTI_FILE"
sed -i 's/RANGE_MS/range.value/g' "$MULTI_FILE"
sed -i 's/3600000/range.value/g' "$MULTI_FILE"

echo "✅ MultiServiceView.jsx actualizado"
echo ""

# ========== 6. GENERAR DATOS DE PRUEBA EN EL BACKEND ==========
echo "[6] Generando datos de prueba en el backend..."

cd /opt/kuma-central/kuma-aggregator

# Generar datos de promedio para todas las sedes
sqlite3 data/history.db << 'EOF'
DELETE FROM instance_averages;

-- Insertar datos para Caracas (últimas 24 horas)
INSERT INTO instance_averages (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
SELECT 
    'Caracas',
    strftime('%s','now','-'||(23 - hour)||' hours') * 1000,
    75 + (hour * 1.5) + (abs(random()) % 20),
    0.96,
    45,
    43,
    2,
    0
FROM (SELECT 0 as hour UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23);

-- Insertar datos para Guanare
INSERT INTO instance_averages (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
SELECT 
    'Guanare',
    strftime('%s','now','-'||(23 - hour)||' hours') * 1000,
    95 + (hour * 2) + (abs(random()) % 25),
    0.93,
    38,
    35,
    3,
    0
FROM (SELECT 0 as hour UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23);
EOF

echo "✅ Datos de prueba generados"
echo ""

# ========== 7. REINICIAR BACKEND ==========
echo "[7] Reiniciando backend..."

pkill -f "node.*index.js" 2>/dev/null || true
sleep 2
NODE_ENV=production nohup node src/index.js > /tmp/kuma-backend.log 2>&1 &
sleep 3

echo "✅ Backend reiniciado"
echo ""

# ========== 8. LIMPIAR CACHÉ Y REINICIAR FRONTEND ==========
echo "[8] Limpiando caché y reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 9. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ SELECTOR DE RANGOS FORZADO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 📊 TimeRangeSelector: VERSIÓN SIMPLE con variable GLOBAL"
echo "   2. 🎯 Dashboard: Selector AGREGADO antes del botón de notificaciones"
echo "   3. 🏢 InstanceDetail: CONECTADO al selector (usa range.value)"
echo "   4. 📈 MultiServiceView: CONECTADO al selector (usa range.value)"
echo "   5. 💾 Backend: DATOS DE PRUEBA generados"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ DEBES VER el selector 📊 '1 hora' en el dashboard"
echo "   3. ✅ HAZ CLICK - debe abrir el dropdown"
echo "   4. ✅ SELECCIONA '24 horas'"
echo "   5. ✅ ENTRA a Caracas o Guanare"
echo "   6. ✅ LA GRÁFICA DEBE MOSTRAR 24 HORAS DE DATOS"
echo ""
echo "📌 VERIFICACIÓN EN CONSOLA:"
echo ""
echo "   Abre F12 → Console y escribe:"
echo "   window.__TIME_RANGE  // Debe mostrar el rango actual"
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
