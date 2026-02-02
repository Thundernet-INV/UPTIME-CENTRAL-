#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$APP" ] && cp "$APP" "$APP.bak_$ts" || true

echo "== 1) Limpiando imports y renders de OverlayChart / ChartFallback en App.jsx =="
# Quitar imports
sed -i '/import OverlayChart from ".\/components\/OverlayChart\.jsx";/d' "$APP" || true
sed -i '/import ChartFallback from ".\/components\/ChartFallback\.jsx";/d' "$APP" || true

# Quitar renders por si quedara alguno
sed -i '/<OverlayChart .*\/>/d' "$APP" || true
sed -i '/<ChartFallback .*\/>/d' "$APP" || true

echo "== 2) Eliminar bloque condicional vacío {route.name === \"sede\" && ( )} =="
awk '
  BEGIN {skip=0}
  {
    if (skip) {
      # cerramos al ver una línea que contenga `)}`
      if ($0 ~ /\)\}/) { skip=0; next }
      # seguimos saltando
      next
    }
    # detecta la línea que abre el condicional vacío
    if ($0 ~ /\{route\.name === "sede"[[:space:]]*&&[[:space:]]*\($/) { skip=1; next }
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 3) Verificación (no debe quedar Overlay/ChartFallback ni bloque vacío) =="
grep -nE 'OverlayChart|ChartFallback' "$APP" || echo "OK: sin fallbacks en App.jsx"
grep -n '{route.name === "sede" && (' "$APP" && echo "WARN: quedo condicion" || echo "OK: bloque vacío eliminado"

echo "== 4) Compilando y desplegando =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: build correcto, fallbacks eliminados y única gráfica nativa activa."
