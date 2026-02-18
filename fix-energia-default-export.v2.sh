#!/bin/bash
# fix-energia-default-export.v2.sh
# ------------------------------------------------------------
# Arregla el error:
#   "The requested module '/src/views/Energia.jsx' does not provide an export named 'default'"
# Estrategia:
#  1) Si es posible, añade `export default Energia;` a src/views/Energia.jsx
#  2) Según el caso, ajusta en src/views/Dashboard.jsx el import:
#       - con default:   import Energia from ".../Energia.jsx";
#       - sin default:   import { Energia } from ".../Energia.jsx";
#  3) Limpia la caché de Vite y reinicia el dev server.
# Seguro y reversible: crea backups con timestamp.
# ------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$ROOT_DIR"
SRC_DIR="$FRONTEND_DIR/src"
ENERGIA_FILE="$SRC_DIR/views/Energia.jsx"
DASHBOARD_FILE="$SRC_DIR/views/Dashboard.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){  echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERR ]\033[0m $*"; }

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

ensure_file "$ENERGIA_FILE"
ensure_file "$DASHBOARD_FILE"

backup "$ENERGIA_FILE"
backup "$DASHBOARD_FILE"

HAS_DEFAULT=0

# 1) Detectar si Energia.jsx ya tiene export default
if grep -Eq '(^|[[:space:]])export[[:space:]]+default[[:space:]]' "$ENERGIA_FILE"; then
  HAS_DEFAULT=1
  log "Energia.jsx ya posee export default"
else
  # 1a) Intentar forzar default si existe el símbolo 'Energia'
  if grep -Eq '(^|[[:space:]])export[[:space:]]+(const|function)[[:space:]]+Energia\b' "$ENERGIA_FILE" || \
     grep -Eq '(^|[[:space:]])(function|const|let|var)[[:space:]]+Energia\b' "$ENERGIA_FILE"; then
    printf "\nexport default Energia;\n" >> "$ENERGIA_FILE"
    HAS_DEFAULT=1
    ok "Se añadió 'export default Energia;' a Energia.jsx"
  else
    warn "No se encontró un símbolo 'Energia' declarable como default en Energia.jsx; no se puede forzar default."
  fi
fi

# 2) Ajustar import en Dashboard.jsx según el caso
if [ "$HAS_DEFAULT" -eq 1 ]; then
  # Forzar import default si hubiese un import nombrado
  #   import { Energia } from ".../Energia.jsx";  -> import Energia from ".../Energia.jsx";
  sed -E -i "s#import[[:space:]]*\\{[[:space:]]*Energia[[:space:]]*\\}[[:space:]]*from[[:space:]]*(['\"][^'\"]*Energia\\.jsx['\"]);#import Energia from \\1;#g" "$DASHBOARD_FILE"
  ok "Dashboard.jsx ajustado para usar import default de Energia"
else
  # No hay default -> asegurar import nombrado si hubiese default
  #   import Energia from ".../Energia.jsx"; -> import { Energia } from ".../Energia.jsx";
  sed -E -i "s#import[[:space:]]+Energia[[:space:]]+from[[:space:]]*(['\"][^'\"]*Energia\\.jsx['\"]);#import { Energia } from \\1;#g" "$DASHBOARD_FILE"
  ok "Dashboard.jsx ajustado para usar import nombrado { Energia }"
fi

# 3) Limpiar caché de Vite y reiniciar
log "Limpiando caché de Vite y reiniciando..."
( cd "$FRONTEND_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$FRONTEND_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Listo. Si deseas revertir, usa los backups con sufijo .backup.${TS} en Energia.jsx y Dashboard.jsx"
