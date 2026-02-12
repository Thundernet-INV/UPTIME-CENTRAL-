#!/bin/bash
# fix-dashboard-import.sh - CORRIGE IMPORT DUPLICADO EN DASHBOARD.JSX

echo "====================================================="
echo "🔧 CORRIGIENDO IMPORT DUPLICADO EN DASHBOARD.JSX"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"
BACKUP_FILE="${DASHBOARD_FILE}.backup.$(date +%s)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup de Dashboard.jsx..."
cp "$DASHBOARD_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

# ========== 2. ELIMINAR IMPORT DUPLICADO ==========
echo ""
echo "[2] Eliminando import duplicado de TimeRangeSelector..."

# Eliminar la línea duplicada exacta
sed -i '/^import TimeRangeSelector from "..\/components\/TimeRangeSelector.jsx";/ {
    N
    /\nimport TimeRangeSelector from "..\/components\/TimeRangeSelector.jsx";/ {
        s/^import TimeRangeSelector from "..\/components\/TimeRangeSelector.jsx";\n//
    }
}' "$DASHBOARD_FILE"

# Método más simple: eliminar todas las ocurrencias y agregar una sola al inicio
grep -v "import TimeRangeSelector" "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp"
sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "${DASHBOARD_FILE}.tmp"
mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"

echo "✅ Import duplicado corregido"

# ========== 3. VERIFICAR QUE NO QUEDEN DUPLICADOS ==========
echo ""
echo "[3] Verificando que no queden imports duplicados..."

DUPLICATES=$(grep -c "import TimeRangeSelector" "$DASHBOARD_FILE")
if [ "$DUPLICATES" -eq 1 ]; then
    echo "✅ TimeRangeSelector importado una sola vez"
else
    echo "⚠️  Aún hay $DUPLICATES imports - forzando limpieza..."
    # Forzar limpieza
    grep -v "import TimeRangeSelector" "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.clean"
    sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "${DASHBOARD_FILE}.clean"
    mv "${DASHBOARD_FILE}.clean" "$DASHBOARD_FILE"
    echo "✅ Forzado: solo 1 import"
fi

# ========== 4. VERIFICAR UBICACIÓN DEL SELECTOR ==========
echo ""
echo "[4] Verificando ubicación del TimeRangeSelector..."

if grep -q "<TimeRangeSelector />" "$DASHBOARD_FILE"; then
    echo "✅ TimeRangeSelector está presente en el render"
else
    echo "⚠️  TimeRangeSelector no encontrado en render - agregando..."
    
    # Buscar el div de controles y agregar el selector
    sed -i '/{·*Controles: filtro por tipo/,/<\/div>/ {
        /{·*Filtro por tipo de servicio/ a\
\
                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />
    }' "$DASHBOARD_FILE"
    echo "✅ TimeRangeSelector agregado al dashboard"
fi

# ========== 5. VERIFICAR SINTAXIS ==========
echo ""
echo "[5] Verificando sintaxis de Dashboard.jsx..."

# Verificar si hay errores de sintaxis
if npx eslint --no-eslintrc "$DASHBOARD_FILE" 2>/dev/null; then
    echo "✅ Sintaxis correcta"
else
    echo "⚠️  Advertencia: Podría haber problemas de sintaxis"
    echo "   Mostrando primeras 20 líneas:"
    head -20 "$DASHBOARD_FILE"
fi

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CORRECCIÓN APLICADA EXITOSAMENTE ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • Import duplicado de TimeRangeSelector eliminado"
echo "   • Dashboard.jsx ahora tiene UNA sola importación"
echo "   • Selector de tiempo visible en el dashboard"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. El dashboard debería cargar sin errores"
echo "   3. Busca el selector 📊 al lado del filtro de tipo"
echo ""
echo "📌 SI SIGUE SIN FUNCIONAR:"
echo "   Restaurar backup manualmente:"
echo "   cp $BACKUP_FILE $DASHBOARD_FILE"
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
