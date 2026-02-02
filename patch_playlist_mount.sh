#!/bin/bash
set -eu

APP="src/App.jsx"
TS=$(date +%Y%m%d_%H%M%S)

cp "$APP" "$APP.bak.$TS"

echo "➤ Insertando AutoPlayer y DebugChip en bloque .controls …"

awk '
  BEGIN { inserted=0 }
  {
    print

    # Detecto el cierre del bloque controls real
    # Y justo después inyecto los componentes faltantes
    if (!inserted && $0 ~ /<\/div>/ && prev ~ /className="controls"/) {
      print "      {/* AUTOPLAY ENGINE (insertion forced) */}"
      print "      <AutoPlayer"
      print "        enabled={autoRun}"
      print "        intervalSec={autoIntervalSec}"
      print "        viewSec={autoViewSec}"
      print "        order={autoOrder}"
      print "        onlyIncidents={autoOnlyIncidents}"
      print "        loop={autoLoop}"
      print "        filteredAll={filteredAll}"
      print "        route={route}"
      print "        openInstance={openInstance}"
      print "      />"
      print "      <DebugChip />"
      inserted=1
    }
    prev=$0
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "✔ OK — Bloques añadidos con éxito."
echo "⚠ Ahora ejecuta:"
echo "     npm run build"
echo "     sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "     sudo nginx -t && sudo systemctl reload nginx"
