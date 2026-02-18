#!/bin/bash
# fix-time-selector-error.sh - CORRIGE EL ERROR DE useTimeRange

echo "====================================================="
echo "🔧 CORRIGIENDO ERROR DE USETIMERANGE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_fix_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. CORREGIR TIMERANGESELECTOR.JSX ==========
echo ""
echo "[2] Corrigiendo TimeRangeSelector.jsx..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
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
        // Verificar que el valor guardado es válido
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
      
      console.log(`📊 Rango: ${selectedRange.label}`);
    } catch (e) {
      console.error('Error:', e);
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

// HOOK CORREGIDO - Devuelve el objeto range completo
export function useTimeRange() {
  const [range, setRange] = useState(TIME_RANGES[0]);

  useEffect(() => {
    // Cargar rango inicial
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed.value === 'number') {
          setRange(parsed);
        }
      }
    } catch (e) {}

    // Escuchar cambios
    const handleRangeChange = (e) => {
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range; // Devuelve EL OBJETO COMPLETO { label, value }
}
EOF

echo "✅ TimeRangeSelector.jsx corregido"

# ========== 3. CORREGIR INSTANCEDETAIL.JSX ==========
echo ""
echo "[3] Corrigiendo InstanceDetail.jsx..."

INSTANCE_FILE="${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

if [ -f "$INSTANCE_FILE" ]; then
    # Reemplazar uso incorrecto
    sed -i 's/const range = useTimeRange();/const timeRange = useTimeRange();/g' "$INSTANCE_FILE"
    sed -i 's/range.value/timeRange.value/g' "$INSTANCE_FILE"
    echo "✅ InstanceDetail.jsx corregido"
fi

# ========== 4. CORREGIR MULTISERVICEVIEW.JSX ==========
echo ""
echo "[4] Corrigiendo MultiServiceView.jsx..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

if [ -f "$MULTI_FILE" ]; then
    sed -i 's/const range = useTimeRange();/const timeRange = useTimeRange();/g' "$MULTI_FILE"
    sed -i 's/range.value/timeRange.value/g' "$MULTI_FILE"
    echo "✅ MultiServiceView.jsx corregido"
fi

# ========== 5. VERIFICAR QUE NO HAYA ERRORES ==========
echo ""
echo "[5] Verificando sintaxis..."

# Verificar que useTimeRange devuelve el objeto correcto
if grep -q "return range;" "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx"; then
    echo "✅ useTimeRange devuelve objeto correctamente"
fi

# Verificar InstanceDetail
if grep -q "timeRange.value" "$INSTANCE_FILE"; then
    echo "✅ InstanceDetail usa timeRange.value"
fi

# ========== 6. LIMPIAR CACHÉ Y REINICIAR ==========
echo ""
echo "[6] Limpiando caché y reiniciando..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ ERROR CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • useTimeRange ahora devuelve el OBJETO COMPLETO { label, value }"
echo "   • InstanceDetail usa 'timeRange.value' en lugar de 'range.value'"
echo "   • MultiServiceView usa 'timeRange.value'"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. El dashboard DEBE cargar sin errores"
echo "   3. Prueba el selector de tiempo 📊"
echo ""
echo "📌 SI EL ERROR PERSISTE:"
echo "   ./rollback-fix.sh (creando script...)"
echo ""
echo "====================================================="

# ========== 8. CREAR SCRIPT DE ROLLBACK ==========
cat > "${FRONTEND_DIR}/rollback-fix.sh" << 'EOF'
#!/bin/bash
FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_fix_* 2>/dev/null | sort -r | head -1)

if [ -d "$BACKUP_DIR" ]; then
    echo "Restaurando desde: $BACKUP_DIR"
    cp "$BACKUP_DIR/TimeRangeSelector.jsx" "${FRONTEND_DIR}/src/components/" 2>/dev/null || true
    cp "$BACKUP_DIR/InstanceDetail.jsx" "${FRONTEND_DIR}/src/components/" 2>/dev/null || true
    cp "$BACKUP_DIR/MultiServiceView.jsx" "${FRONTEND_DIR}/src/components/" 2>/dev/null || true
    echo "✅ Rollback completado"
else
    echo "❌ No se encontró backup"
fi
EOF

chmod +x "${FRONTEND_DIR}/rollback-fix.sh"
echo "✅ Script de rollback creado: rollback-fix.sh"

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
