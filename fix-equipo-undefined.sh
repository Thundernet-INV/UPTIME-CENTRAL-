#!/bin/bash
# fix-equipo-undefined.sh
# CORRIGE EL ERROR DE EQUIPO UNDEFINED Y EL 404 DE BLOCKLIST

echo "====================================================="
echo "🔧 CORRIGIENDO ERRORES FINALES"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"
API_FILE="$FRONTEND_DIR/src/api.js"

# ========== 1. CORREGIR ENERGIA DASHBOARD ==========
echo ""
echo "[1] Corrigiendo EnergiaDashboard.jsx..."

# Hacer backup
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.$(date +%Y%m%d_%H%M%S)"

# Agregar validación al inicio del componente
sed -i '3i \ \n  if (!equipo) {\n    return null;\n  }' "$DASHBOARD_FILE"

# También modificar para que sea más robusto
sed -i 's/equipo\.info/equipo?.info/g' "$DASHBOARD_FILE"
sed -i 's/equipo\.latest/equipo?.latest/g' "$DASHBOARD_FILE"
sed -i 's/equipo\.instance/equipo?.instance/g' "$DASHBOARD_FILE"

echo "✅ EnergiaDashboard.jsx corregido"

# ========== 2. CORREGIR API.JS PARA MANEJAR ERROR 404 ==========
echo ""
echo "[2] Corrigiendo api.js para manejar error 404..."

if [ -f "$API_FILE" ]; then
    cp "$API_FILE" "$API_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Agregar manejo de error 404 para blocklist
    sed -i '/export async function getBlocklist/,/}/ {
        s/if (!res.ok) return null;/if (!res.ok) {\n      if (res.status === 404) {\n        console.log("Blocklist endpoint no disponible (404)");\n        return [];\n      }\n      return null;\n    }/
    }' "$API_FILE"
    
    echo "✅ api.js corregido"
else
    echo "⚠️ No se encontró api.js"
fi

# ========== 3. VERIFICAR QUE EL COMPONENTE ESTÉ BIEN IMPORTADO ==========
echo ""
echo "[3] Verificando dónde se usa EnergiaDashboard..."

# Buscar archivos que importen EnergiaDashboard
grep -r "import.*EnergiaDashboard" "$FRONTEND_DIR/src/" | head -5

# ========== 4. REINICIAR FRONTEND ==========
echo ""
echo "[4] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ ERRORES FINALES CORREGIDOS ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EL DETALLE DEBERÍA FUNCIONAR:"
echo "   • Ya no debería dar error 'equipo is undefined'"
echo "   • El error 404 de blocklist está manejado"
echo "   • El consumo debería mostrarse correctamente"
echo ""
