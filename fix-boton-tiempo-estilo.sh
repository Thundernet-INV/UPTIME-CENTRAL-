#!/bin/bash
# fix-boton-tiempo-estilo.sh - APLICAR MISMO ESTILO A TODOS LOS BOTONES DE TIEMPO

echo "====================================================="
echo "🎨 UNIFICANDO ESTILO DE BOTONES DE TIEMPO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_boton_tiempo_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR INSTANCEDETAIL.JSX ==========
echo "[2] Actualizando InstanceDetail.jsx con estilo unificado..."

sed -i 's/style={{\n              display: .flex.,\n              alignItems: .center.,\n              gap: .6px.,\n              padding: .4px 12px.,\n              background: .var(--bg-tertiary, #f3f4f6).,\n              border: .1px solid var(--border, #e5e7eb).,\n              borderRadius: .16px.,\n              fontSize: .0.8rem.,\n              cursor: .pointer.,\n            }}/style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              padding: "6px 14px",
              background: "var(--bg-tertiary, #f3f4f6)",
              border: "1px solid var(--border, #e5e7eb)",
              borderRadius: "20px",
              fontSize: "0.85rem",
              color: "var(--text-primary, #1f2937)",
              cursor: "pointer",
              transition: "all 0.2s ease",
            }}/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

sed -i 's/<span style={{ fontSize: .1rem. }}>🕒<\\/span>/<span style={{ fontSize: "1rem" }}>🕒<\\/span>/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
sed -i 's/<span style={{ fontWeight: .500. }}>{selectedLabel}<\\/span>/<span style={{ fontWeight: "500" }}>{selectedLabel}<\\/span>/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
sed -i 's/<span style={{ fontSize: .0.7rem., opacity: 0.7 }}>▼<\\/span>/<span style={{ fontSize: "0.7rem", opacity: 0.7 }}>▼<\\/span>/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

echo "✅ InstanceDetail.jsx actualizado"
echo ""

# ========== 3. ACTUALIZAR MULTISERVICEVIEW.JSX ==========
echo "[3] Actualizando MultiServiceView.jsx con estilo unificado..."

sed -i 's/style={{\n          display: .flex.,\n          alignItems: .center.,\n          gap: .6px.,\n          padding: .6px 14px.,\n          background: .var(--bg-tertiary, #f3f4f6).,\n          border: .1px solid var(--border, #e5e7eb).,\n          borderRadius: .20px.,\n          fontSize: .0.85rem.,\n          cursor: .pointer.,\n          transition: .all 0.2s ease.,\n          fontWeight: .500.,\n        }}/style={{
          display: "flex",
          alignItems: "center",
          gap: "8px",
          padding: "6px 14px",
          background: "var(--bg-tertiary, #f3f4f6)",
          border: "1px solid var(--border, #e5e7eb)",
          borderRadius: "20px",
          fontSize: "0.85rem",
          color: "var(--text-primary, #1f2937)",
          cursor: "pointer",
          transition: "all 0.2s ease",
        }}/g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

sed -i 's/<span style={{ fontSize: .0.9rem. }}>🕒<\\/span>/<span style={{ fontSize: "1rem" }}>🕒<\\/span>/g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
sed -i 's/<span style={{ fontSize: .0.7rem., opacity: 0.7 }}>▼<\\/span>/<span style={{ fontSize: "0.7rem", opacity: 0.7 }}>▼<\\/span>/g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

echo "✅ MultiServiceView.jsx actualizado"
echo ""

# ========== 4. ACTUALIZAR DARK-MODE.CSS ==========
echo "[4] Actualizando dark-mode.css con estilos de botones de tiempo..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== BOTONES DE TIEMPO - ESTILO UNIFICADO MODO OSCURO ========== */
body.dark-mode button[style*="border-radius: 20px"] {
  background: transparent !important;
  border: 1px solid #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode button[style*="border-radius: 20px"]:hover {
  background: #2d3238 !important;
}

body.dark-mode button[style*="border-radius: 20px"] span[style*="font-size: 1rem"] {
  color: #e5e7eb !important;
}

/* ========== DROPDOWNS DE TIEMPO - MODO OSCURO ========== */
body.dark-mode div[style*="position: absolute"][style*="background: white"] {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode div[style*="position: absolute"] button {
  color: #e5e7eb !important;
  border-bottom-color: #2d3238 !important;
  background: transparent !important;
}

body.dark-mode div[style*="position: absolute"] button:hover {
  background: #2d3238 !important;
}

body.dark-mode div[style*="position: absolute"] button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  color: white !important;
}
EOF

echo "✅ dark-mode.css actualizado"
echo ""

# ========== 5. LIMPIAR CACHÉ ==========
echo "[5] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 6. REINICIAR FRONTEND ==========
echo "[6] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ BOTONES DE TIEMPO UNIFICADOS ✅✅"
echo "====================================================="
echo ""
echo "📋 ESTILO UNIFICADO APLICADO:"
echo ""
echo "   🕒 BOTÓN DE TIEMPO:"
echo "   • display: flex"
echo "   • align-items: center"
echo "   • gap: 8px"
echo "   • padding: 6px 14px"
echo "   • background: var(--bg-tertiary, #f3f4f6)"
echo "   • border: 1px solid var(--border, #e5e7eb)"
echo "   • border-radius: 20px"
echo "   • font-size: 0.85rem"
echo "   • color: var(--text-primary, #1f2937)"
echo "   • cursor: pointer"
echo "   • transition: all 0.2s ease"
echo ""
echo "   🌙 MODO OSCURO:"
echo "   • background: transparent"
echo "   • border: 1px solid #2d3238"
echo "   • color: #e5e7eb"
echo "   • hover: background #2d3238"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Entra a una sede - VERÁS botón 🕒 con estilo redondeado"
echo "   3. ✅ Ve a 'Comparar' - MISMO estilo en el botón 🕒"
echo "   4. ✅ Activa modo oscuro - botón transparente con borde gris"
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
