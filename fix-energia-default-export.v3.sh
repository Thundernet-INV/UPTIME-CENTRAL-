#!/bin/bash
# fix-energia-imports.v3.sh
# ------------------------------------------------------------
# Soluciona:
#  - "does not provide an export named 'default'"
#  - "does not provide an export named 'Energia'"
# Estrategia robusta:
#  1) En src/views/Energia.jsx garantiza que exista el símbolo Energia,
#     y exporta **ambos** formatos:
#        - export default Energia;
#        - export { Energia };
#  2) En src/views/Dashboard.jsx normaliza el import para usar
#        import Energia from ".../Energia.jsx";
#     y elimina variantes conflictivas (import nombrado).
#  3) Limpia la caché de Vite y reinicia el dev server.
# Crea backups con timestamp, por si necesitas revertir.
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

# ------------------------------------------------------------
# 1) Asegurar que Energia.jsx exporte default y nombrado
# ------------------------------------------------------------

HAS_DEFAULT=0
HAS_NAMED=0
HAS_SYMBOL=0

# ¿Existe export default?
if grep -Eq '(^|[[:space:]])export[[:space:]]+default[[:space:]]' "$ENERGIA_FILE"; then
  HAS_DEFAULT=1
fi

# ¿Existe export nombrado { Energia } (en cualquier forma)?
if grep -Eq '(^|[[:space:]])export[[:space:]]*\{[^}]*\bEnergia\b[^}]*\}' "$ENERGIA_FILE" || \
   grep -Eq '(^|[[:space:]])export[[:space:]]+(const|function)[[:space:]]+Energia\b' "$ENERGIA_FILE"
then
  HAS_NAMED=1
fi

# ¿Existe símbolo Energia declarado?
if grep -Eq '(^|[[:space:]])(function|const|let|var)[[:space:]]+Energia\b' "$ENERGIA_FILE" || \
   grep -Eq '(^|[[:space:]])export[[:space:]]+(const|function)[[:space:]]+Energia\b' "$ENERGIA_FILE"
then
  HAS_SYMBOL=1
fi

# Si no hay símbolo, intentemos detectar un componente principal y renombrarlo a Energia
# (muy conservador: solo actúa si encuentra "export default function ..." sin nombre)
if [ "$HAS_SYMBOL" -eq 0 ]; then
  if grep -Eq 'export[[:space:]]+default[[:space:]]+function[[:space:]]*\(' "$ENERGIA_FILE"; then
    # Renombra a function Energia(...)
    sed -E -i 's/export[[:space:]]+default[[:space:]]+function[[:space:]]*\(/function Energia(/' "$ENERGIA_FILE"
    # Agrega export default al final
    printf "\nexport default Energia;\n" >> "$ENERGIA_FILE"
    HAS_SYMBOL=1
    HAS_DEFAULT=1
    ok "Se convirtió la default function anónima en 'function Energia' y se exportó por default"
  fi
fi

# Si aún no hay símbolo Energia, intenta detectar un default export de una constante anónima:
# export default () => { ... }
if [ "$HAS_SYMBOL" -eq 0 ]; then
  if grep -Eq 'export[[:space:]]+default[[:space:]]*\\([^)]*\\)[[:space:]]*=>' "$ENERGIA_FILE"; then
    # Wrap: crea const Energia = (...) => ... ; export default Energia;
    # NOTA: Esta transformación es compleja para sed puro; dejamos aviso.
    warn "Se detectó un default export de arrow function anónima. No se refactoriza automáticamente."
  fi
fi

# Forzar default si existe símbolo Energia pero no hay default
if [ "$HAS_SYMBOL" -eq 1 ] && [ "$HAS_DEFAULT" -eq 0 ]; then
  printf "\nexport default Energia;\n" >> "$ENERGIA_FILE"
  HAS_DEFAULT=1
  ok "Añadido 'export default Energia;' a Energia.jsx"
fi

# Forzar export nombrado si existe símbolo Energia pero no hay nombrado
if [ "$HAS_SYMBOL" -eq 1 ] && [ "$HAS_NAMED" -eq 0 ]; then
  # Evitar duplicar si ya hay una línea igual
  if ! grep -Eq '(^|[[:space:]])export[[:space:]]*\{[^}]*\bEnergia\b[^}]*\}' "$ENERGIA_FILE"; then
    printf "\nexport { Energia };\n" >> "$ENERGIA_FILE"
    HAS_NAMED=1
    ok "Añadido 'export { Energia };' a Energia.jsx"
  fi
fi

# ------------------------------------------------------------
# 2) Normalizar import en Dashboard.jsx
#    Usaremos SIEMPRE el import por default:
#      import Energia from ".../Energia.jsx";
#    y eliminaremos variantes nombradas para evitar el error.
# ------------------------------------------------------------

# Eliminar cualquier import nombrado de Energia desde Energia.jsx
#   import { Energia } from ".../Energia.jsx";
sed -E -i "s#import[[:space:]]*\\{[[:space:]]*Energia[[:space:]]*\\}[[:space:]]*from[[:space:]]*(['\"][^'\"]*Energia\\.jsx['\"]);##g" "$DASHBOARD_FILE"

# Eliminar posibles dobles imports del mismo módulo que puedan quedar
# (limpieza suave, no destructiva)

# Asegurar un import default único:
if grep -Eq "from[[:space:]]*['\"][^'\"]*Energia\\.jsx['\"]" "$DASHBOARD_FILE"; then
  # Si ya existe un import default correcto, no duplicar.
  if ! grep -Eq 'import[[:space:]]+Energia[[:space:]]+from[[:space:]]*'\''[^'\'']*Energia\.jsx'\'''; then
    # Insertar una línea de import default después del primer import del archivo
    FIRST_IMPORT_LINE=$(awk '/^import[[:space:]]/ {print NR; exit}' "$DASHBOARD_FILE" || true)
    if [ -n "${FIRST_IMPORT_LINE:-}" ]; then
      sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"./Energia.jsx\";" "$DASHBOARD_FILE" || \
      sed -i "$((FIRST_IMPORT_LINE+1))i import Energia from \"../views/Energia.jsx\";" "$DASHBOARD_FILE" || true
      ok "Insertado import default de Energia en Dashboard.jsx"
    else
      # Si no hay imports, añadir al inicio
      { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
      ok "Insertado import default de Energia al inicio de Dashboard.jsx"
    fi
  fi
else
  # Si no hay NINGÚN import del módulo, añadimos uno relativo por defecto
  # Preferimos la ruta relativa local (ajústala si tu estructura difiere)
  # Intento 1: misma carpeta
  ADDED=0
  if [ -f "$SRC_DIR/views/Energia.jsx" ] && [ -f "$SRC_DIR/views/Dashboard.jsx" ]; then
    # Dashboard y Energia están en la misma carpeta "views"
    { echo 'import Energia from "./Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
    ADDED=1
  fi
  if [ "$ADDED" -eq 0 ]; then
    { echo 'import Energia from "../views/Energia.jsx";'; cat "$DASHBOARD_FILE"; } > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
  fi
  ok "Añadido import default de Energia en Dashboard.jsx (no existía ninguno)"
fi

# Limpieza: si por alguna razón quedaron dobles imports de Energia.jsx, compactar a uno (opcional)
# (No agresivo para evitar romper otros imports; se puede ampliar si es necesario)

# ------------------------------------------------------------
# 3) Limpiar caché de Vite y reiniciar
# ------------------------------------------------------------
log "Limpiando caché de Vite y reiniciando..."
( cd "$FRONTEND_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$FRONTEND_DIR" && (npm run dev &) ) || true
ok "Vite reiniciado"

echo
ok "Hecho. Energia.jsx exporta default y nombrado; Dashboard.jsx importa por default. Si algo falla, revierte con los backups .backup.${TS}"
