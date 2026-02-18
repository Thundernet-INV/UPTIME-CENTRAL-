#!/bin/bash
# fix-energia-gate-regex.sh
# -------------------------------------------------------------------
# Corrige el error de RegExp en Dashboard.jsx (flag inválido) y
# deja un detector de ruta #/energia robusto SIN regex.
#
# Qué hace:
#   1) Backup de src/views/Dashboard.jsx
#   2) Elimina cualquier definición previa de isEnergiaRoute()/__ENERGIA_GATE_V5__/V4
#   3) Inserta una nueva utilidad isEnergiaRoute() (sin regex) y mantiene
#      el early-return de <Energia .../> cuando corresponda.
#   4) Asegura UN SOLO "import Energia from './Energia.jsx';"
#   5) Limpia caché de Vite y reinicia dev server.
#
# Uso:
#   chmod +x ./fix-energia-gate-regex.sh
#   ./fix-energia-gate-regex.sh
# -------------------------------------------------------------------

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

# 1) Backup
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
ok "Backup: ${DASHBOARD_FILE}.backup.${TS}"

# 2) Saneamos imports duplicados de Energia y quitamos Energia.default.jsx
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\'']\.[\.\/]*Energia\.default\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\'']\.[\.\/]*Energia\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i '/^[[:space:]]*import[[:space:]]*\{[[:space:]]*Energia[[:space:]]*\}[[:space:]]*from[[:space:]]*["'\'']\.[\.\/]*Energia\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

# Insertar UN SOLO import default justo debajo del primer import del archivo
FIRST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)"
if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"./Energia.jsx\";" "$DASHBOARD_FILE" || \
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"../views/Energia.jsx\";" "$DASHBOARD_FILE"
else
  { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
fi
ok "Import único de Energia normalizado"

# 3) Eliminar definiciones previas de detectores/gates con regex o marcadores antiguos
#    - Remueve bloques que contengan __ENERGIA_GATE_V5__/__ENERGIA_GATE_V4__ o función isEnergiaRoute antigua
#    - Remueve la vieja línea con la regex inválida si quedó
sed -E -i '/__ENERGIA_GATE_V5__|__ENERGIA_GATE_V4__/d' "$DASHBOARD_FILE"
sed -E -i '/const[[:space:]]+isEnergiaRoute[[:space:]]*=\s*\(\)\s*=>\s*\{/,/^\};[[:space:]]*$/d' "$DASHBOARD_FILE"
sed -E -i 's#return[[:space:]]*/\^\#.*inversor\)\)\?\$\$/i\.test\(h\);#return false;#g' "$DASHBOARD_FILE" || true

# 4) Insertar NUEVA utilidad isEnergiaRoute SIN REGEX (después de imports)
LAST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {li=NR} END{print li+0}' "$DASHBOARD_FILE")"
if [ "$LAST_IMPORT_LINE" -gt 0 ]; then
  sed -i "$((LAST_IMPORT_LINE+1))i \
const __ENERGIA_GATE_V6__ = true;\\n\
const isEnergiaRoute = () => {\\n\
  try {\\n\
    const h = ((typeof window !== 'undefined' ? window.location.hash : '') || '').toLowerCase();\\n\
    if (!h.startsWith('#/energia')) return false;\\n\
    const segs = h.replace(/^#\\//,'').split('/'); // ['energia'] o ['energia', 'slug']\\n\
    if (segs.length === 1) return true;\\n\
    const slug = segs[1] || '';\\n\
    return ['avr','corpoelec','plantas','inversor'].includes(slug);\\n\
  } catch { return false; }\\n\
};" "$DASHBOARD_FILE"
  ok "Insertada utilidad isEnergiaRoute (sin regex)"
else
  warn "No se detectaron imports; no pude insertar utilidad tras imports."
fi

# 5) Insertar EARLY RETURN si no existe aún (dentro del componente Dashboard)
if ! grep -q "EARLY RETURN para ruta de Energía v6" "$DASHBOARD_FILE"; then
  LINE_DECL="$(awk '
    /export[[:space:]]+default[[:space:]]+function[[:space:]]+Dashboard[[:space:]]*\(/ {print NR; exit}
    /function[[:space:]]+Dashboard[[:space:]]*\(/ {print NR; exit}
    /const[[:space:]]+Dashboard[[:space:]]*=[[:space:]]*\(/ {print NR; exit}
  ' "$DASHBOARD_FILE")"

  if [ -n "$LINE_DECL" ]; then
    BODY_START="$(awk -v s="$LINE_DECL" 'NR>=s { if (index($0,"{")) {print NR; exit} }' "$DASHBOARD_FILE")"
    [ -z "$BODY_START" ] && BODY_START="$LINE_DECL"

    awk -v ins="$BODY_START" '
      NR==ins {
        print $0
        print "  // EARLY RETURN para ruta de Energía v6"
        print "  if (typeof isEnergiaRoute === \"function\" && isEnergiaRoute()) {"
        print "    const cand = (typeof monitors !== \"undefined\" ? monitors : (typeof props !== \"undefined\" ? (props.monitorsAll || props.monitors || []) : []));"
        print "    return <Energia monitorsAll={cand} />;"
        print "  }"
        next
      }
      { print }
    ' "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
    ok "Early return insertado en el componente Dashboard"
  else
    warn "No pude localizar la declaración del componente Dashboard; omito el early return."
  fi
else
  ok "El early return ya estaba presente (no se duplica)."
fi

# 6) Asegurar que cualquier enlace a Energía use #/energia
sed -E -i "s#(href=)[\"'][^\"']*([Ee]nergia|[Ee]nergía)[^\"']*[\"']#\\1\"#/energia\"#g" "$DASHBOARD_FILE" || true

# 7) Reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Arreglo aplicado. Ve a #/energia (o pulsa en 'Energía') para que Dashboard renderice la vista."
