#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

echo "== Backup =="
cp "$APP" "$APP.bak_msgfix_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Corregir ternaria y fallback del nombre =="
# - Repara ${delta>0?+:}  -> ${delta>0?'+':''}
# - Repara ${m.info?.monitor_name || } -> ${m.info?.monitor_name || ''}

perl -0777 -i -pe "
  s/\\$\\{\\s*delta\\s*>\\s*0\\s*\\?\\s*\\+\\s*:\\s*\\}/\\\${delta>0?'+':''}/g;
  s/\\$\\{\\s*m\\.info\\?\\.\\s*monitor_name\\s*\\|\\|\\s*\\}/\\\${m.info?.monitor_name || ''}/g;
" "$APP"

echo "== 2) (Opcional) Normalizar toda la línea del mensaje si quedara corrupta =="
# Si prefieres forzar la línea completa del mensaje a un formato seguro, descomenta el bloque de abajo:
# perl -0777 -i -pe "
#   s/const\\s+msg\\s*=\\s*`[^`]*?`;\\s*\\n/const msg = \`Variación \\\${delta>0?'+':''}\${Math.round(delta)} ms vs prom \\\${avg} ms en \\\${m.info?.monitor_name || ''} (\${m.instance})\`;\n/g;
# " "$APP"

echo "== 3) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo '✓ Mensaje corregido. Build OK. Criterio activo: |rt - promedio(últimos 5)| ≥ DELTA_ALERT_MS.'
