#!/bin/sh
set -eu
HOST="10.10.31.31"
STAMP="$(date +%Y%m%d_%H%M%S)"
TMP_HTML="/tmp/index_remote_$STAMP.html"
OUT="assets_diff_$STAMP.txt"

echo "== Bajando index remoto =="
curl -sS "http://$HOST/" -o "$TMP_HTML"

echo "== Extrayendo rutas /assets/ del HTML ==" 
ASSETS=$(grep -Eo 'src="/assets/[^"]+|href="/assets/[^"]+' "$TMP_HTML" | sed 's/^[^"]*"\(\/assets\/.*\)$/\1/' | sort -u)

echo "== Comparando con dist local ==" | tee "$OUT"
FOUND_MISS=0
for a in $ASSETS; do
  REM="/tmp/remote_$STAMP$(echo "$a" | tr '/' '_')"
  curl -sS "http://$HOST$a" -o "$REM" || true
  if [ -f "dist$a" ]; then
    L=$(sha256sum "dist$a" | awk '{print $1}')
  else
    L="(no existe local)"
  fi
  if [ -f "$REM" ]; then
    R=$(sha256sum "$REM" | awk '{print $1}')
  else
    R="(no existe remoto)"
  fi
  if [ "$L" != "$R" ]; then
    echo "✗ Mismatch: $a" | tee -a "$OUT"
    echo "  local : $L" | tee -a "$OUT"
    echo "  remoto: $R" | tee -a "$OUT"
    FOUND_MISS=1
  else
    echo "✓ OK      $a" | tee -a "$OUT"
  fi
done

echo
if [ "$FOUND_MISS" -eq 1 ]; then
  echo "➡ Hay assets remotos distintos a tu build local. Conviene re-desplegar dist/ con --delete."
else
  echo "✅ Todo coincide (assets y HTML). Si sigues viendo 'lo viejo', probablemente es caché del navegador o CDN."
fi
