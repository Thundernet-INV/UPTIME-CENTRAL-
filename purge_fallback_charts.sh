#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"

echo "== Backups =="
for f in "$ROOT/src/App.jsx" "$ROOT/src/components/InstanceDetail.jsx"; do
  [ -f "$f" ] && cp "$f" "$f.bak_$(date +%Y%m%d_%H%M%S)" || true
done

echo "== 1) Eliminar imports/renders de OverlayChart/ChartFallback en TODOS los archivos =="
# Imports
grep -RIl 'OverlayChart|ChartFallback' "$ROOT/src" | xargs -r sed -i \
  -e '/import \s*OverlayChart\s*from .*OverlayChart\.jsx";/d' \
  -e '/import \s*ChartFallback\s*from .*ChartFallback\.jsx";/d'

# Renders en JSX
grep -RIl 'OverlayChart|ChartFallback' "$ROOT/src" | xargs -r sed -i \
  -e '/<OverlayChart .*\/>/d' \
  -e '/<ChartFallback .*\/>/d'

echo "== 2) Quitar bloque condicional vacío {route.name === \"sede\" && ( )} si quedara en App.jsx =="
APP="$ROOT/src/App.jsx"
awk '
  BEGIN {skip=0}
  {
    if (skip) {
      if ($0 ~ /\)\}/) { skip=0; next }
      next
    }
    if ($0 ~ /\{route\.name === "sede"[[:space:]]*&&[[:space:]]*\($/) { skip=1; next }
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 3) Verificación de restos =="
grep -RIn 'OverlayChart\|ChartFallback' "$ROOT/src" || echo "OK: sin fallbacks"
grep -n '{route.name === "sede" && (' "$APP" && echo "WARN: quedo bloque vacío" || echo "OK: bloque vacío no presente"

echo "== 4) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ Limpieza hecha y despliegue listo"
