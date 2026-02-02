#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

# Backup
cp "$APP" "$APP.bak_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Cambiar comentario HTML por comentario JSX =="
# Reemplaza `</div><!-- end:header-tools -->` por `</div>{/* end:header-tools */}`
sed -i 's#</div><!-- end:header-tools -->#</div>{/* end:header-tools */}#' "$APP"

echo "== 2) Asegurar que el bloque de filtros tiene el componente <Filters .../> =="
# Si el div header-filters está vacío, insertar el <Filters .../> dentro
awk '
  BEGIN{pending=0}
  {
    print
    if ($0 ~ /<div className="header-filters"/) {
      pending=1
    } else if (pending==1) {
      # si la siguiente línea cierra inmediatamente el div, inyecta Filters
      if ($0 ~ /^\s*<\/div>\s*$/) {
        print "            <Filters monitors={monitors} value={filters} onChange={setFilters} />"
      }
      pending=0
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 3) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ Arreglo aplicado: comentario JSX válido y filtros renderizados en el header."
