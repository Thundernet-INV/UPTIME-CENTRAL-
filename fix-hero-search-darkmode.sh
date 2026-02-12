#!/bin/bash
# fix-hero-search-darkmode.sh - ESTILO OSCURO PARA HERO SEARCH

echo "====================================================="
echo "🌙 APLICANDO ESTILO OSCURO AL HERO SEARCH"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_hero_search_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. APLICAR ESTILO AL HERO SEARCH EN MODO OSCURO ==========
echo "[2] Aplicando estilo oscuro al hero search..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== HERO SEARCH - MODO OSCURO ========== */
body.dark-mode .hero-search {
  display: flex !important;
  align-items: center !important;
  background: #000000 !important;
  border-radius: 999px !important;
  padding: 4px !important;
  width: 100% !important;
  max-width: 560px !important;
  margin: 0 auto !important;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.5), 0 2px 4px -1px rgba(0, 0, 0, 0.3) !important;
  overflow: hidden !important;
}

/* Ajustar los inputs dentro del hero search en modo oscuro */
body.dark-mode .hero-search .hero-search-input {
  background: transparent !important;
  border: none !important;
  color: #ffffff !important;
  height: 44px !important;
  padding: 0 16px !important;
  font-size: 0.95rem !important;
  flex: 1 !important;
}

body.dark-mode .hero-search .hero-search-input::placeholder {
  color: #9ca3af !important;
}

body.dark-mode .hero-search .hero-search-input:focus {
  outline: none !important;
  box-shadow: none !important;
}

body.dark-mode .hero-search .hero-search-button {
  background: transparent !important;
  border: none !important;
  color: #ffffff !important;
  height: 44px !important;
  padding: 0 24px !important;
  font-size: 0.95rem !important;
  font-weight: 500 !important;
  border-radius: 999px !important;
  transition: all 0.2s ease !important;
  margin: 0 !important;
}

body.dark-mode .hero-search .hero-search-button:hover {
  background: rgba(255, 255, 255, 0.1) !important;
}

/* Eliminar bordes redundantes */
body.dark-mode .hero-search .hero-search-input {
  border-right: none !important;
}

body.dark-mode .hero-search .hero-search-button {
  border-left: none !important;
}
EOF

echo "✅ Estilo oscuro aplicado al hero search"
echo ""

# ========== 3. LIMPIAR CACHÉ ==========
echo "[3] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 4. REINICIAR FRONTEND ==========
echo "[4] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 5. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ ESTILO OSCURO APLICADO AL HERO SEARCH ✅✅"
echo "====================================================="
echo ""
echo "📋 ESTILO APLICADO (SOLO MODO OSCURO):"
echo ""
echo "   .hero-search {"
echo "     display: flex;"
echo "     align-items: center;"
echo "     background: #000000;"
echo "     border-radius: 999px;"
echo "     padding: 4px;"
echo "     width: 100%;"
echo "     max-width: 560px;"
echo "     margin: 0 auto;"
echo "     box-shadow: 0 4px 6px -1px rgba(0,0,0,0.5);"
echo "     overflow: hidden;"
echo "   }"
echo ""
echo "   .hero-search-input {"
echo "     background: transparent;"
echo "     border: none;"
echo "     color: #ffffff;"
echo "   }"
echo ""
echo "   .hero-search-button {"
echo "     background: transparent;"
echo "     border: none;"
echo "     color: #ffffff;"
echo "   }"
echo ""
echo "   .hero-search-button:hover {"
echo "     background: rgba(255,255,255,0.1);"
echo "   }"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa modo oscuro (botón 🌙)"
echo "   3. ✅ HERO SEARCH: Fondo NEGRO (#000000)"
echo "   4. ✅ HERO SEARCH: Bordes TOTALMENTE REDONDEADOS (999px)"
echo "   5. ✅ HERO SEARCH: Input y botón SIN bordes internos"
echo "   6. ✅ HERO SEARCH: Botón hover con fondo blanco tenue"
echo ""
echo "📌 ESTE ESTILO SOLO SE APLICA EN MODO OSCURO"
echo "   • Modo claro: SIN CAMBIOS"
echo "   • Otros componentes: SIN CAMBIOS"
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
