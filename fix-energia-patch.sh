#!/usr/bin/env bash
set -euo pipefail

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASH="$FRONTEND_DIR/src/views/Dashboard.jsx"
BACKUP="$DASH.bak.$(date +%Y%m%d_%H%M%S)"

echo "📦 Backup → $BACKUP"
cp "$DASH" "$BACKUP"

# Leer archivo completo en un array (línea por línea)
mapfile -t LINES < "$DASH"

# -------------------------------
# 1) Eliminar TODOS los imports previos de Energia
# -------------------------------
FILTERED=()
for line in "${LINES[@]}"; do
  if [[ "$line" =~ ^[[:space:]]*import[[:space:]]+Energia[[:space:]]+from[[:space:]]+\"./Energia\.jsx\"[[:space:]]*;[[:space:]]*$ ]]; then
    continue
  fi
  FILTERED+=("$line")
done

# -------------------------------
# 2) Insertar UN import único después del último import
# -------------------------------
last_import=-1
for i in "${!FILTERED[@]}"; do
  [[ "${FILTERED[$i]}" =~ ^[[:space:]]*import[[:space:]]+ ]] && last_import=$i
done

OUT=()
if (( last_import >= 0 )); then
  # Copiamos hasta el último import
  for i in $(seq 0 $last_import); do OUT+=("${FILTERED[$i]}"); done
  OUT+=('import Energia from "./Energia.jsx";')
  # Copiamos lo que sigue
  for i in $(seq $((last_import+1)) $(( ${#FILTERED[@]} - 1 )) ); do OUT+=("${FILTERED[$i]}"); done
else
  # No había imports, lo ponemos arriba
  OUT+=('import Energia from "./Energia.jsx";')
  for i in "${!FILTERED[@]}"; do OUT+=("${FILTERED[$i]}"); done
fi

# -------------------------------
# 3) Comentar cualquier declaración local "const Energia" o "function Energia"
# -------------------------------
for i in "${!OUT[@]}"; do
  if [[ "${OUT[$i]}" =~ ^[[:space:]]*const[[:space:]]+Energia\> ]] || \
     [[ "${OUT[$i]}" =~ ^[[:space:]]*function[[:space:]]+Energia\> ]]; then
    OUT[$i]="// ${OUT[$i]}"
  fi
done

# -------------------------------
# 4) Inyectar render condicional para route.name === "energia" si no existe
# -------------------------------
has_render=0
for line in "${OUT[@]}"; do
  [[ "$line" == *'<Energia monitorsAll={monitors} />'* ]] && has_render=1 && break
done

if (( has_render == 0 )); then
  TMP=()
  injected=0
  for line in "${OUT[@]}"; do
    if (( injected == 0 )) && [[ "$line" =~ return[[:space:]]*\( ]]; then
      TMP+=('if (route?.name === "energia") { return <Energia monitorsAll={monitors} />; }')
      injected=1
    fi
    TMP+=("$line")
  done
  OUT=("${TMP[@]}")
fi

# -------------------------------
# 5) Si ya mapeas "#/comparar", agrega mapeo para "#/energia"
# -------------------------------
has_map_comparar=0
has_map_energia=0
for line in "${OUT[@]}"; do
  [[ "$line" == *'#/comparar'* ]] && has_map_comparar=1
  [[ "$line" == *'name === "energia"'* || "$line" == *'name: "energia"'* ]] && has_map_energia=1
done

if (( has_map_comparar == 1 && has_map_energia == 0 )); then
  TMP=()
  inserted=0
  for line in "${OUT[@]}"; do
    TMP+=("$line")
    if (( inserted == 0 )) && [[ "$line" == *'#/comparar'* ]]; then
      TMP+=('    if (hash.startsWith("#/energia")) return { name: "energia" };')
      inserted=1
    fi
  done
  OUT=("${TMP[@]}")
fi

# -------------------------------
# 6) Guardar cambios
# -------------------------------
printf "%s\n" "${OUT[@]}" > "$DASH"
echo "✅ Dashboard.jsx reparado (import único + render + routing)."

# -------------------------------
# 7) Reiniciar Vite sin bloquear
# -------------------------------
cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite 2>/dev/null || true
pkill -f vite 2>/dev/null || true
nohup npm run dev >/tmp/kuma-ui-vite.log 2>&1 &
echo "🚀 Dev server reiniciado. Log: /tmp/kuma-ui-vite.log"
