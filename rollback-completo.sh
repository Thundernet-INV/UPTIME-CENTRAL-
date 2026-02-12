#!/bin/bash
# rollback-completo.sh - RESTAURA TODO A ESTADO ORIGINAL

echo "🔙 HACIENDO ROLLBACK COMPLETO"
echo "=============================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# 1. RESTAURAR DASHBOARD.JSX
echo "1. Restaurando Dashboard.jsx..."
if [ -f "$FRONTEND_DIR/src/views/Dashboard.jsx.backup.boton" ]; then
    cp "$FRONTEND_DIR/src/views/Dashboard.jsx.backup.boton" "$FRONTEND_DIR/src/views/Dashboard.jsx"
    echo "   ✅ Restaurado: Dashboard.jsx.backup.boton"
elif [ -f "$FRONTEND_DIR/src/views/Dashboard.jsx.backup" ]; then
    cp "$FRONTEND_DIR/src/views/Dashboard.jsx.backup" "$FRONTEND_DIR/src/views/Dashboard.jsx"
    echo "   ✅ Restaurado: Dashboard.jsx.backup"
else
    echo "   ⚠️ No se encontró backup, buscando en carpetas de backup..."
    # Buscar en carpetas de backup
    LATEST_BACKUP=$(ls -d "$FRONTEND_DIR"/backup_* 2>/dev/null | sort -r | head -1)
    if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP/Dashboard.jsx.bak" ]; then
        cp "$LATEST_BACKUP/Dashboard.jsx.bak" "$FRONTEND_DIR/src/views/Dashboard.jsx"
        echo "   ✅ Restaurado desde: $LATEST_BACKUP"
    fi
fi

# 2. RESTAURAR ALERTSBANNER.JSX
echo "2. Restaurando AlertsBanner.jsx..."
if [ -f "$FRONTEND_DIR/src/components/AlertsBanner.jsx.backup" ]; then
    cp "$FRONTEND_DIR/src/components/AlertsBanner.jsx.backup" "$FRONTEND_DIR/src/components/AlertsBanner.jsx"
    echo "   ✅ Restaurado: AlertsBanner.jsx.backup"
else
    # Si no hay backup, crear versión vacía (como estaba originalmente)
    cat > "$FRONTEND_DIR/src/components/AlertsBanner.jsx" << 'EOF'
export default function AlertsBanner(){ return null; }
EOF
    echo "   ✅ Restaurado a versión vacía (return null)"
fi

# 3. ELIMINAR window.__dashboard DEL DASHBOARD
echo "3. Eliminando window.__dashboard..."
sed -i '/\/\/ ============================================/,/\/\/ ============================================/d' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i '/window\.__dashboard/d' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i '/__dashboard/d' "$FRONTEND_DIR/src/views/Dashboard.jsx"

# 4. RESTAURAR UMBRALES ORIGINALES
echo "4. Restaurando umbrales originales..."
sed -i 's/const DELTA_ALERT_MS = 20;/const DELTA_ALERT_MS = 100;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_ALERT_MS = 10;/const DELTA_ALERT_MS = 100;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_COOLDOWN_MS = 10 \* 1000;/const DELTA_COOLDOWN_MS = 60 \* 1000;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_COOLDOWN_MS = 5000;/const DELTA_COOLDOWN_MS = 60 \* 1000;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_WINDOW = 5;/const DELTA_WINDOW = 20;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"
sed -i 's/const DELTA_WINDOW = 3;/const DELTA_WINDOW = 20;/g' "$FRONTEND_DIR/src/views/Dashboard.jsx"

# 5. LIMPIAR CACHÉ DEL NAVEGADOR (sugerencia)
echo "5. Limpiando caché..."
rm -rf "$FRONTEND_DIR/node_modules/.vite" 2>/dev/null

echo ""
echo "=============================="
echo "✅ ROLLBACK COMPLETADO"
echo "=============================="
echo ""
echo "🔄 Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3
echo ""
echo "📋 TODO RESTAURADO A ESTADO ORIGINAL:"
echo "   • Dashboard.jsx → backup"
echo "   • AlertsBanner.jsx → return null"
echo "   • window.__dashboard → eliminado"
echo "   • Umbrales → 100ms, 60s, 20 muestras"
echo ""
echo "✅ Las notificaciones push han sido DESACTIVADAS"
echo "=============================="
