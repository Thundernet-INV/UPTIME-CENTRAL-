#!/bin/bash
# fix-searchbar-chips-final.sh - ESTILO FINAL: BORDES REDONDEADOS Y TRANSPARENTE

echo "====================================================="
echo "🎨 APLICANDO ESTILO FINAL - BORDES REDONDEADOS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_final_chips_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. APLICAR ESTILO FINAL ==========
echo "[2] Aplicando estilo final a searchbar y chips..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== SEARCHBAR - ESTILO FINAL CON BORDES REDONDEADOS ========== */
body.dark-mode .hero-search-input {
  background: transparent !important;
  border: 1px solid #2d3238 !important;
  border-radius: 999px !important;
  color: #e5e7eb !important;
  padding: 8px 16px !important;
  height: 40px !important;
}

body.dark-mode .hero-search-button {
  background: transparent !important;
  border: 1px solid #2d3238 !important;
  border-radius: 999px !important;
  color: #e5e7eb !important;
  padding: 8px 20px !important;
  height: 40px !important;
  margin-left: 8px !important;
  transition: all 0.2s ease !important;
}

body.dark-mode .hero-search-button:hover {
  background: #2d3238 !important;
  color: white !important;
}

/* ========== CHIPS - ESTILO FINAL CON BORDES REDONDEADOS ========== */
body.dark-mode .k-chip,
body.dark-mode .k-chip--muted {
  background: transparent !important;
  border: 1px solid #2d3238 !important;
  border-radius: 999px !important;
  color: #e5e7eb !important;
  padding: 6px 16px !important;
}

body.dark-mode .k-chip strong {
  color: #ffffff !important;
}

body.dark-mode .k-chip .k-chip-action {
  background: transparent !important;
  border: none !important;
  color: #60a5fa !important;
  border-radius: 999px !important;
  padding: 4px 12px !important;
}

body.dark-mode .k-chip .k-chip-action:hover {
  background: #2d3238 !important;
  color: white !important;
}
EOF

echo "✅ Estilo final aplicado - bordes redondeados y transparente"
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
echo "✅✅ ESTILO FINAL APLICADO ✅✅"
echo "====================================================="
echo ""
echo "📋 ESTILO APLICADO:"
echo ""
echo "   🔍 SEARCHBAR:"
echo "   • background: transparent"
echo "   • border: 1px solid #2d3238"
echo "   • border-radius: 999px"
echo "   • color: #e5e7eb"
echo ""
echo "   🏷️ CHIPS:"
echo "   • background: transparent"
echo "   • border: 1px solid #2d3238"
echo "   • border-radius: 999px"
echo "   • color: #e5e7eb"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa modo oscuro (botón 🌙)"
echo "   3. ✅ SEARCHBAR: Bordes redondeados (999px), fondo transparente"
echo "   4. ✅ CHIPS: Bordes redondeados (999px), fondo transparente"
echo "   5. ✅ HOVER: Botón search y chip-action se ponen grises"
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
