#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

# Backup
cp "$APP" "$APP.bak_avg5msg_$(date +%Y%m%d_%H%M%S)"

# 1) Arreglar la ternaria rota: ${delta>0?+:}  ->  ${delta>0?'+':''}
#    Usamos perl para no pelear con escapados en sed/awk
perl -0777 -pe "s/\\$\\{delta>0\\?\\+:\\}/\\\${delta>0?'+':''}/g" -i "$APP"

# 2) (Opcional) Si por alguna razón la variante quedó con espacios, normalizamos:
perl -0777 -pe "s/\\$\\{\\s*delta\\s*>\\s*0\\s*\\?\\s*\\+\\s*:\\s*\\}/\\\${delta>0?'+':''}/g" -i "$APP"

# 3) Build & deploy
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Ternaria del mensaje corregida: build OK."
