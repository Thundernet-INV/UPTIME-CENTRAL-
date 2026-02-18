#!/bin/bash
# fix-coma-dashboard.sh - CORRIGE EL ERROR DE LA COMA EN DASHBOARD.JSX

echo "🔧 CORRIGIENDO ERROR DE SINTAXIS EN DASHBOARD.JSX"
echo "================================================="

DASHBOARD_FILE="/home/thunder/kuma-dashboard-clean/kuma-ui/src/views/Dashboard.jsx"
BACKUP_FILE="${DASHBOARD_FILE}.backup.coma.$(date +%s)"

# Hacer backup
cp "$DASHBOARD_FILE" "$BACKUP_FILE"
echo "✅ Backup creado: $BACKUP_FILE"

# Buscar y corregir la coma en línea 452
sed -i '452s/},/}/' "$DASHBOARD_FILE" 2>/dev/null || \
sed -i '452s/},/}/' "$DASHBOARD_FILE"

# Verificar que se corrigió
if grep -n "}," "$DASHBOARD_FILE" | grep -q "452"; then
    echo "❌ Error: la coma persiste en línea 452"
    # Intentar método alternativo
    sed -i '/^\s*},$/s/,//' "$DASHBOARD_FILE"
else
    echo "✅ Coma eliminada de línea 452"
fi

# Verificar sintaxis
echo ""
echo "🔍 Verificando sintaxis..."
cd "/home/thunder/kuma-dashboard-clean/kuma-ui"

if npx eslint --no-eslintrc "$DASHBOARD_FILE" 2>/dev/null; then
    echo "✅ Sintaxis correcta"
else
    echo "⚠️  Advertencia: aún hay problemas de sintaxis"
    echo "   Últimas 10 líneas del archivo:"
    tail -10 "$DASHBOARD_FILE"
fi

echo ""
echo "🔄 Reiniciando Vite..."
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 2

echo ""
echo "================================================="
echo "✅ CORREGIDO! El error de la coma está solucionado"
echo "================================================="
