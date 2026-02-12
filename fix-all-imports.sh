#!/bin/bash
# fix-all-imports.sh - CORRIGE TODOS LOS IMPORTS DUPLICADOS

echo "====================================================="
echo "🔧 CORRIGIENDO TODOS LOS IMPORTS DUPLICADOS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_imports_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP COMPLETO ==========
echo ""
echo "[1] Creando backup completo de componentes modificados..."
mkdir -p "$BACKUP_DIR"

cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/MonitorsTable.jsx" "$BACKUP_DIR/" 2>/dev/null || true

echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. CORREGIR MULTISERVICEVIEW.JSX ==========
echo ""
echo "[2] Corrigiendo MultiServiceView.jsx..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

if [ -f "$MULTI_FILE" ]; then
    # Backup específico
    cp "$MULTI_FILE" "$BACKUP_DIR/MultiServiceView.jsx.bak"
    
    # Eliminar TODAS las líneas con import useTimeRange
    grep -v "import { useTimeRange }" "$MULTI_FILE" > "${MULTI_FILE}.tmp"
    
    # Agregar UNA sola línea al inicio
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${MULTI_FILE}.tmp"
    
    # Verificar que no hay duplicados de React import
    grep -v "import React, { useEffect, useMemo, useRef, useState }" "${MULTI_FILE}.tmp" > "${MULTI_FILE}.tmp2"
    sed -i '1iimport React, { useEffect, useMemo, useRef, useState } from "react";' "${MULTI_FILE}.tmp2"
    
    # Mover archivo final
    mv "${MULTI_FILE}.tmp2" "$MULTI_FILE"
    rm -f "${MULTI_FILE}.tmp" 2>/dev/null
    
    echo "✅ MultiServiceView.jsx corregido"
else
    echo "⚠️  MultiServiceView.jsx no encontrado"
fi

# ========== 3. CORREGIR INSTANCEDETAIL.JSX ==========
echo ""
echo "[3] Corrigiendo InstanceDetail.jsx..."

INSTANCE_FILE="${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

if [ -f "$INSTANCE_FILE" ]; then
    cp "$INSTANCE_FILE" "$BACKUP_DIR/InstanceDetail.jsx.bak"
    
    # Eliminar TODAS las líneas con import useTimeRange
    grep -v "import { useTimeRange }" "$INSTANCE_FILE" > "${INSTANCE_FILE}.tmp"
    
    # Agregar UNA sola línea al inicio
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${INSTANCE_FILE}.tmp"
    
    mv "${INSTANCE_FILE}.tmp" "$INSTANCE_FILE"
    echo "✅ InstanceDetail.jsx corregido"
else
    echo "⚠️  InstanceDetail.jsx no encontrado"
fi

# ========== 4. CORREGIR MONITORSTABLE.JSX ==========
echo ""
echo "[4] Corrigiendo MonitorsTable.jsx..."

TABLE_FILE="${FRONTEND_DIR}/src/components/MonitorsTable.jsx"

if [ -f "$TABLE_FILE" ]; then
    cp "$TABLE_FILE" "$BACKUP_DIR/MonitorsTable.jsx.bak"
    
    # Eliminar TODAS las líneas con import useTimeRange
    grep -v "import { useTimeRange }" "$TABLE_FILE" > "${TABLE_FILE}.tmp"
    
    # Agregar UNA sola línea al inicio
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${TABLE_FILE}.tmp"
    
    mv "${TABLE_FILE}.tmp" "$TABLE_FILE"
    echo "✅ MonitorsTable.jsx corregido"
else
    echo "⚠️  MonitorsTable.jsx no encontrado"
fi

# ========== 5. CORREGIR DASHBOARD.JSX ==========
echo ""
echo "[5] Corrigiendo Dashboard.jsx..."

DASH_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

if [ -f "$DASH_FILE" ]; then
    cp "$DASH_FILE" "$BACKUP_DIR/Dashboard.jsx.bak"
    
    # Eliminar TODAS las líneas con import TimeRangeSelector
    grep -v "import TimeRangeSelector" "$DASH_FILE" > "${DASH_FILE}.tmp"
    
    # Agregar UNA sola línea al inicio
    sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "${DASH_FILE}.tmp"
    
    mv "${DASH_FILE}.tmp" "$DASH_FILE"
    echo "✅ Dashboard.jsx corregido"
fi

# ========== 6. CORREGIR TIMERANGESELECTOR.JSX ==========
echo ""
echo "[6] Verificando TimeRangeSelector.jsx..."

TIMERANGE_FILE="${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx"

if [ -f "$TIMERANGE_FILE" ]; then
    # Asegurar que exporta correctamente
    if ! grep -q "export function useTimeRange" "$TIMERANGE_FILE"; then
        echo "⚠️  TimeRangeSelector.jsx no exporta useTimeRange correctamente"
        
        cp "$TIMERANGE_FILE" "$BACKUP_DIR/TimeRangeSelector.jsx.bak"
        
        # Agregar export faltante
        sed -i '/export default function TimeRangeSelector/,/}/ {
            /}$/ a\
\
// Hook personalizado para usar el rango de tiempo\
export function useTimeRange(defaultRangeMs = 60 * 60 * 1000) {\
  const [rangeMs, setRangeMs] = useState(defaultRangeMs);\
  const [label, setLabel] = useState("Última 1 hora");\
\
  useEffect(() => {\
    const handleRangeChange = (e) => {\
      setRangeMs(e.detail.rangeMs);\
      setLabel(e.detail.label);\
    };\
    window.addEventListener("time-range-changed", handleRangeChange);\
    return () => window.removeEventListener("time-range-changed", handleRangeChange);\
  }, []);\
\
  return { rangeMs, label };\
}
        ' "$TIMERANGE_FILE"
        
        echo "✅ TimeRangeSelector.jsx actualizado"
    else
        echo "✅ TimeRangeSelector.jsx OK"
    fi
fi

# ========== 7. LIMPIAR CACHÉ DE VITE ==========
echo ""
echo "[7] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite 2>/dev/null || true
rm -rf .vite 2>/dev/null || true

echo "✅ Caché limpiada"

# ========== 8. VERIFICAR QUE NO QUEDEN DUPLICADOS ==========
echo ""
echo "[8] Verificando que no queden imports duplicados..."

ERRORS=0

# Verificar MultiServiceView
if [ -f "$MULTI_FILE" ]; then
    COUNT=$(grep -c "import { useTimeRange }" "$MULTI_FILE" 2>/dev/null || echo 0)
    if [ "$COUNT" -eq 1 ]; then
        echo "✅ MultiServiceView.jsx: OK (1 import)"
    else
        echo "⚠️  MultiServiceView.jsx: $COUNT imports"
        ERRORS=$((ERRORS+1))
    fi
fi

# Verificar InstanceDetail
if [ -f "$INSTANCE_FILE" ]; then
    COUNT=$(grep -c "import { useTimeRange }" "$INSTANCE_FILE" 2>/dev/null || echo 0)
    if [ "$COUNT" -eq 1 ]; then
        echo "✅ InstanceDetail.jsx: OK (1 import)"
    else
        echo "⚠️  InstanceDetail.jsx: $COUNT imports"
        ERRORS=$((ERRORS+1))
    fi
fi

# Verificar MonitorsTable
if [ -f "$TABLE_FILE" ]; then
    COUNT=$(grep -c "import { useTimeRange }" "$TABLE_FILE" 2>/dev/null || echo 0)
    if [ "$COUNT" -eq 1 ]; then
        echo "✅ MonitorsTable.jsx: OK (1 import)"
    else
        echo "⚠️  MonitorsTable.jsx: $COUNT imports"
        ERRORS=$((ERRORS+1))
    fi
fi

# Verificar Dashboard
if [ -f "$DASH_FILE" ]; then
    COUNT=$(grep -c "import TimeRangeSelector" "$DASH_FILE" 2>/dev/null || echo 0)
    if [ "$COUNT" -eq 1 ]; then
        echo "✅ Dashboard.jsx: OK (1 import)"
    else
        echo "⚠️  Dashboard.jsx: $COUNT imports"
        ERRORS=$((ERRORS+1))
    fi
fi

# ========== 9. REINICIAR FRONTEND ==========
echo ""
echo "[9] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 10. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ TODOS LOS IMPORTS CORREGIDOS ✅✅"
echo "====================================================="
echo ""
echo "📋 ARCHIVOS CORREGIDOS:"
echo "   • Dashboard.jsx - TimeRangeSelector"
echo "   • MultiServiceView.jsx - useTimeRange"
echo "   • InstanceDetail.jsx - useTimeRange"
echo "   • MonitorsTable.jsx - useTimeRange"
echo ""
echo "📦 BACKUP COMPLETO:"
echo "   $BACKUP_DIR"
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ VERIFICACIÓN: TODOS LOS IMPORTS CORRECTOS"
else
    echo "⚠️  VERIFICACIÓN: $ERRORS archivos con problemas"
fi
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. El dashboard debe cargar SIN ERRORES"
echo "   3. Prueba el selector de tiempo 📊"
echo "   4. Navega a una sede y a comparar servicios"
echo ""
echo "📌 SI PERSISTEN ERRORES:"
echo "   ./rollback-imports.sh (crearemos este script ahora)"
echo ""
echo "====================================================="

# ========== 11. CREAR SCRIPT DE ROLLBACK ==========
cat > "${FRONTEND_DIR}/rollback-imports.sh" << 'EOF'
#!/bin/bash
# rollback-imports.sh - RESTAURA TODOS LOS ARCHIVOS DESDE EL BACKUP

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_imports_* 2>/dev/null | sort -r | head -1)

if [ -d "$BACKUP_DIR" ]; then
    echo "Restaurando desde: $BACKUP_DIR"
    cp "$BACKUP_DIR/Dashboard.jsx.bak" "${FRONTEND_DIR}/src/views/Dashboard.jsx" 2>/dev/null || true
    cp "$BACKUP_DIR/MultiServiceView.jsx.bak" "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" 2>/dev/null || true
    cp "$BACKUP_DIR/InstanceDetail.jsx.bak" "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" 2>/dev/null || true
    cp "$BACKUP_DIR/MonitorsTable.jsx.bak" "${FRONTEND_DIR}/src/components/MonitorsTable.jsx" 2>/dev/null || true
    echo "✅ Rollback completado"
else
    echo "❌ No se encontró backup"
fi
EOF

chmod +x "${FRONTEND_DIR}/rollback-imports.sh"
echo "✅ Script de rollback creado: rollback-imports.sh"

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
