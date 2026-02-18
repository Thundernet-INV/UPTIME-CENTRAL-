#!/bin/bash
# fix-energia-tdz.sh
# ------------------------------------------------------------
# Arregla el error:
#   ReferenceError: Cannot access 'monitors' before initialization
# Causa: el "early return" insertado en Dashboard.jsx hace referencia
# a la variable local `monitors` ANTES de que sea declarada (TDZ).
#
# Solución:
#  1) Reescribe el bloque del EARLY RETURN para que NO toque la
#     variable `monitors`. En su lugar, usa solo `props` de Dashboard.
#     -> const cand = (props?.monitorsAll || props?.monitors || []);
#  2) Si no existe `props` (por cómo está declarada la función), usa
#     `arguments[0]` para obtener las props de forma segura.
#  3) Mantiene el detector isEnergiaRoute SIN regex.
#  4) Deja UN SOLO import:  import Energia from "./Energia.jsx";
#  5) Limpia caché de Vite y reinicia.
#
# Uso:
#   chmod +x ./fix-energia-tdz.sh
#   ./fix-energia-tdz.sh
# ------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEWS_DIR="$ROOT_DIR/src/views"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

[ -f "$DASHBOARD_FILE" ] || { err "No existe: $DASHBOARD_FILE"; exit 1; }

# 0) Backup
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
ok "Backup: ${DASHBOARD_FILE}.backup.${TS}"

# 1) Normaliza a UN SOLO import default (elimina duplicados y shims)
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
ok "Import único de Energia en Dashboard.jsx"

# 2) Elimina detectores/gates anteriores para reconstruirlos limpios
sed -E -i '/__ENERGIA_GATE_V[0-9]+__/d' "$DASHBOARD_FILE"
sed -E -i '/const[[:space:]]+isEnergiaRoute[[:space:]]*=\s*\(\)\s*=>\s*\{/,/^\};[[:space:]]*$/d' "$DASHBOARD_FILE"

# 3) Inserta utilidad isEnergiaRoute (SIN REGEX) después de los imports
LAST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {li=NR} END{print li+0}' "$DASHBOARD_FILE")"
if [ "$LAST_IMPORT_LINE" -gt 0 ]; then
  sed -i "$((LAST_IMPORT_LINE+1))i \
const __ENERGIA_GATE_V8__ = true;\\n\
const isEnergiaRoute = () => {\\n\
  try {\\n\
    const hRaw = (typeof window !== 'undefined' ? (window.location.hash || '') : '');\\n\
    const h = hRaw.toLowerCase();\\n\
    if (!h.startsWith('#/energia')) return false;\\n\
    const rest = h.slice(2);                 // 'energia' o 'energia/slug'\\n\
    const segs = rest.split('/');\\n\
    if (segs[0] !== 'energia') return false;\\n\
    if (segs.length === 1) return true;      // justo #/energia\\n\
    const slug = segs[1] || '';\\n\
    return ['avr','corpoelec','plantas','inversor'].includes(slug);\\n\
  } catch { return false; }\\n\
};" "$DASHBOARD_FILE"
  ok "Insertada utilidad isEnergiaRoute (v8, sin regex)"
else
  warn "No se detectaron imports; no se pudo insertar la utilidad tras imports."
fi

# 4) Reconstruye el EARLY RETURN sin tocar la variable local `monitors`
#    Reemplaza bloques anteriores por uno que use SOLO props/arguments[0]
#    y así evitar TDZ.
TMP_OUT="${DASHBOARD_FILE}.tmp.${TS}"

awk '
  BEGIN { inserted=0; startDecl=0; braceLine=0 }
  # Detecta declaración del componente Dashboard
  /export[[:space:]]+default[[:space:]]+function[[:space:]]+Dashboard[[:space:]]*\(/ { startDecl=NR }
  /function[[:space:]]+Dashboard[[:space:]]*\(/ { if(!startDecl) startDecl=NR }
  /const[[:space:]]+Dashboard[[:space:]]*=[[:space:]]*\(/ { if(!startDecl) startDecl=NR }

  {
    print $0
    if (!inserted && startDecl>0 && NR>=startDecl && index($0,"{")) {
      # Insertar inmediatamente después de la primera llave "{"
      print "  // EARLY RETURN para ruta de Energía v8 (sin tocar variable local `monitors`)"
      print "  if (typeof isEnergiaRoute === \"function\" && isEnergiaRoute()) {"
      print "    const __p = (typeof props !== \"undefined\" && props) ? props : (arguments && arguments[0] ? arguments[0] : {});"
      print "    const cand = (__p.monitorsAll || __p.monitors || []);"
      print "    return <Energia monitorsAll={cand} />;"
      print "  }"
      inserted=1
    }
  }
' "$DASHBOARD_FILE" > "$TMP_OUT" && mv "$TMP_OUT" "$DASHBOARD_FILE"

if [ $inserted -ne 0 ] 2>/dev/null; then
  : # noop
else
  ok "Se insertó el EARLY RETURN v8"
fi

# 5) (Opcional) Asegura que cualquier link visible a Energía use #/energia
sed -E -i "s#(href=)[\"'][^\"']*([Ee]nergia|[Ee]nergía)[^\"']*[\"']#\\1\"#/energia\"#g" "$DASHBOARD_FILE" || true

# 6) Reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Arreglo aplicado. El TDZ desaparece al no referenciar `monitors` antes de tiempo. Abre #/energia para ver la vista."
