#!/bin/bash
# Rollback automático para fix de IPs
BACKUP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui/backup_ip_fix_20260211_112149"
FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

echo "🔄 Restaurando backup desde: $BACKUP_DIR"
cp -r "$BACKUP_DIR"/* "$FRONTEND_DIR/" 2>/dev/null
echo "✅ Rollback completado"
echo "📁 Reinicia el frontend: cd $FRONTEND_DIR && npm run dev"
