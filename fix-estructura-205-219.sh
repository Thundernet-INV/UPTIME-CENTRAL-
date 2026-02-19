#!/bin/bash
# fix-estructura-205-219.sh
# CORRIGE LAS LÍNEAS 205-219

echo "====================================================="
echo "🔧 CORRIGIENDO ESTRUCTURA LÍNEAS 205-219"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.final.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR LÍNEAS ACTUALES ==========
echo ""
echo "[2] Líneas 200-220 actuales:"
sed -n '200,220p' "$DASHBOARD_FILE"
echo ""

# ========== 3. ELIMINAR LÍNEAS PROBLEMÁTICAS ==========
echo ""
echo "[3] Eliminando líneas 205-219..."

# Eliminar el bloque problemático
sed -i '205,219d' "$DASHBOARD_FILE"

echo "✅ Líneas eliminadas"

# ========== 4. RESTAURAR ESTRUCTURA CORRECTA ==========
echo ""
echo "[4] Restaurando estructura correcta..."

# Insertar el cierre correcto después de la línea 204
sed -i '204a \          </div>\n        </div>\n      )}\n    </div>\n  );\n}' "$DASHBOARD_FILE"

echo "✅ Estructura restaurada"

# ========== 5. VERIFICAR DESPUÉS ==========
echo ""
echo "[5] Líneas 190-210 después de la corrección:"
sed -n '190,210p' "$DASHBOARD_FILE"
echo ""

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ ESTRUCTURA CORREGIDA ✅✅"
echo "====================================================="
echo ""
