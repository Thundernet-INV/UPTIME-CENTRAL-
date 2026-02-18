#!/bin/bash
# patch-energia-gate-v6-fix.sh
# -------------------------------------------------------------------
# Corrige el error de sintaxis en Dashboard.jsx (la línea quedó como
#   h.replace(/^#//,'')  <-- barra sobrante
# y deja un detector de ruta #/energia sin regex, estable.
#
# Además:
#   - Normaliza a UN SOLO: import Energia from "./Energia.jsx";
#   - Inserta (o reescribe) el early-return dentro de Dashboard()
#     para renderizar <Energia /> cuando el hash sea #/energia
#     o #/energia/<avr|corpoelec|plantas|inversor>.
#   - Limpia la caché de Vite y reinicia el dev server.
#
# USO:
#   chmod +x ./patch-energia-gate-v6-fix.sh
#   ./patch-energia-gate-v6-fix.sh
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

# 2) Quitar residuos de intentos anteriores (regex/flags y gates viejos)
#    - elimina utilidades anteriores y marcadores
sed -E -i '/__ENERGIA_GATE_V[0-9]+__/d' "$DASHBOARD_FILE"
sed -E -i '/const[[:space:]]+isEnergiaRoute[[:space:]]*=\s*\(\)\s*=>\s*\{/,/^\};[[:space:]]*$/d' "$DASHBOARD_FILE"
#    - elimina cualquier línea con .test(h) de la versión regex
sed -E -i 's#return[[:space:]]*/\^.*\$/i\.test\(h\);#return false;#g' "$DASHBOARD_FILE" || true

# 3) Normaliza imports: UN SOLO default desde "./Energia.jsx"
#    - borra import duplicados y el del shim default si existiera
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

# 4) Inserta NUEVA utilidad isEnergiaRoute (sin regex) después de imports
LAST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {li=NR} END{print li+0}' "$DASHBOARD_FILE")"
if [ "$LAST_IMPORT_LINE" -gt 0 ]; then
  sed -i "$((LAST_IMPORT_LINE+1))i \
const __ENERGIA_GATE_V7__ = true;\\n\
const isEnergiaRoute = () => {\\n\
  try {\\n\
    const hRaw = (typeof window !== 'undefined' ? (window.location.hash || '') : '');\\n\
    const h = hRaw.toLowerCase();\\n\
    if (!h.startsWith('#/energia')) return false;\\n\
    // Quita \"#/\" inicial y separa segmentos\\n\
    const rest = h.slice(2);                // 'energia' o 'energia/slug'\\n\
    const segs = rest.split('/');\\n\
    if (segs[0] !== 'energia') return false;\\n\
    if (segs.length === 1) return true;     // justo #/energia\\n\
    const slug = segs[1] || '';\\n\
    return ['avr','corpoelec','plantas','inversor'].includes(slug);\\n\
  } catch { return false; }\\n\
};" "$DASHBOARD_FILE"
  ok "Insertada utilidad isEnergiaRoute (sin regex, v7)"
else
  warn "No se detectaron imports; no pude insertar la utilidad tras imports."
fi

# 5) Inserta EARLY RETURN dentro del componente Dashboard si no existe
if ! grep -q "EARLY RETURN para ruta de Energía v7" "$DASHBOARD_FILE"; then
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
        print "  // EARLY RETURN para ruta de Energía v7"
        print "  if (typeof isEnergiaRoute === \"function\" && isEnergiaRoute()) {"
        print "    const cand = (typeof monitors !== \"undefined\" ? monitors : (typeof props !== \"undefined\" ? (props.monitorsAll || props.monitors || []) : []));"
        print "    return <Energia monitorsAll={cand} />;"
        print "  }"
        next
      }
      { print }
    ' "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
    ok "Early return insertado en Dashboard.jsx"
  else
    warn "No pude localizar la declaración del componente Dashboard; omito el early return."
  fi
else
  ok "Early return ya estaba presente (no se duplica)."
fi

# 6) (Opcional) Actualiza cualquier link visible a Energía -> #/energia
sed -E -i "s#(href=)[\"'][^\"']*([Ee]nergia|[Ee]nergía)[^\"']*[\"']#\\1\"#/energia\"#g" "$DASHBOARD_FILE" || true

# 7) Reiniciar Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Corregido el detector de ruta. Abre #/energia en el navegador para ver la vista de Energía."
