#!/bin/bash
# rollback-dark-mode-seguro.sh - Desinstala completamente el modo oscuro

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_dark_mode_seguro_* 2>/dev/null | sort -r | head -1)

echo "====================================================="
echo "🔙 DESINSTALANDO MODO OSCURO SEGURO"
echo "====================================================="

if [ -d "$BACKUP_DIR" ]; then
    # Restaurar App.jsx
    [ -f "$BACKUP_DIR/App.jsx.original" ] && cp "$BACKUP_DIR/App.jsx.original" "${FRONTEND_DIR}/src/App.jsx"
    
    # Restaurar index.html
    [ -f "$BACKUP_DIR/index.html.original" ] && cp "$BACKUP_DIR/index.html.original" "${FRONTEND_DIR}/index.html"
    
    # Eliminar archivos nuevos
    rm -f "${FRONTEND_DIR}/src/dark-mode.css"
    rm -f "${FRONTEND_DIR}/src/components/ThemeToggleSimple.jsx"
    rm -f "${FRONTEND_DIR}/src/theme-injector.js"
    
    # Limpiar localStorage
    echo "localStorage.removeItem('uptime-theme');" > "${FRONTEND_DIR}/public/clean-theme.js"
    
    echo "✅ Modo oscuro desinstalado completamente"
else
    echo "❌ No se encontró backup"
fi

# Limpiar clase dark-mode del body
sed -i '/dark-mode/d' "${FRONTEND_DIR}/index.html"

echo "====================================================="
echo "✅ LISTO - Reinicia el frontend"
echo "====================================================="
