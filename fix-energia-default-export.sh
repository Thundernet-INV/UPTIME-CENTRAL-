#!/bin/bash
# fix-energia-default-export.sh
# ------------------------------------------------------------
# Arregla el error:
#   "The requested module '/src/views/Energia.jsx' does not provide an export named 'default'"
# Forzando un export default en Energia.jsx (si es posible) o
# ajustando el import en Dashboard.jsx a un import nombrado { Energia }.
# También limpia la caché de Vite y reinicia el dev server.
# ------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$ROOT_DIR"
SRC_DIR="$FRONTEND_DIR/src"
ENERGIA_FILE="$SRC_DIR/views/Energia.jsx"
DASHBOARD_FILE="$SRC_DIR/views/Dashboard.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

log(){ echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok(){ echo -e "\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERR ]\033[0m $*"; }

ensure_file(){ local f="$1"; if [ ! -f "$f" ]; then err "No existe: $f"; exit 1; fi }
backup(){ local f="$1"; local b="${f}.backup.${TS}"; cp "$f" "$b"; ok "Backup: $b"; }

main(){
  ensure_file "$ENERGIA_FILE"
  ensure_file "$DASHBOARD_FILE"

  backup "$ENERGIA_FILE"
  backup "$DASHBOARD_FILE"

  HAS_DEFAULT=0
  if grep -qE "(^|[[:space:]])export[[:space:]]+default[[:space:]]" "$ENERGIA_FILE"; then
    HAS_DEFAULT=1
    log "Energia.jsx ya tiene export default"
  else
    # Detectar definiciones comunes del componente principal
    if grep -qE "(^|[[:space:]])export[[:space:]]+(const|function)[[:space:]]+Energia\b" "$ENERGIA_FILE" || \
       grep -qE "(^|[[:space:]])(function|const|let|var)[[:space:]]+Energia\b" "$ENERGIA_FILE"; then
      echo -e "\nexport default Energia;" >> "$ENERGIA_FILE"
      HAS_DEFAULT=1
      ok "Se añadió 'export default Energia;' a Energia.jsx"
    else
      warn "No se encontró símbolo 'Energia' exportable en Energia.jsx; no se puede forzar default"
    fi
  fi

  if [ $HAS_DEFAULT -eq 1 ]; then
    # Asegurar import por default en Dashboard.jsx
    # Cambiar: import { Energia } from ".../Energia.jsx";  -> import Energia from ".../Energia.jsx";
    perl -0777 -pe 's/import\s*\{\s*Energia\s*\}\s*from\s*(["\'][^"\']*Energia\.jsx["\']);/import Energia from \1;/g' -i "$DASHBOARD_FILE"
    ok "Dashboard.jsx ajustado para usar import default de Energia"
  else
    # No hay default posible -> asegurar import nombrado en Dashboard.jsx
    # Cambiar: import Energia from ".../Energia.jsx"; -> import { Energia } from ".../Energia.jsx";
    perl -0777 -pe 's/import\s+Energia\s+from\s*(["\'][^"\']*Energia\.jsx["\']);/import { Energia } from \1;/g' -i "$DASHBOARD_FILE"
    ok "Dashboard.jsx ajustado para usar import nombrado { Energia }"
  fi

  # Limpieza y reinicio Vite
  log "Limpiando caché de Vite y reiniciando..."
  (cd "$FRONTEND_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true)
  pkill -f "vite" 2>/dev/null || true
  (cd "$FRONTEND_DIR" && (npm run dev &))
  ok "Vite reiniciado"

  echo
  ok "Listo: export/import corregidos. Si algo falla, usa los backups .backup.${TS}"
}

main "$@"
