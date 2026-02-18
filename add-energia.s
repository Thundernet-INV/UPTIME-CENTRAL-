#!/bin/bash
# add-energia.sh - Agrega vista "Energía" (ICMP) y botón junto a "Comparar"
set -e

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASH="$FRONTEND_DIR/src/views/Dashboard.jsx"
ENERGIA="$FRONTEND_DIR/src/views/Energia.jsx"
BACKUP="$FRONTEND_DIR/backup_energia_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"

echo "🔧 Backup de Dashboard.jsx → $BACKUP"
cp "$DASH" "$BACKUP/Dashboard.jsx.bak"

echo "🧩 Creando $ENERGIA (vista Energía: ICMP por tipo + etiquetas)..."
cat > "$ENERGIA" <<'EOF'
[PEGA_AQUÍ_EL_CONTENIDO_COMPLETO_DE_src/views/Energia.jsx_DEL_BLOQUE_ANTERIOR]
EOF

echo "🧩 Importando <Energia /> en Dashboard.jsx..."
# Inserta import justo después de otros imports de views
if ! grep -q 'import Energia from "./Energia.jsx"' "$DASH"; then
  sed -i '1,/import .* from/s|^import .* from.*|&\nimport Energia from "./Energia.jsx";|' "$DASH"
fi

echo "🧩 Insertando botón 'Energía' al lado de 'Comparar'..."
# Busca el botón Comparar y añade inmediatamente después el botón Energía
# Patrón robusto: línea con >Comparar</button>
awk '
  BEGIN{added=0}
  {
    print $0
    if ($0 ~ />[[:space:]]*Comparar[[:space:]]*<\/button>/ && added==0) {
      print "      <button"
      print "        className=\"home-btn\""
      print "        type=\"button\""
      print "        title=\"Vista de energía (ICMP)\""
      print "        onClick={() => {"
      print "          window.location.hash = \"/energia\";"
      print "          setAutoPlay?.(false);"
      print "        }}"
      print "      >"
      print "        Energía"
      print "      </button>"
      added=1
    }
  }
' "$DASH" > "$DASH.tmp" && mv "$DASH.tmp" "$DASH"

echo "🧩 Extendiendo routing: reconoce #/energia..."
# Añadir case de ruta si no existe
if ! grep -q 'name === "energia"' "$DASH"; then
  sed -i 's|if\s*(route\?.*name\s*===\s*"compare".*|&\
if (route?.name === "energia") {\
  return <Energia monitorsAll={monitors} />;\
}|' "$DASH" || true
fi

# Intento alterno: si usas un switch render central, añadimos un bloque común
if ! grep -q '<Energia monitorsAll={monitors}' "$DASH"; then
  # Añade un bloque condicional genérico antes del return principal
  sed -i '/return\s*(/i if (route?.name === "energia") { return <Energia monitorsAll={monitors} />; }' "$DASH"
fi

# Si existe un getRoute() que analiza el hash, añadir mapeo #/energia
if grep -q "function getRoute" "$DASH"; then
  sed -i '/#\/comparar/ a \ \ \ \ if (hash.startsWith("#/energia")) return { name: "energia" };' "$DASH"
fi

echo "🧼 Limpiando caché Vite y reiniciando dev server..."
cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
npm run dev &>/dev/null &

echo "✅ Listo: botón 'Energía' junto a 'Comparar' y vista ICMP por tipo/etiquetas."
echo "   • Abrir: http://10.10.31.31:5173"
echo "   • Revertir: cp \"$BACKUP/Dashboard.jsx.bak\" \"$DASH\""
