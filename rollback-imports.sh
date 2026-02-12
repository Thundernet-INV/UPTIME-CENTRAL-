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
