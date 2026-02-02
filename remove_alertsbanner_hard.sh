#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

echo "== Backup =="
cp "$APP" "$APP.bak_removeBanner_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Eliminar import de AlertsBanner =="
# borra cualquier import de AlertsBanner
sed -i '/import AlertsBanner from ".\/components\/AlertsBanner\.jsx";/d' "$APP"

echo "== 2) Eliminar renders de AlertsBanner (envuelto o plano) =="
# 2.1 Quita wrappers tipo {SHOW_BANNER && (<AlertsBanner ... />)}
sed -i 's/{SHOW_BANNER\s*&&\s*(<AlertsBanner[^}]*>[^}]*<\/AlertsBanner>)}/ /g' "$APP"
sed -i 's/{SHOW_BANNER\s*&&\s*(<AlertsBanner[^}]*\/>)}/ /g' "$APP"
# 2.2 Quita renders planos autocerrados y apertura/cierre en misma línea
sed -i 's/<AlertsBanner[^>]*\/>/ /g' "$APP"
sed -i 's/<AlertsBanner[^>]*>.*<\/AlertsBanner>/ /g' "$APP"

echo "== 3) Quitar la constante SHOW_BANNER si quedó =="
sed -i '/^\s*const\s\+SHOW_BANNER\s*=\s*.*;.*$/d' "$APP"

echo "== 4) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: AlertsBanner eliminado. Solo quedan pop‑ups a la derecha."
