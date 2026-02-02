#!/bin/sh
set -eu
APP="src/App.jsx"
cp "$APP" "$APP.bak.$(date +%Y%m%d_%H%M%S)"

# Corrige la línea del template literal en el filtro base (hay => lowercased)
awk '
  {
    # Reemplazo sólo la línea que contiene "const hay =" seguida de ".toLowerCase();"
    if ($0 ~ /const hay =/ && $0 ~ /toLowerCase$$$$;/) {
      print "      const hay = ${m.info?.monitor_name ?? \"\"} ${m.info?.monitor_url ?? \"\"}.toLowerCase();"
      next
    }
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "✓ Línea corregida en src/App.jsx."
