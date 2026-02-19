#!/bin/bash
# restaurar-energia-dashboard.sh
# RESTAURA LA VERSIÓN ORIGINAL DE ENERGIA DASHBOARD

echo "====================================================="
echo "🔄 RESTAURANDO VERSIÓN ORIGINAL"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"
BACKUP_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx.backup.20260219_085433"

# ========== 1. RESTAURAR BACKUP ==========
echo ""
echo "[1] Restaurando desde: $BACKUP_FILE"

if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$DASHBOARD_FILE"
    echo "✅ Archivo restaurado"
else
    echo "❌ No se encontró el backup"
    exit 1
fi

# ========== 2. VERIFICAR ==========
echo ""
echo "[2] Verificando primeras líneas:"
head -10 "$DASHBOARD_FILE"

# ========== 3. REINICIAR FRONTEND ==========
echo ""
echo "[3] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ VERSIÓN ORIGINAL RESTAURADA ✅✅"
echo "====================================================="
echo ""
