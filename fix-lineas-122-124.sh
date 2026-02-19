#!/bin/bash
# fix-lineas-122-124.sh
# CORRIGE LAS LÍNEAS 122-124 ESPECÍFICAMENTE

echo "====================================================="
echo "🔧 CORRIGIENDO LÍNEAS 122-124"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.final.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR LAS LÍNEAS ANTES ==========
echo ""
echo "[2] Líneas 115-125 ANTES:"
sed -n '115,125p' "$DASHBOARD_FILE"
echo ""

# ========== 3. CORREGIR LAS LÍNEAS ==========
echo ""
echo "[3] Corrigiendo líneas..."

# Reemplazar las líneas 122-124 con la versión correcta
sed -i '122c \        <div style={{ fontSize: "0.85rem", color: "#4b5563" }}>' "$DASHBOARD_FILE"
sed -i '123c \          {rt} ms' "$DASHBOARD_FILE"
sed -i '124c \        </div>' "$DASHBOARD_FILE"

echo "✅ Líneas corregidas"

# ========== 4. MOSTRAR LAS LÍNEAS DESPUÉS ==========
echo ""
echo "[4] Líneas 115-125 DESPUÉS:"
sed -n '115,125p' "$DASHBOARD_FILE"
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
echo "✅✅ LÍNEAS CORREGIDAS ✅✅"
echo "====================================================="
echo ""
