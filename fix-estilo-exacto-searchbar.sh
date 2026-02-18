#!/bin/bash
# fix-estilo-exacto-searchbar.sh - APLICAR ESTILO EXACTO AL SEARCHBAR

echo "====================================================="
echo "🎨 APLICANDO ESTILO EXACTO AL SEARCHBAR EN MODO OSCURO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_searchbar_exacto_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. APLICAR EL ESTILO EXACTO ==========
echo "[2] Aplicando estilo exacto al searchbar en modo oscuro..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== SEARCHBAR - ESTILO EXACTO EN MODO OSCURO ========== */
body.dark-mode .hero-search {
  display: flex !important;
  width: 100% !important;
}

body.dark-mode .hero-search-input {
  flex: 1 !important;
  padding: 12px 16px !important;
  font-size: 0.95rem !important;
  background: #0f1217 !important;
  border: 1px solid #e5e7eb !important;
  border-right: none !important;
  border-radius: 8px 0 0 8px !important;
  outline: none !important;
  color: #ffffff !important;
  transition: all 0.2s ease !important;
}

body.dark-mode .hero-search-input::placeholder {
  color: #9ca3af !important;
}

body.dark-mode .hero-search-button {
  padding: 12px 24px !important;
  background: #2563eb !important;
  color: white !important;
  border: 1px solid #e5e7eb !important;
  border-left: none !important;
  border-radius: 0 8px 8px 0 !important;
  font-size: 0.95rem !important;
  font-weight: 500 !important;
  cursor: pointer !important;
  transition: all 0.2s ease !important;
}

body.dark-mode .hero-search-button:hover {
  background: #3b82f6 !important;
}
EOF

echo "✅ Estilo exacto aplicado al searchbar"
echo ""

# ========== 3. APLICAR ESTILO A LOS CHIPS ==========
echo "[3] Aplicando estilo a los chips en modo oscuro..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== CHIPS - ESTILO CONSISTENTE EN MODO OSCURO ========== */
body.dark-mode .k-chip,
body.dark-mode .k-chip--muted {
  background: #1a1e24 !important;
  border: 1px solid #e5e7eb !important;
  color: #e5e7eb !important;
  padding: 4px 12px !important;
  border-radius: 16px !important;
  display: inline-flex !important;
  align-items: center !important;
  gap: 8px !important;
}

body.dark-mode .k-chip strong {
  color: #ffffff !important;
  font-weight: 600 !important;
}

body.dark-mode .k-chip .k-chip-action {
  color: #60a5fa !important;
  background: transparent !important;
  border: none !important;
  padding: 4px 8px !important;
  margin-left: 4px !important;
  border-radius: 4px !important;
}

body.dark-mode .k-chip .k-chip-action:hover {
  background: rgba(96, 165, 250, 0.1) !important;
}
EOF

echo "✅ Estilo de chips aplicado"
echo ""

# ========== 4. LIMPIAR CACHÉ ==========
echo "[4] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 5. REINICIAR FRONTEND ==========
echo "[5] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 6. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ ESTILO EXACTO APLICADO ✅✅"
echo "====================================================="
echo ""
echo "📋 ESTILO APLICADO AL SEARCHBAR:"
echo ""
echo "   body.dark-mode .hero-search-input {"
echo "     background: #0f1217;"
echo "     border: 1px solid #e5e7eb;"
echo "     border-right: none;"
echo "     border-radius: 8px 0 0 8px;"
echo "     color: #ffffff;"
echo "   }"
echo ""
echo "   body.dark-mode .hero-search-button {"
echo "     background: #2563eb;"
echo "     border: 1px solid #e5e7eb;"
echo "     border-left: none;"
echo "     border-radius: 0 8px 8px 0;"
echo "     color: white;"
echo "   }"
echo ""
echo "📋 ESTILO APLICADO A LOS CHIPS:"
echo ""
echo "   body.dark-mode .k-chip {"
echo "     background: #1a1e24;"
echo "     border: 1px solid #e5e7eb;"
echo "     color: #e5e7eb;"
echo "   }"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa modo oscuro (botón 🌙)"
echo "   3. ✅ SEARCHBAR: Input con borde blanco, fondo oscuro, texto blanco"
echo "   4. ✅ SEARCHBAR: Botón azul con borde blanco"
echo "   5. ✅ CHIPS: Borde blanco, fondo #1a1e24, texto blanco"
echo ""
echo "📌 SOLO SE MODIFICÓ dark-mode.css"
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
