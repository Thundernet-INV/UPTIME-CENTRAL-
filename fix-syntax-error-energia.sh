#!/bin/bash
# fix-syntax-error-energia.sh
# CORRIGE EL ERROR DE SINTAXIS EN ENERGIA DASHBOARD

echo "====================================================="
echo "🔧 CORRIGIENDO ERROR DE SINTAXIS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.syntax.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR LA LÍNEA PROBLEMÁTICA ==========
echo ""
echo "[2] Línea con error (alrededor de la 375):"
sed -n '370,380p' "$DASHBOARD_FILE"
echo ""

# ========== 3. CORREGIR EL ERROR ==========
echo ""
echo "[3] Eliminando la 'n' intrusa..."

# Eliminar la 'n' antes del comentario
sed -i '375s/^n//' "$DASHBOARD_FILE"

echo "✅ Error corregido"

# ========== 4. VERIFICAR LA CORRECCIÓN ==========
echo ""
echo "[4] Líneas después de la corrección:"
sed -n '370,380p' "$DASHBOARD_FILE"
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
echo "✅✅ ERROR DE SINTAXIS CORREGIDO ✅✅"
echo "====================================================="
echo ""
