#!/bin/bash
# fix-energia-entities-and-button.v1.sh
# -----------------------------------------------------------------------------
# Problema que estás viendo:
#   En Dashboard.jsx quedó inyectado un bloque con ENTIDADES HTML (&lt; ... &gt;)
#   dentro del JSX (ej.: “&lt;div style=...&gt;”), lo que rompe el parser de Vite/Babel.
#
# Qué hace este script:
#   1) Hace backup de src/views/Dashboard.jsx
#   2) Elimina cualquier import duplicado de Energia y deja UN SOLO:
#        import Energia from "./Energia.jsx";
#   3) Elimina CUALQUIER BLOQUE mal inyectado con entidades:
#        &lt;div style={{margin:"10px 0"}}&gt; ... &lt;/div&gt;
#   4) Inserta (si no existe aún) un botón JSX correcto que navega a #/energia
#      justo después de la primera ocurrencia de <Hero ...> o, si no existe,
#      al inicio del primer return( … ).
#   5) Mantiene un early return ya existente (no lo toca) y NO usa variables
#      locales tipo `monitors` para evitar TDZ.
#   6) Limpia la caché de Vite y reinicia el dev server.
#
# Uso:
#   chmod +x ./fix-energia-entities-and-button.v1.sh
#   ./fix-energia-entities-and-button.v1.sh
# -----------------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEWS_DIR="$ROOT_DIR/src/views"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log() {  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()  {  echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){  echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() {  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

[ -f "$DASHBOARD_FILE" ] || { err "No existe: $DASHBOARD_FILE"; exit 1; }

# 1) Backup
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
ok "Backup: ${DASHBOARD_FILE}.backup.${TS}"

# 2) Normaliza imports de Energia (un solo default desde ./Energia.jsx)
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'"'"']\.[\.\/]*Energia\.default\.jsx["'"'"'][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'"'"']\.[\.\/]*Energia\.jsx["'"'"'][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]*\{[[:space:]]*Energia[[:space:]]*\}[[:space:]]*from[[:space:]]*["'"'"']\.[\.\/]*Energia\.jsx["'"'"'][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

FIRST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)"
if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"./Energia.jsx\";" "$DASHBOARD_FILE" || \
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"../views/Energia.jsx\";" "$DASHBOARD_FILE"
else
  { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
fi
ok "Import único de Energia normalizado"

# 3) Eliminar cualquier BLOQUE con entidades HTML mal inyectadas:
#    patrón: &lt;div style={{margin:"10px 0"}}&gt;  ...  &lt;/div&gt;
#    (si hay varios, elimina todos)
if grep -q '&lt;div style={{margin:"10px 0"}}&gt;' "$DASHBOARD_FILE"; then
  awk '
    BEGIN{ skip=0 }
    {
      if ($0 ~ /&lt;div style=\{\{margin:"10px 0"\}\}&gt;/) { skip=1; next }
      if (skip==1) {
        # nos saltamos líneas hasta encontrar el cierre en entidades
        if ($0 ~ /&lt;\/div&gt;/) { skip=0; next }
        next
      }
      print $0
    }
  ' "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
  ok "Bloque(s) con entidades mal inyectadas eliminados"
fi

# 4) Insertar un botón JSX correcto a #/energia si no existe aún
if ! grep -q 'href="#/energia"' "$DASHBOARD_FILE"; then
  # Preferencia: insertar justo debajo del primer <Hero
  if grep -n '<Hero' "$DASHBOARD_FILE" >/dev/null 2>&1; then
    TARGET_LINE="$(grep -n '<Hero' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1)"
    sed -i "$((TARGET_LINE+1))i \ \ \ \ <div style={{margin:\"10px 0\"}}>\n\ \ \ \ \ \ <a href=\"#/energia\" onClick={(e)=>{e.preventDefault(); window.location.hash=\"#/energia\";}}\n\ \ \ \ \ \ \ \ className=\"btn btn-primary\" style={{padding:\"6px 10px\", borderRadius:\"8px\"}}>\n\ \ \ \ \ \ \ \ Energía\n\ \ \ \ \ \ </a>\n\ \ \ \ </div>" "$DASHBOARD_FILE"
    ok "Botón JSX a #/energia inyectado junto a <Hero>"
  else
    # Fallback: meterlo tras el primer return(
    START_RETURN_LINE="$(grep -n 'return[[:space:]]*(' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1 || true)"
    if [ -n "${START_RETURN_LINE:-}" ]; then
      sed -i "$((START_RETURN_LINE+1))i \ \ <div style={{margin:\"10px 0\"}}>\n\ \ \ \ <a href=\"#/energia\" onClick={(e)=>{e.preventDefault(); window.location.hash=\"#/energia\";}}\n\ \ \ \ \ \ className=\"btn btn-primary\" style={{padding:\"6px 10px\", borderRadius:\"8px\"}}>\n\ \ \ \ \ \ Energía\n\ \ \ \ </a>\n\ \ </div>" "$DASHBOARD_FILE"
      ok "Botón JSX a #/energia inyectado en el return()"
    else
      warn "No pude ubicar <Hero> ni return(. Inserción del botón omitida."
    fi
  fi
else
  ok "Ya existe un enlace visible a #/energia (no se duplica)"
fi

# 5) Limpia caché y reinicia Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. El bloque con entidades (&lt; ... &gt;) fue removido y se insertó (si hacía falta) un botón JSX válido a #/energia. Refresca el navegador."
