#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

# Backup de seguridad
cp "$APP" "$APP.bak_solodown_$(date +%Y%m%d_%H%M%S)"

# Elimina el bloque <label> ... Solo DOWN ... que añadimos al lado de los filtros.
# (No toca el Solo DOWN que ya trae <Filters />)
awk '
  BEGIN{skip=0}
  {
    # Detectar inicio del label que contiene "Solo DOWN" (en el header)
    if ($0 ~ /<label[^>]*>.*Solo DOWN/ || $0 ~ /<label[^>]*>$/) {
      # Si la palabra aparece en la misma línea o siguiente, activamos skip y buscamos el cierre </label>
      if ($0 ~ /Solo DOWN/) { skip=1; next }
      else { skip=2; next }
    }
    if (skip==2 && $0 ~ /Solo DOWN/) { skip=1; next }
    if (skip==1) {
      if ($0 ~ /<\/label>/) { skip=0; next } 
      else { next }
    }
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "Compilando…"
cd "$ROOT"
npm run build

echo "Desplegando…"
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ Listo: quedó un único 'Solo DOWN' (el de Filters)."
