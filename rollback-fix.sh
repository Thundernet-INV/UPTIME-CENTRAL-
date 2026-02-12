#!/bin/bash
FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_fix_* 2>/dev/null | sort -r | head -1)

if [ -d "$BACKUP_DIR" ]; then
    echo "Restaurando desde: $BACKUP_DIR"
    cp "$BACKUP_DIR/TimeRangeSelector.jsx" "${FRONTEND_DIR}/src/components/" 2>/dev/null || true
    cp "$BACKUP_DIR/InstanceDetail.jsx" "${FRONTEND_DIR}/src/components/" 2>/dev/null || true
    cp "$BACKUP_DIR/MultiServiceView.jsx" "${FRONTEND_DIR}/src/components/" 2>/dev/null || true
    echo "✅ Rollback completado"
else
    echo "❌ No se encontró backup"
fi
