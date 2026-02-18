#!/bin/bash
# fix-energia-entities-range.sh
# -----------------------------------------------------------------------------
# Problema:
#   En src/views/Dashboard.jsx quedaron líneas con ENTIDADES HTML
#   (ej.: “&lt;Hero”, “&lt;div …&gt;”) dentro del JSX y eso rompe el parser.
#
# Qué hace:
#   1) Backup de Dashboard.jsx
#   2) Convierte **solo en las zonas problemáticas** las entidades &lt;/&gt; a < / >
#      - Zona A: desde el comentario "HERO principal" hasta el cierre de Hero
#      - Zona B: cualquier bloque &lt;div style={{margin:"10px 0"}}&gt; ... &lt;/div&gt;
#   3) Si aún quedaran entidades sueltas en esas zonas, también las corrige.
#   4) Limpia caché de Vite y reinicia el dev server.
#
# Uso:
#   chmod +x ./fix-energia-entities-range.sh
#   ./fix-energia-entities-range.sh
# -----------------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEWS_DIR="$ROOT_DIR/src/views"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

[ -f "$DASHBOARD_FILE" ] || { err "No existe: $DASHBOARD_FILE"; exit 1; }

# 1) Backup
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
ok "Backup: ${DASHBOARD_FILE}.backup.${TS}"

TMP="${DASHBOARD_FILE}.tmp.${TS}"

# 2) Reparar entidades en ZONA A (desde comentario HERO hasta cierre de Hero)
#    - Busca línea del comentario "HERO principal" y convierte &lt; &gt; hasta encontrar:
#        </Hero>  o  <Hero ... />
#    - Si no encuentra el comentario, no hace nada en esta zona.

START_LINE="$(grep -n 'HERO principal' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1 || true)"
if [ -n "${START_LINE:-}" ]; then
  awk -v start="$START_LINE" '
    BEGIN{fix=0}
    {
      if (NR==start) { fix=1 }
      if (fix==1) {
        gsub(/&lt;/,"<"); gsub(/&gt;/,">");
      }
      print $0
      if (fix==1 && ($0 ~ /<\/Hero>/ || $0 ~ /<Hero[^>]*\/>/)) { fix=0 }
    }
  ' "$DASHBOARD_FILE" > "$TMP" && mv "$TMP" "$DASHBOARD_FILE"
  ok "ZONA A reparada: entidades <Hero> convertidas a JSX real"
else
  log "No se encontró el comentario 'HERO principal'; omito ZONA A"
fi

# 3) Reparar entidades en ZONA B (bloque del botón a energía con <div style=...>)
#    - Convierte &lt; &gt; desde la línea que abre ese <div> hasta su </div> de cierre.

if grep -q '&lt;div style={{margin:"10px 0"}}&gt;' "$DASHBOARD_FILE"; then
  awk '
    BEGIN{fix=0}
    {
      if ($0 ~ /&lt;div style=\{\{margin:"10px 0"\}\}&gt;/) { fix=1 }
      if (fix==1) {
        gsub(/&lt;/,"<"); gsub(/&gt;/,">");
      }
      print $0
      if (fix==1 && $0 ~ /<\/div>/) { fix=0 }
    }
  ' "$DASHBOARD_FILE" > "$TMP" && mv "$TMP" "$DASHBOARD_FILE"
  ok "ZONA B reparada: bloque <div style> del botón convertido a JSX real"
fi

# 4) Reparación adicional: si por alguna razón quedaron &lt;Hero sueltos entre el
#    comentario HERO y las 80 líneas siguientes, conviértelos.
if [ -n "${START_LINE:-}" ]; then
  END_LINE=$((START_LINE+80))
  awk -v s="$START_LINE" -v e="$END_LINE" '
    NR>=s && NR<=e { gsub(/&lt;/,"<"); gsub(/&gt;/,">"); print; next }
    { print }
  ' "$DASHBOARD_FILE" > "$TMP" && mv "$TMP" "$DASHBOARD_FILE"
  ok "Corrección adicional en rango cercano al HERO"
fi

# 5) Reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Hecho. Las entidades &lt; / &gt; en las zonas conflictivas fueron convertidas a JSX. Recarga el navegador."
