#!/bin/bash
# rollback-time-selector-completo.sh - RESTAURA TODOS LOS ARCHIVOS A ESTADO ORIGINAL

echo "====================================================="
echo "🔴 ROLLBACK COMPLETO - SELECTOR DE TIEMPO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# ========== 1. BUSCAR EL BACKUP MÁS RECIENTE ==========
echo ""
echo "[1] Buscando backup más reciente..."

LATEST_BACKUP=$(ls -d ${FRONTEND_DIR}/backup_imports_* 2>/dev/null | sort -r | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "⚠️  No se encontró backup de imports, buscando otros backups..."
    LATEST_BACKUP=$(ls -d ${FRONTEND_DIR}/backup_* 2>/dev/null | sort -r | head -1)
fi

if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ No se encontró ningún backup"
    exit 1
fi

echo "✅ Backup encontrado: $LATEST_BACKUP"

# ========== 2. RESTAURAR ARCHIVOS ==========
echo ""
echo "[2] Restaurando archivos desde backup..."

# InstanceDetail.jsx
if [ -f "$LATEST_BACKUP/InstanceDetail.jsx.bak" ]; then
    cp "$LATEST_BACKUP/InstanceDetail.jsx.bak" "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
    echo "✅ InstanceDetail.jsx restaurado"
elif [ -f "${FRONTEND_DIR}/src/components/InstanceDetail.jsx.backup" ]; then
    cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx.backup" "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
    echo "✅ InstanceDetail.jsx restaurado (backup local)"
fi

# MultiServiceView.jsx
if [ -f "$LATEST_BACKUP/MultiServiceView.jsx.bak" ]; then
    cp "$LATEST_BACKUP/MultiServiceView.jsx.bak" "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    echo "✅ MultiServiceView.jsx restaurado"
fi

# MonitorsTable.jsx
if [ -f "$LATEST_BACKUP/MonitorsTable.jsx.bak" ]; then
    cp "$LATEST_BACKUP/MonitorsTable.jsx.bak" "${FRONTEND_DIR}/src/components/MonitorsTable.jsx"
    echo "✅ MonitorsTable.jsx restaurado"
fi

# Dashboard.jsx
if [ -f "$LATEST_BACKUP/Dashboard.jsx.bak" ]; then
    cp "$LATEST_BACKUP/Dashboard.jsx.bak" "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    echo "✅ Dashboard.jsx restaurado"
fi

# ========== 3. ELIMINAR TIMERANGESELECTOR.JSX ==========
echo ""
echo "[3] Eliminando TimeRangeSelector.jsx..."

if [ -f "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" ]; then
    # Hacer backup antes de eliminar
    cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$LATEST_BACKUP/TimeRangeSelector.jsx.final"
    rm "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx"
    echo "✅ TimeRangeSelector.jsx eliminado"
fi

# ========== 4. LIMPIAR IMPORTS RESIDUALES ==========
echo ""
echo "[4] Limpiando imports residuales..."

# InstanceDetail.jsx - limpiar cualquier import de useTimeRange
if [ -f "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" ]; then
    sed -i '/import { useTimeRange }/d' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
    sed -i '/const { rangeMs, label }/d' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
    echo "✅ InstanceDetail.jsx limpiado"
fi

# MultiServiceView.jsx
if [ -f "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" ]; then
    sed -i '/import { useTimeRange }/d' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    sed -i '/const { rangeMs, label }/d' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    echo "✅ MultiServiceView.jsx limpiado"
fi

# MonitorsTable.jsx
if [ -f "${FRONTEND_DIR}/src/components/MonitorsTable.jsx" ]; then
    sed -i '/import { useTimeRange }/d' "${FRONTEND_DIR}/src/components/MonitorsTable.jsx"
    sed -i '/const { rangeMs, label }/d' "${FRONTEND_DIR}/src/components/MonitorsTable.jsx"
    echo "✅ MonitorsTable.jsx limpiado"
fi

# Dashboard.jsx - limpiar import de TimeRangeSelector
if [ -f "${FRONTEND_DIR}/src/views/Dashboard.jsx" ]; then
    sed -i '/import TimeRangeSelector/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i '/<TimeRangeSelector/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    echo "✅ Dashboard.jsx limpiado"
fi

# ========== 5. RESTAURAR HISTORYENGINE.JS ORIGINAL ==========
echo ""
echo "[5] Restaurando historyEngine.js original..."

# Buscar backup de historyEngine.js
if [ -f "${FRONTEND_DIR}/src/historyEngine.js.backup" ]; then
    cp "${FRONTEND_DIR}/src/historyEngine.js.backup" "${FRONTEND_DIR}/src/historyEngine.js"
    echo "✅ historyEngine.js restaurado desde backup"
elif [ -f "$LATEST_BACKUP/../historyEngine.js" ]; then
    cp "$LATEST_BACKUP/../historyEngine.js" "${FRONTEND_DIR}/src/historyEngine.js"
    echo "✅ historyEngine.js restaurado"
fi

# ========== 6. LIMPIAR CACHÉ ==========
echo ""
echo "[6] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite
rm -rf .vite
echo "✅ Caché limpiada"

# ========== 7. REINICIAR FRONTEND ==========
echo ""
echo "[7] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 8. VERIFICAR LIMPIEZA ==========
echo ""
echo "[8] Verificando que no queden residuos..."

ERRORS=0

# Verificar que no existen imports
grep -r "import { useTimeRange }" --include="*.jsx" "${FRONTEND_DIR}/src/components/" && echo "⚠️  Aún hay imports de useTimeRange" || echo "✅ No hay imports de useTimeRange"
grep -r "import TimeRangeSelector" --include="*.jsx" "${FRONTEND_DIR}/src/views/" && echo "⚠️  Aún hay imports de TimeRangeSelector" || echo "✅ No hay imports de TimeRangeSelector"
grep -r "<TimeRangeSelector" --include="*.jsx" "${FRONTEND_DIR}/src/views/" && echo "⚠️  Aún hay componentes TimeRangeSelector" || echo "✅ No hay componentes TimeRangeSelector"

# ========== 9. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ ROLLBACK COMPLETADO EXITOSAMENTE ✅✅"
echo "====================================================="
echo ""
echo "📋 ACCIONES REALIZADAS:"
echo "   • Archivos restaurados desde backup"
echo "   • TimeRangeSelector.jsx eliminado"
echo "   • Imports residuales limpiados"
echo "   • Caché de Vite limpiada"
echo "   • Frontend reiniciado"
echo ""
echo "🔄 ESTADO ACTUAL:"
echo "   • Dashboard SIN selector de tiempo"
echo "   • Gráficas con comportamiento ORIGINAL"
echo "   • Sin errores de imports duplicados"
echo ""
echo "📌 PRÓXIMOS PASOS:"
echo "   Cuando quieras reintentar el selector de tiempo,"
echo "   haremos una implementación LIMPIA y CONTROLADA"
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
echo "✅ Script de rollback completado"
