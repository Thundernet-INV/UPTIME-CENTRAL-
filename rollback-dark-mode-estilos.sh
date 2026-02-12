#!/bin/bash
# rollback-dark-mode-estilos.sh - REVERTIR CAMBIOS DE ESTILO DARK MODE

echo "====================================================="
echo "🔙 REVIRTIENDO CAMBIOS DE ESTILO DARK MODE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# ========== 1. BUSCAR EL ÚLTIMO BACKUP ==========
echo ""
echo "[1] Buscando backup anterior..."

LATEST_BACKUP=$(ls -d ${FRONTEND_DIR}/backup_dark_detalles_* 2>/dev/null | sort -r | head -1)

if [ -n "$LATEST_BACKUP" ]; then
    echo "✅ Backup encontrado: $LATEST_BACKUP"
else
    echo "❌ No se encontró backup"
    exit 1
fi

# ========== 2. RESTAURAR ARCHIVOS ==========
echo ""
echo "[2] Restaurando archivos originales..."

# Restaurar dark-mode.css
if [ -f "$LATEST_BACKUP/dark-mode.css" ]; then
    cp "$LATEST_BACKUP/dark-mode.css" "${FRONTEND_DIR}/src/dark-mode.css"
    echo "✅ dark-mode.css restaurado"
fi

# Restaurar SearchBar.jsx
if [ -f "$LATEST_BACKUP/SearchBar.jsx" ]; then
    cp "$LATEST_BACKUP/SearchBar.jsx" "${FRONTEND_DIR}/src/components/SearchBar.jsx"
    echo "✅ SearchBar.jsx restaurado"
fi

# Restaurar Hero.jsx
if [ -f "$LATEST_BACKUP/Hero.jsx" ]; then
    cp "$LATEST_BACKUP/Hero.jsx" "${FRONTEND_DIR}/src/components/Hero.jsx"
    echo "✅ Hero.jsx restaurado"
fi

# ========== 3. LIMPIAR CACHÉ ==========
echo ""
echo "[3] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"

# ========== 4. REINICIAR FRONTEND ==========
echo ""
echo "[4] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 5. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ ESTILOS ORIGINALES RESTAURADOS ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🎨 dark-mode.css: RESTAURADO a versión original"
echo "   2. 🔍 SearchBar.jsx: RESTAURADO a versión original"
echo "   3. 🏠 Hero.jsx: RESTAURADO a versión original"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa modo oscuro"
echo "   3. ✅ Los chips y searchbar VOLVIERON a su estilo original"
echo ""
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
