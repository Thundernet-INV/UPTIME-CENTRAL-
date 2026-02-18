#!/bin/bash
# fix-energia-open.v1.sh
# -------------------------------------------------------------------
# Objetivo: que la pestaña / enlace **Energía** exista, apunte a `#/energia`
# y que al hacer click realmente renderice la vista (usando el gate ya insertado).
#
# Qué hace este script:
#  1) Verifica que existan los archivos clave de Energía (Energia.jsx + Overview/Detail/CSS/helpers).
#  2) Asegura que en Dashboard.jsx haya UN SOLO `import Energia from "./Energia.jsx";`
#     (limpia duplicados y cualquier import del shim Energia.default.jsx).
#  3) Inserta (o corrige) un **enlace visible** "Energía" en la barra de pestañas/top‑nav
#     de Dashboard.jsx que use `href="#/energia"` y un handler `onClick` que
#     solo haga `location.hash = "#/energia"`.
#     - Si no encuentra tu nav, agrega un botón fallback justo bajo el título.
#  4) Mantiene un **early return** seguro que NO toca `monitors` antes de tiempo,
#     usando solo `props/arguments[0]`.
#  5) Limpia caché de Vite y reinicia el dev server.
#
# Uso:
#   chmod +x ./fix-energia-open.v1.sh
#   ./fix-energia-open.v1.sh
# -------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT_DIR/src"
VIEWS_DIR="$SRC_DIR/views"

DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
ENERGIA_FILE="$VIEWS_DIR/Energia.jsx"
HELPERS_FILE="$VIEWS_DIR/Energia.metrics.helpers.js"
OVERVIEW_FILE="$VIEWS_DIR/EnergiaOverviewCards.jsx"
DETAIL_FILE="$VIEWS_DIR/EnergiaCategoryDetail.jsx"
CSS_FILE="$VIEWS_DIR/energia-cards-v4.css"
CSS_FILE_V5="$VIEWS_DIR/energia-cards-v5.css"
CSS_FILE_V3="$VIEWS_DIR/energia-cards-v3.css"

TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

need(){
  local f="$1"
  if [ ! -f "$f" ]; then err "No existe: $f"; exit 1; fi
}

# 0) Archivos necesarios para que la vista exista
need "$DASHBOARD_FILE"
need "$ENERGIA_FILE"
[ -f "$HELPERS_FILE" ] || warn "No se encontró $HELPERS_FILE (helpers). Continúo."
[ -f "$OVERVIEW_FILE" ] || warn "No se encontró $OVERVIEW_FILE (overview cards). Continúo."
[ -f "$DETAIL_FILE" ] || warn "No se encontró $DETAIL_FILE (detalle categoría). Continúo."
[ -f "$CSS_FILE" ] || [ -f "$CSS_FILE_V5" ] || [ -f "$CSS_FILE_V3" ] || warn "No se encontró el CSS de energía (v3/v4/v5). Continúo."

# 1) Backup de Dashboard.jsx
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
ok "Backup: ${DASHBOARD_FILE}.backup.${TS}"

# 2) Normaliza imports: UN SOLO default desde "./Energia.jsx"
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\'']\.[\.\/]*Energia\.default\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\'']\.[\.\/]*Energia\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]*\{[[:space:]]*Energia[[:space:]]*\}[[:space:]]*from[[:space:]]*["'\'']\.[\.\/]*Energia\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

FIRST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)"
if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"./Energia.jsx\";" "$DASHBOARD_FILE" || \
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"../views/Energia.jsx\";" "$DASHBOARD_FILE"
else
  { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
fi
ok "Import único de Energia normalizado"

# 3) Detector de ruta (sin regex) + early return seguro (NO usa variable local `monitors`)
#    Limpia intentos previos:
sed -E -i '/__ENERGIA_GATE_V[0-9]+__/d' "$DASHBOARD_FILE"
sed -E -i '/const[[:space:]]+isEnergiaRoute[[:space:]]*=\s*\(\)\s*=>\s*\{/,/^\};[[:space:]]*$/d' "$DASHBOARD_FILE"

LAST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {li=NR} END{print li+0}' "$DASHBOARD_FILE")"
if [ "$LAST_IMPORT_LINE" -gt 0 ]; then
  sed -i "$((LAST_IMPORT_LINE+1))i \
const __ENERGIA_GATE_V10__ = true;\\n\
const isEnergiaRoute = () => {\\n\
  try {\\n\
    const hRaw = (typeof window !== 'undefined' ? (window.location.hash || '') : '');\\n\
    const h = hRaw.toLowerCase();\\n\
    if (!h.startsWith('#/energia')) return false;\\n\
    const rest = h.slice(2); // 'energia' o 'energia/slug'\\n\
    const segs = rest.split('/');\\n\
    if (segs[0] !== 'energia') return false;\\n\
    if (segs.length === 1) return true;\\n\
    const slug = segs[1] || '';\\n\
    return ['avr','corpoelec','plantas','inversor'].includes(slug);\\n\
  } catch { return false; }\\n\
};" "$DASHBOARD_FILE"
  ok "Insertada utilidad isEnergiaRoute (v10, sin regex)"
fi

# Inserta early return al inicio del cuerpo de Dashboard()
TMP_OUT="${DASHBOARD_FILE}.tmp.${TS}"
awk '
  BEGIN { inserted=0; startDecl=0 }
  /export[[:space:]]+default[[:space:]]+function[[:space:]]+Dashboard[[:space:]]*\(/ { if(!startDecl) startDecl=NR }
  /function[[:space:]]+Dashboard[[:space:]]*\(/ { if(!startDecl) startDecl=NR }
  /const[[:space:]]+Dashboard[[:space:]]*=[[:space:]]*\(/ { if(!startDecl) startDecl=NR }

  {
    print $0
    if (!inserted && startDecl>0 && NR>=startDecl && index($0,"{")) {
      print "  // EARLY RETURN Energía v10 (no usa variable local `monitors`)"
      print "  if (typeof isEnergiaRoute === \"function\" && isEnergiaRoute()) {"
      print "    const __p = (typeof props !== \"undefined\" && props) ? props : (arguments && arguments[0] ? arguments[0] : {});"
      print "    const cand = (__p.monitorsAll || __p.monitors || []);"
      print "    return <Energia monitorsAll={cand} />;"
      print "  }"
      inserted=1
    }
  }
' "$DASHBOARD_FILE" > "$TMP_OUT" && mv "$TMP_OUT" "$DASHBOARD_FILE"
ok "Early return Energía v10 insertado"

# 4) Asegurar **link visible** a #/energia
#    Intento 1: si existe un nav con texto Energia/Energía, lo reescribo
sed -E -i "s#(href=)[\"'][^\"']*([Ee]nergia|[Ee]nergía)[^\"']*[\"']#\\1\"#/energia\"#g" "$DASHBOARD_FILE" || true

#    Intento 2 (fallback): si no existe nada con href="#/energia", inyecto un botón cerca del título/hero
if ! grep -q "href=\"#/energia\"" "$DASHBOARD_FILE"; then
  # Busco una línea típica de título o wrapper y meto un botón debajo
  # Marcadores comunes: <h1, <Hero, "Thunder Detector"
  awk '
    BEGIN { injected=0 }
    {
      print $0
      if (!injected && ($0 ~ /<Hero|Thunder Detector|<h1|<header/)) {
        print "      <div style={{margin:\"10px 0\"}}>"
        print "        <a href=\"#/energia\" onClick={(e)=>{e.preventDefault(); window.location.hash=\"#/energia\";}}"
        print "           className=\"btn btn-primary\" style={{padding:\"6px 10px\", borderRadius:\"8px\"}}>"
        print "          Energía"
        print "        </a>"
        print "      </div>"
        injected=1
      }
    }
  ' "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
  ok "Botón visible 'Energía' inyectado como fallback (href=\"#/energia\")"
else
  ok "Hay al menos un enlace visible a #/energia"
fi

# 5) Reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Deberías VER un enlace/botón 'Energía' en el Dashboard. Al pulsarlo te lleva a #/energia y se renderizan las cards."
echo "Si no aparece donde esperas, dime qué selector/trozo de JSX usa tu barra de pestañas y te genero un script que lo inserte exactamente ahí."
