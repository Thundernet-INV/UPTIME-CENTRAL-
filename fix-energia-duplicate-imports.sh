#!/bin/bash
# fix-energia-duplicate-imports.sh
# ------------------------------------------------------------
# Arregla el error:
#   Identifier 'Energia' has already been declared.
# Causa: imports duplicados de Energia en src/views/Dashboard.jsx
# Solución:
#   1) Elimina cualquier import desde "./Energia.default.jsx"
#   2) Elimina duplicados (default o nombrados) desde "./Energia.jsx"
#   3) Inserta UN SOLO:  import Energia from "./Energia.jsx";
#   4) Limpia caché de Vite y reinicia el dev server.
# Crea backup con timestamp.
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

# 1) Backup
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
ok "Backup: ${DASHBOARD_FILE}.backup.${TS}"

# 2) Eliminar import duplicado desde Energia.default.jsx
#    Ej.: import Energia from "./Energia.default.jsx";
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\'']\.[\.\/]*Energia\.default\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

# 3) Eliminar todos los imports de Energia desde Energia.jsx
#    (para reinsertar uno único y limpio).
#    a) default: import Energia from "./Energia.jsx";
sed -E -i '/^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]*["'\'']\.[\.\/]*Energia\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"
#    b) nombrado: import { Energia } from "./Energia.jsx";
sed -E -i '/^[[:space:]]*import[[:space:]]*\{[[:space:]]*Energia[[:space:]]*\}[[:space:]]*from[[:space:]]*["'\'']\.[\.\/]*Energia\.jsx["'\''][[:space:]]*;[[:space:]]*$/d' "$DASHBOARD_FILE"

# 4) Insertar UN SOLO import default desde "./Energia.jsx"
FIRST_IMPORT_LINE="$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)"
if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
  sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"./Energia.jsx\";" "$DASHBOARD_FILE" || {
    # fallback si falla la ruta relativa (poco probable)
    sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"../views/Energia.jsx\";" "$DASHBOARD_FILE"
  }
else
  # Si no hay imports, ponlo al inicio
  { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
fi
ok "Normalizado import único: import Energia from \"./Energia.jsx\";"

# 5) Limpieza de caché y reinicio de Vite
log "Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Imports de Energia saneados en Dashboard.jsx. Si deseas revertir: ${DASHBOARD_FILE}.backup.${TS}"
