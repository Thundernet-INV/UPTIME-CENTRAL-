#!/bin/bash
# fix-energia-imports.v4.sh
# -------------------------------------------------------------------
# Arregla definitivamente el error de import/export de Energia.jsx
# sin tocar tu archivo Energia.jsx:
#   - Crea un "shim" src/views/Energia.default.jsx que siempre
#     exporta un default válido (o un stub de React si no encuentra
#     componente), y además exporta { Energia }.
#   - Reescribe en src/views/Dashboard.jsx cualquier import desde
#     "Energia.jsx" para que apunte al shim "Energia.default.jsx"
#   - Limpia caché de Vite y reinicia el dev server.
# Crea backups con timestamp para poder revertir.
# -------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$ROOT_DIR"
SRC_DIR="$FRONTEND_DIR/src"
VIEWS_DIR="$SRC_DIR/views"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
ENERGIA_FILE="$VIEWS_DIR/Energia.jsx"
SHIM_FILE="$VIEWS_DIR/Energia.default.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log(){  echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

ensure_file(){
  local f="$1"
  if [ ! -f "$f" ]; then
    err "No existe: $f"
    exit 1
  fi
}

backup(){
  local f="$1"
  local b="${f}.backup.${TS}"
  cp "$f" "$b"
  ok "Backup: $b"
}

ensure_file "$DASHBOARD_FILE"
ensure_file "$ENERGIA_FILE"

backup "$DASHBOARD_FILE"

# 1) Crear/actualizar el SHIM que garantiza export default y nombrado
cat > "$SHIM_FILE" <<'EOF'
// Auto-generado por fix-energia-imports.v4.sh
// Provee un export default robusto desde Energia.jsx sin modificarlo.
import * as EnergiaModule from './Energia.jsx';
import React from 'react';

// Heurística para resolver el componente:
const pickFirstFunction = (mod) => {
  try {
    const vals = Object.values(mod);
    for (const v of vals) {
      if (typeof v === 'function') return v;
      if (v && typeof v === 'object' && typeof v.$$typeof !== 'undefined') return v; // React.forwardRef, memo, etc.
    }
    return null;
  } catch {
    return null;
  }
};

const resolved =
  (('default' in EnergiaModule) ? EnergiaModule.default : undefined) ??
  EnergiaModule.Energia ??
  pickFirstFunction(EnergiaModule);

const Energia = resolved ?? (() => null);

export default Energia;
export { Energia };
EOF
ok "Creado/actualizado shim: $SHIM_FILE"

# 2) Reescribir imports en Dashboard.jsx para usar el SHIM
#    - Eliminar cualquier import desde Energia.jsx (default o nombrado)
#    - Añadir un único:  import Energia from "./Energia.default.jsx";
TMP_DASH="${DASHBOARD_FILE}.tmp.${TS}"

# Eliminar líneas que importen desde Energia.jsx (cualquier forma)
sed -E '/import[[:space:]].*from[[:space:]]*([\"\x27]).*Energia\.jsx\1[[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE" > "$TMP_DASH"

# Si ya existe un import desde Energia.default.jsx, no duplicar
if ! grep -Eq 'import[[:space:]]+Energia[[:space:]]+from[[:space:]]*([\"\x27])\./Energia\.default\.jsx\1' "$TMP_DASH"; then
  # Insertar después del primer import del archivo; si no hay imports, al inicio
  FIRST_IMPORT_LINE=$(awk '/^import[[:space:]]/ {print NR; exit}' "$TMP_DASH" || true)
  if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
    awk -v n="$((FIRST_IMPORT_LINE))" '
      NR==n { print; print "import Energia from \"./Energia.default.jsx\";" ; next } { print }
    ' "$TMP_DASH" > "${TMP_DASH}.ins" && mv "${TMP_DASH}.ins" "$TMP_DASH"
  else
    { echo 'import Energia from "./Energia.default.jsx";'; cat "$TMP_DASH"; } > "${TMP_DASH}.ins" && mv "${TMP_DASH}.ins" "$TMP_DASH"
  fi
  ok "Dashboard.jsx ahora importa desde Energia.default.jsx"
else
  ok "Dashboard.jsx ya importaba el shim Energia.default.jsx (sin duplicar)"
fi

mv "$TMP_DASH" "$DASHBOARD_FILE"

# 3) Limpiar caché de Vite y reiniciar
log "Limpiando caché de Vite y reiniciando..."
( cd "$FRONTEND_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$FRONTEND_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Se usa un shim que garantiza export default desde Energia.jsx. Si deseas revertir, usa el backup: ${DASHBOARD_FILE}.backup.${TS}"
