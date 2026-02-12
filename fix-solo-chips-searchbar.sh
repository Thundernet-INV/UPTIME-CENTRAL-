#!/bin/bash
# fix-solo-chips-searchbar.sh - SOLO CAMBIAR CHIPS Y SEARCHBAR EN MODO OSCURO

echo "====================================================="
echo "🎨 CORRIGIENDO SOLO CHIPS Y SEARCHBAR EN MODO OSCURO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_solo_chips_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR SOLO LAS CLASES ESPECÍFICAS ==========
echo "[2] Actualizando solo .k-chip y .hero-search en dark-mode.css..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== CHIPS EN MODO OSCURO - SOLO BORDE BLANCO ========== */
body.dark-mode .k-chip,
body.dark-mode .k-chip--muted {
  background: #1a1e24 !important;
  border: 1px solid #e5e7eb !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-chip strong {
  color: #ffffff !important;
}

body.dark-mode .k-chip .k-chip-action {
  color: #60a5fa !important;
}

/* ========== SEARCHBAR EN MODO OSCURO - SOLO BORDE BLANCO ========== */
body.dark-mode .hero-search-input {
  background: #0f1217 !important;
  border: 1px solid #e5e7eb !important;
  border-right: none !important;
  color: #ffffff !important;
}

body.dark-mode .hero-search-input::placeholder {
  color: #9ca3af !important;
}

body.dark-mode .hero-search-button {
  background: #2563eb !important;
  border: 1px solid #e5e7eb !important;
  border-left: none !important;
  color: white !important;
}

body.dark-mode .hero-search-button:hover {
  background: #3b82f6 !important;
}
EOF

echo "✅ Clases .k-chip y .hero-search actualizadas"
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
echo "✅✅ CAMBIOS APLICADOS - SOLO CHIPS Y SEARCHBAR ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS (SOLO ESTO):"
echo ""
echo "   1. 🏷️ .k-chip y .k-chip--muted:"
echo "      • Fondo: #1a1e24 (se mantiene)"
echo "      • Borde: BLANCO (#e5e7eb)"
echo "      • Texto: #e5e7eb"
echo ""
echo "   2. 🔍 .hero-search-input:"
echo "      • Fondo: #0f1217 (se mantiene)"
echo "      • Borde: BLANCO (#e5e7eb)"
echo "      • Texto: BLANCO (#ffffff)"
echo ""
echo "   3. 🔘 .hero-search-button:"
echo "      • Fondo: #2563eb"
echo "      • Borde: BLANCO (#e5e7eb)"
echo "      • Hover: #3b82f6"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa modo oscuro (botón 🌙)"
echo "   3. ✅ CHIPS: 'Mostrando: Google' debe tener BORDE BLANCO"
echo "   4. ✅ SEARCHBAR: Input debe tener BORDE BLANCO"
echo "   5. ❌ TODO LO DEMÁS SIGUE IGUAL"
echo ""
echo "📌 NO SE MODIFICÓ NINGÚN OTRO ESTILO"
echo "   • Hero.jsx: INTACTO"
echo "   • SearchBar.jsx: INTACTO"
echo "   • Otros componentes: INTACTOS"
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
