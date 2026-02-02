#!/bin/sh
# Diagnóstico de origen del dashboard en 10.10.31.31
# - Inspecciona headers y contenido del index
# - Busca huellas de Vite dev (/@vite/client, type="module")
# - Revisa si hay proxy_pass a 5173 en Nginx
# - Lista quién atiende :80 y :5173
# - Si existe dist/index.html local, compara hash con el remoto
set -eu

HOST="10.10.31.31"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="dashboard_audit_$STAMP.txt"
TMP_HTML="/tmp/audit_index_$STAMP.html"
TMP_HDR="/tmp/audit_headers_$STAMP.txt"

echo "=== AUDIT DASHBOARD ORIGIN ($STAMP) ===" | tee "$OUT"

echo "\n-- 1) HEADERS de http://$HOST/ --" | tee -a "$OUT"
curl -sS -D "$TMP_HDR" -o "$TMP_HTML" "http://$HOST/" >/dev/null || true
sed -n '1,30p' "$TMP_HDR" | tee -a "$OUT"

echo "\n-- 2) Primeras líneas del HTML remoto --" | tee -a "$OUT"
sed -n '1,60p' "$TMP_HTML" | tee -a "$OUT"

echo "\n-- 3) Huellas de Vite dev en el HTML remoto --" | tee -a "$OUT"
grep -E -n '/@vite/client|type="module"|vite' "$TMP_HTML" || echo "(sin huellas típicas de Vite)"

echo "\n-- 4) ¿Quién escucha en :80 y :5173? --" | tee -a "$OUT"
sudo ss -ltnp | egrep ':80|:5173' || true

echo "\n-- 5) Nginx: ¿hay proxy_pass o referencia a 5173? --" | tee -a "$OUT"
sudo grep -R --line-number --color -E 'proxy_pass|5173' /etc/nginx/nginx.conf /etc/nginx/sites-enabled/ 2>/dev/null || echo "(sin coincidencias obvias)"

echo "\n-- 6) systemctl status nginx (resumen) --" | tee -a "$OUT"
systemctl is-active nginx >/dev/null 2>&1 && systemctl status nginx -n 0 --no-pager | sed -n '1,12p' | tee -a "$OUT" || echo "(nginx no está como servicio o no usa systemd)"

if [ -f dist/index.html ]; then
  echo "\n-- 7) Comparativa de hash: local dist/index.html vs remoto --" | tee -a "$OUT"
  # Normalizamos mínimamente (sin serio minify) y calculamos sha256
  LOC_SHA=$(sha256sum dist/index.html | awk '{print $1}')
  REM_SHA=$(sha256sum "$TMP_HTML" | awk '{print $1}')
  echo "local:  $LOC_SHA" | tee -a "$OUT"
  echo "remoto: $REM_SHA" | tee -a "$OUT"
  if [ "$LOC_SHA" = "$REM_SHA" ]; then
    echo "=> El HTML remoto coincide con el build local actual." | tee -a "$OUT"
  else
    echo "=> El HTML remoto NO coincide con tu build local." | tee -a "$OUT"
  fi
else
  echo "\n-- 7) dist/index.html no existe en esta ruta; se omite comparación --" | tee -a "$OUT"
fi

echo "\n-- 8) Deducción rápida --" | tee -a "$OUT"
if grep -q '/@vite/client' "$TMP_HTML"; then
  echo "Posible Vite dev server detrás (proxy a 5173) o página dev." | tee -a "$OUT"
elif sudo grep -R -q 'proxy_pass.*5173' /etc/nginx/nginx.conf /etc/nginx/sites-enabled/ 2>/dev/null; then
  echo "Nginx está proxyeando a 5173." | tee -a "$OUT"
else
  echo "Parece contenido estático servido por Nginx; si es 'viejo', hay que reemplazar el dist en /var/www/... y recargar Nginx." | tee -a "$OUT"
fi

echo "\n=== FIN AUDIT ===\nArchivo: $OUT"
