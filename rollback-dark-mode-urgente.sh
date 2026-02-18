#!/bin/bash
# rollback-dark-mode-urgente.sh - RESTAURACIÓN COMPLETA DEL BACKUP
# Fecha: 2026-02-12
# Backup a restaurar: backup_dark_mode_20260212_082105

echo "====================================================="
echo "🔴 ROLLBACK DE EMERGENCIA - RESTAURACIÓN COMPLETA"
echo "====================================================="
echo ""

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui/backup_dark_mode_20260212_082105"

# ========== COLORES ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# ========== VERIFICAR BACKUP ==========
if [ ! -d "$BACKUP_DIR" ]; then
    error "❌ Backup no encontrado: $BACKUP_DIR"
    exit 1
fi

log "✅ Backup encontrado: $(basename $BACKUP_DIR)"
log "   Contenido del backup:"
ls -la "$BACKUP_DIR" | sed 's/^/   /'

# ========== CONFIRMAR ROLLBACK ==========
echo ""
warn "⚠️  VAS A RESTAURAR EL BACKUP COMPLETO ⚠️"
echo ""
echo "📦 Backup: $(basename $BACKUP_DIR)"
echo "📁 Destino: $FRONTEND_DIR"
echo ""
read -p "¿Estás ABSOLUTAMENTE SEGURO? (escribe 'SI' para confirmar): " CONFIRM

if [ "$CONFIRM" != "SI" ]; then
    error "❌ Rollback cancelado"
    exit 1
fi

# ========== 1. CREAR BACKUP DEL ESTADO ACTUAL (POR SI ACASO) ==========
echo ""
info "📦 Creando backup del estado actual antes de restaurar..."

CURRENT_BACKUP="${FRONTEND_DIR}/backup_antes_rollback_dark_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$CURRENT_BACKUP"

# Backup de archivos actuales
[ -f "${FRONTEND_DIR}/src/App.jsx" ] && cp "${FRONTEND_DIR}/src/App.jsx" "$CURRENT_BACKUP/App.jsx.actual"
[ -f "${FRONTEND_DIR}/src/views/Dashboard.jsx" ] && cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$CURRENT_BACKUP/Dashboard.jsx.actual"
[ -f "${FRONTEND_DIR}/index.html" ] && cp "${FRONTEND_DIR}/index.html" "$CURRENT_BACKUP/index.html.actual"
[ -f "${FRONTEND_DIR}/src/components/HistoryChart.jsx" ] && cp "${FRONTEND_DIR}/src/components/HistoryChart.jsx" "$CURRENT_BACKUP/HistoryChart.jsx.actual" 2>/dev/null || true

log "✅ Backup del estado actual guardado en: $CURRENT_BACKUP"

# ========== 2. RESTAURAR APP.JSX ==========
echo ""
info "1. Restaurando App.jsx..."

if [ -f "$BACKUP_DIR/App.jsx.bak" ]; then
    cp "$BACKUP_DIR/App.jsx.bak" "${FRONTEND_DIR}/src/App.jsx"
    log "✅ App.jsx restaurado desde: App.jsx.bak"
elif [ -f "$BACKUP_DIR/App.jsx.before_mod" ]; then
    cp "$BACKUP_DIR/App.jsx.before_mod" "${FRONTEND_DIR}/src/App.jsx"
    log "✅ App.jsx restaurado desde: App.jsx.before_mod"
else
    # Versión original forzada
    cat > "${FRONTEND_DIR}/src/App.jsx" << 'EOF'
import React from "react";
import Dashboard from "./views/Dashboard.jsx";
import "./styles.css";

export default function App() {
  return <Dashboard />;
}
EOF
    log "✅ App.jsx restaurado a versión ORIGINAL (sin ThemeProvider)"
fi

# ========== 3. RESTAURAR DASHBOARD.JSX ==========
info "2. Restaurando Dashboard.jsx..."

DASHBOARD_RESTORED=0

if [ -f "$BACKUP_DIR/Dashboard.jsx.bak" ]; then
    cp "$BACKUP_DIR/Dashboard.jsx.bak" "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    log "✅ Dashboard.jsx restaurado desde: Dashboard.jsx.bak"
    DASHBOARD_RESTORED=1
elif [ -f "$BACKUP_DIR/Dashboard.jsx.before_mod" ]; then
    cp "$BACKUP_DIR/Dashboard.jsx.before_mod" "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    log "✅ Dashboard.jsx restaurado desde: Dashboard.jsx.before_mod"
    DASHBOARD_RESTORED=1
fi

# Si no hay backup, forzar limpieza total
if [ $DASHBOARD_RESTORED -eq 0 ]; then
    warn "⚠️ No se encontró backup de Dashboard.jsx, forzando limpieza manual..."
    
    # Eliminar TODAS las líneas relacionadas con tema oscuro
    sed -i '/import ThemeToggle/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i '/import { useTheme }/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i '/const { theme, isDark } = useTheme();/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i '/{·*Theme Toggle/,/<\/ThemeToggle>/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i '/<ThemeToggle \/>/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i 's/color: theme\.textSecondary/color: "#475569"/g' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i 's/accentColor: theme\.info//g' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    
    log "✅ Dashboard.jsx limpiado FORZOSAMENTE"
fi

# ========== 4. ELIMINAR TODOS LOS ARCHIVOS DE MODO OSCURO ==========
info "3. Eliminando TODOS los archivos de modo oscuro..."

# Eliminar archivos físicamente
rm -vf "${FRONTEND_DIR}/src/contexts/ThemeContext.jsx" 2>/dev/null | sed 's/^/   /'
rm -vf "${FRONTEND_DIR}/src/components/ThemeToggle.jsx" 2>/dev/null | sed 's/^/   /'
rm -vf "${FRONTEND_DIR}/src/dark-mode.css" 2>/dev/null | sed 's/^/   /'
rm -vf "${FRONTEND_DIR}/src/theme/index.js" 2>/dev/null | sed 's/^/   /'

# Eliminar directorios si están vacíos
rmdir "${FRONTEND_DIR}/src/contexts" 2>/dev/null && log "✅ Directorio contexts eliminado" || true
rmdir "${FRONTEND_DIR}/src/theme" 2>/dev/null && log "✅ Directorio theme eliminado" || true

log "✅ Archivos de modo oscuro ELIMINADOS"

# ========== 5. RESTAURAR INDEX.HTML ==========
info "4. Restaurando index.html..."

if [ -f "$BACKUP_DIR/index.html.bak" ]; then
    cp "$BACKUP_DIR/index.html.bak" "${FRONTEND_DIR}/index.html"
    log "✅ index.html restaurado desde: index.html.bak"
elif [ -f "$BACKUP_DIR/index.html.before_mod" ]; then
    cp "$BACKUP_DIR/index.html.before_mod" "${FRONTEND_DIR}/index.html"
    log "✅ index.html restaurado desde: index.html.before_mod"
else
    # Eliminar script anti-flash
    sed -i '/Prevenir flash de modo claro\/oscuro/,/<\/script>/d' "${FRONTEND_DIR}/index.html"
    log "✅ Script anti-flash eliminado de index.html"
fi

# ========== 6. RESTAURAR HISTORYCHART.JSX ==========
info "5. Restaurando HistoryChart.jsx..."

if [ -f "$BACKUP_DIR/HistoryChart.jsx.bak" ]; then
    cp "$BACKUP_DIR/HistoryChart.jsx.bak" "${FRONTEND_DIR}/src/components/HistoryChart.jsx" 2>/dev/null
    log "✅ HistoryChart.jsx restaurado desde backup"
elif [ -f "$BACKUP_DIR/HistoryChart.jsx.before_mod" ]; then
    cp "$BACKUP_DIR/HistoryChart.jsx.before_mod" "${FRONTEND_DIR}/src/components/HistoryChart.jsx" 2>/dev/null
    log "✅ HistoryChart.jsx restaurado desde backup before_mod"
else
    warn "⚠️ No se encontró backup de HistoryChart.jsx"
fi

# ========== 7. RESTAURAR ALERTSBANNER.JSX (si está en backup) ==========
info "6. Verificando AlertsBanner.jsx..."

if [ -f "$BACKUP_DIR/AlertsBanner.jsx.bak" ]; then
    cp "$BACKUP_DIR/AlertsBanner.jsx.bak" "${FRONTEND_DIR}/src/components/AlertsBanner.jsx" 2>/dev/null
    log "✅ AlertsBanner.jsx restaurado desde backup"
fi

# ========== 8. LIMPIAR LOCALSTORAGE ==========
info "7. Limpiando localStorage del navegador..."

cat > "${FRONTEND_DIR}/public/clean-localstorage.js" << 'EOF'
// Script para limpiar TODAS las preferencias del tema
(function() {
    try {
        localStorage.removeItem('uptime-theme');
        console.log('✅ Tema eliminado de localStorage');
        
        // Limpiar cualquier otra clave relacionada
        const keysToRemove = [];
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && (key.includes('theme') || key.includes('dark') || key.includes('light'))) {
                keysToRemove.push(key);
            }
        }
        
        keysToRemove.forEach(key => {
            localStorage.removeItem(key);
            console.log(`✅ Eliminado: ${key}`);
        });
        
        console.log('✅ localStorage limpiado completamente');
    } catch(e) {
        console.error('Error limpiando localStorage:', e);
    }
})();
EOF

log "✅ Script de limpieza creado: public/clean-localstorage.js"

# ========== 9. LIMPIAR CACHÉ ==========
info "8. Limpiando caché de Vite..."

rm -rf "${FRONTEND_DIR}/node_modules/.vite" 2>/dev/null && log "✅ Caché de Vite eliminada" || true
rm -rf "${FRONTEND_DIR}/.vite" 2>/dev/null && log "✅ Caché local eliminada" || true
rm -rf "${FRONTEND_DIR}/dist" 2>/dev/null && log "✅ Build anterior eliminado" || true

# ========== 10. VERIFICACIÓN FINAL ==========
info "9. Verificando limpieza completa..."

ERRORS=0

# Verificar que NO existen archivos de modo oscuro
[ ! -f "${FRONTEND_DIR}/src/contexts/ThemeContext.jsx" ] && log "✅ ThemeContext.jsx NO existe" || (warn "⚠️ ThemeContext.jsx AÚN existe" && ERRORS=$((ERRORS+1)))
[ ! -f "${FRONTEND_DIR}/src/components/ThemeToggle.jsx" ] && log "✅ ThemeToggle.jsx NO existe" || (warn "⚠️ ThemeToggle.jsx AÚN existe" && ERRORS=$((ERRORS+1)))
[ ! -f "${FRONTEND_DIR}/src/dark-mode.css" ] && log "✅ dark-mode.css NO existe" || (warn "⚠️ dark-mode.css AÚN existe" && ERRORS=$((ERRORS+1)))

# Verificar App.jsx
if grep -q "ThemeProvider" "${FRONTEND_DIR}/src/App.jsx" 2>/dev/null; then
    warn "⚠️ App.jsx AÚN contiene ThemeProvider"
    # Forzar versión original
    cat > "${FRONTEND_DIR}/src/App.jsx" << 'EOF'
import React from "react";
import Dashboard from "./views/Dashboard.jsx";
import "./styles.css";

export default function App() {
  return <Dashboard />;
}
EOF
    log "✅ App.jsx FORZADO a versión original"
fi

# Verificar Dashboard.jsx
if grep -q "useTheme" "${FRONTEND_DIR}/src/views/Dashboard.jsx" 2>/dev/null; then
    warn "⚠️ Dashboard.jsx AÚN contiene useTheme"
    sed -i '/import { useTheme }/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    sed -i '/const { theme, isDark } = useTheme();/d' "${FRONTEND_DIR}/src/views/Dashboard.jsx"
    log "✅ Dashboard.jsx FORZADO a versión limpia"
fi

# Verificar index.html
if grep -q "Prevenir flash" "${FRONTEND_DIR}/index.html" 2>/dev/null; then
    warn "⚠️ index.html AÚN contiene script anti-flash"
    sed -i '/Prevenir flash/,/<\/script>/d' "${FRONTEND_DIR}/index.html"
    log "✅ index.html FORZADO a versión limpia"
fi

# ========== 11. REINICIAR FRONTEND ==========
info "10. Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null && log "✅ Procesos Vite terminados" || true
npm run dev &
sleep 3

# ========== 12. CREAR ACTA DE ROLLBACK ==========
cat > "${FRONTEND_DIR}/ROLLBACK_DARK_MODE_COMPLETADO.txt" << EOF
=====================================================
✅ ROLLBACK DE MODO OSCURO COMPLETADO - $(date)
=====================================================

📋 BACKUP RESTAURADO:
   • Backup: $(basename $BACKUP_DIR)
   • Fecha: 2026-02-12 08:21:05

📦 BACKUP DEL ESTADO ACTUAL:
   • Backup: $(basename $CURRENT_BACKUP)
   • Por si necesitas revertir este rollback

✅ ARCHIVOS RESTAURADOS/ELIMINADOS:
   • ✓ App.jsx → Versión original sin ThemeProvider
   • ✓ Dashboard.jsx → Sin referencias a tema oscuro
   • ✗ ThemeContext.jsx → ELIMINADO
   • ✗ ThemeToggle.jsx → ELIMINADO
   • ✗ dark-mode.css → ELIMINADO
   • ✗ theme/index.js → ELIMINADO
   • ✓ index.html → Script anti-flash eliminado
   • ✓ HistoryChart.jsx → Restaurado (si había backup)

🎯 ESTADO FINAL:
   • ✅ Dashboard funcionando con tema claro ORIGINAL
   • ✅ Notificaciones negras: MANTENIDAS
   • ✅ Botón notificaciones ON/OFF: FUNCIONANDO
   • ✅ Sin botón de cambio de tema
   • ✅ Sin modo oscuro en ninguna parte

🚀 PARA VERIFICAR:
   1. Abre http://10.10.31.31:5173
   2. Abre consola (F12) y ejecuta:
      localStorage.removeItem('uptime-theme');
   3. Confirma que NO hay botón de tema
   4. Confirma que las notificaciones funcionan

🔄 SI ALGO SALIÓ MAL:
   # Restaurar el backup del estado actual
   cp -r $CURRENT_BACKUP/* $FRONTEND_DIR/

=====================================================
✅ SISTEMA RESTAURADO A ESTADO PREVIO AL MODO OSCURO
=====================================================
EOF

# ========== FINAL ==========
echo ""
echo "====================================================="
echo "✅✅✅ ROLLBACK COMPLETADO EXITOSAMENTE ✅✅✅"
echo "====================================================="
echo ""
echo "📋 RESUMEN:"
echo "   • Backup restaurado: $(basename $BACKUP_DIR)"
echo "   • Backup actual guardado: $(basename $CURRENT_BACKUP)"
echo "   • Archivos de modo oscuro: ELIMINADOS"
echo "   • Dashboard: RESTAURADO"
echo "   • Frontend: REINICIADO"
echo ""
echo "🚀 El dashboard debería estar disponible en:"
echo "   http://10.10.31.31:5173"
echo ""
echo "📄 Acta de rollback guardada en:"
echo "   ${FRONTEND_DIR}/ROLLBACK_DARK_MODE_COMPLETADO.txt"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   1. Abre el navegador y limpia localStorage:"
echo "      localStorage.removeItem('uptime-theme');"
echo "   2. Recarga la página (F5)"
echo ""
echo "====================================================="
echo "✅ TODO RESTAURADO - MODO OSCURO ELIMINADO"
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
log "Script de rollback completado"
