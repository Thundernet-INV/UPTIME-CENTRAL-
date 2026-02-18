#!/bin/bash
# rollback-energia.sh - RESTAURA DESDE EL BACKUP

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_energia_* 2>/dev/null | sort -r | head -1)

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ No se encontró backup"
    exit 1
fi

echo "====================================================="
echo "🔙 RESTAURANDO DESDE: $BACKUP_DIR"
echo "====================================================="

cp -r "$BACKUP_DIR/components" "${FRONTEND_DIR}/src/" 2>/dev/null
cp -r "$BACKUP_DIR/views" "${FRONTEND_DIR}/src/" 2>/dev/null

sudo fuser -k 5173/tcp 5174/tcp 5175/tcp 2>/dev/null
pkill -f "vite" 2>/dev/null

cd "$FRONTEND_DIR"
npm run dev &

echo "✅ Rollback completado"
echo "   Abre http://10.10.31.31:5173"
