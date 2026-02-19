#!/bin/bash
# fix-lineas-213.sh
# CORRIGE LAS LÍNEAS 213-216 MANUALMENTE

echo "====================================================="
echo "🔧 CORRIGIENDO LÍNEAS 213-216"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.lineas.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR LAS LÍNEAS ACTUALES ==========
echo ""
echo "[2] Líneas 210-220 actuales:"
sed -n '210,220p' "$DASHBOARD_FILE"
echo ""

# ========== 3. ELIMINAR LAS LÍNEAS PROBLEMÁTICAS ==========
echo ""
echo "[3] Eliminando líneas problemáticas..."

# Eliminar líneas 213-216
sed -i '213,216d' "$DASHBOARD_FILE"

echo "✅ Líneas eliminadas"

# ========== 4. VERIFICAR DESPUÉS DE ELIMINAR ==========
echo ""
echo "[4] Líneas 210-220 después de eliminar:"
sed -n '210,220p' "$DASHBOARD_FILE"
echo ""

# ========== 5. REINICIAR FRONTEND ==========
echo ""
echo "[5] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ LÍNEAS PROBLEMÁTICAS ELIMINADAS ✅✅"
echo "====================================================="
echo ""
