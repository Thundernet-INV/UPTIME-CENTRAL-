#!/bin/bash
# fix-comentario-modal.sh
# CORRIGE EL COMENTARIO DENTRO DEL OBJETO STYLE

echo "====================================================="
echo "🔧 CORRIGIENDO COMENTARIO EN MODAL"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.comentario.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR LÍNEAS ACTUALES ==========
echo ""
echo "[2] Líneas 270-290 actuales:"
sed -n '270,290p' "$DASHBOARD_FILE"
echo ""

# ========== 3. CORREGIR EL COMENTARIO ==========
echo ""
echo "[3] Moviendo comentario fuera del objeto style..."

# Reemplazar las líneas problemáticas
sed -i '275,290c \
  return (\n\
    <div style={{\n\
      background: '\''white'\'',\n\
      borderRadius: '\''12px'\'',\n\
      marginBottom: '\''16px'\'',\n\
      boxShadow: '\''0 2px 8px rgba(0,0,0,0.1)'\''\n\
    }}>\n\
      {/* SECCIÓN DE CONSUMO EN MODAL */}\n\
      {tipo === '\''PLANTA'\'' && (\n\
        <div style={{\n\
          gridColumn: '\''span 2'\'',\n\
          background: '\''#d1fae5'\'',\n\
          padding: '\''20px'\'',\n\
          borderRadius: '\''12px'\'',\n\
          marginBottom: '\''16px'\''\n\
        }}>\n\
          <h4 style={{ margin: '\''0 0 12px 0'\'', fontSize: '\''1rem'\'', color: '\''#065f46'\'' }}>\n\
            ⛽ CONSUMO DE COMBUSTIBLE\n\
          </h4>\n\
        </div>\n\
      )}\n\
    </div>\n\
  );' "$DASHBOARD_FILE"

echo "✅ Comentario corregido"

# ========== 4. VERIFICAR DESPUÉS ==========
echo ""
echo "[4] Líneas 270-290 después de la corrección:"
sed -n '270,290p' "$DASHBOARD_FILE"
echo ""

# ========== 5. REINICIAR FRONTEND ==========
echo ""
echo "[5] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ COMENTARIO CORREGIDO ✅✅"
echo "====================================================="
echo ""
