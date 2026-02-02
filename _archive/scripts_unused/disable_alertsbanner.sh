#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

# Backup
cp "$APP" "$APP.bak_nobanner_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Insertar flag SHOW_BANNER=false (si no existe) =="
grep -q 'const SHOW_BANNER' "$APP" || \
  sed -i '0,/const ALERT_AUTOCLOSE_MS/a const SHOW_BANNER = false; // Oculta el banner superior de alertas' "$APP"

echo "== 2) Envolver el render de <AlertsBanner .../> con {SHOW_BANNER && (...)} =="
awk '
  BEGIN{done=0}
  {
    if (!done && $0 ~ /<AlertsBanner[^>]*\/>/) {
      gsub(/<AlertsBanner[^>]*\/>/, "{SHOW_BANNER && (<AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS} />)}")
      done=1
    }
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 3) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ Listo: banner oculto; se mantienen solo los pop-ups a la derecha."
