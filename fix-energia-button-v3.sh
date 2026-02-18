
#!/bin/bash
# fix-energia-button-v3.sh
# -------------------------------------------------------------------
# Objetivo: corregir el error de JSX causado por entidades HTML
#           (&lt;div ...&gt;) que se inyectaron en Dashboard.jsx
#           y asegurar que exista un botón/enlace visible a #/energia.
#
# Qué hace:
#   1) Backup de src/views/Dashboard.jsx
#   2) Arregla el bloque mal inyectado convirtiendo entidades &lt; / &gt; a JSX real
#      SOLO si detecta el patrón del bloque.
#   3) Si no encuentra ese bloque, inserta un botón JSX correcto (no entidades)
#      cerca del área del HERO/título o como fallback tras el primer <main>/<section>.
#   4) Mantiene import único de Energia y NO toca variables locales (evita TDZ).
#   5) Limpia caché de Vite y reinicia el dev server.
#
# Uso:
#   chmod +x ./fix-energia-button-v3.sh
#   ./fix-energia-button-v3.sh
# -------------------------------------------------------------------

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIEWS_DIR="$ROOT_DIR/src/views"
DASHBOARD_FILE="$VIEWS_DIR/Dashboard.jsx"
TS="$(date +%Y%m%d_%H%M%S)"

echo -e "\033[1;34m[INFO]\033[0m Archivo objetivo: $DASHBOARD_FILE"
[ -f "$DASHBOARD_FILE" ] || { echo -e "\033[1;31m[ERR ]\033[0m No existe: $DASHBOARD_FILE"; exit 1; }

# 1) Backup
cp "$DASHBOARD_FILE" "${DASHBOARD_FILE}.backup.${TS}"
echo -e "\033[1;32m[OK]\033[0m Backup: ${DASHBOARD_FILE}.backup.${TS}"

# 2) Normaliza a UN SOLO import default de Energia (quita duplicados y shims)
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
echo -e "\033[1;32m[OK]\033[0m Import único de Energia normalizado"

# 3) Intento A: reparar el bloque con entidades (&lt; / &gt;) si existe
if grep -q '&lt;div style={{margin:"10px 0"}}&gt;' "$DASHBOARD_FILE"; then
  # Convierte solo la región del bloque (del <div ...> hasta "Energía" y cierre </a> / </div>)
  # Rango aproximado entre la línea con &lt;div style=... y la primera que contenga 'Energía' o '</div>'
  # Luego cambia entidades por JSX real.
  awk '
    BEGIN{inblock=0}
    {
      if ($0 ~ /&lt;div style=\{\{margin:"10px 0"\}\}&gt;/ && inblock==0) { inblock=1 }
      if (inblock==1) {
        gsub(/&lt;/,"<"); gsub(/&gt;/,">");
      }
      print $0
      if (inblock==1 && ($0 ~ /<\/div>/ || $0 ~ /Energía/)) {
        # Cerramos cuando encontramos el cierre o la palabra Energía (para cubrir el <a> y </div>)
        # Dejamos que salga al encontrar el PRIMER cierre de </div> posterior al bloque
        if ($0 ~ /<\/div>/) inblock=0
      }
    }
  ' "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp" && mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
  echo -e "\033[1;32m[OK]\033[0m Bloque con entidades HTML convertido a JSX real"
fi

# 4) Intento B: si NO existe el botón JSX a #/energia, inyectar uno correcto
if ! grep -q 'href="#/energia"' "$DASHBOARD_FILE"; then
  # Insertar después de un área probable: una línea que contenga <Hero o un comentario de HERO
  if grep -n '<Hero' "$DASHBOARD_FILE" >/dev/null 2>&1; then
    TARGET_LINE="$(grep -n '<Hero' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1)"
  elif grep -n 'HERO principal' "$DASHBOARD_FILE" >/dev/null 2>&1; then
    TARGET_LINE="$(grep -n 'HERO principal' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1)"
  else
    # Fallback: primera línea que contenga "<main" o "<section"
    TARGET_LINE="$(grep -n '<main\\|<section' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1 || true)"
  fi

  if [ -n "${TARGET_LINE:-}" ]; then
    # Inserta justo debajo del TARGET_LINE un bloque JSX verdadero
    sed -i "$((TARGET_LINE+1))i \ \ \ \ <div style={{margin:\"10px 0\"}}>\n\ \ \ \ \ \ <a href=\"#/energia\" onClick={(e)=>{e.preventDefault(); window.location.hash=\"#/energia\";}}\n\ \ \ \ \ \ \ \ className=\"btn btn-primary\" style={{padding:\"6px 10px\", borderRadius:\"8px\"}}>\n\ \ \ \ \ \ \ \ Energía\n\ \ \ \ \ \ </a>\n\ \ \ \ </div>" "$DASHBOARD_FILE"
    echo -e "\033[1;32m[OK]\033[0m Botón JSX a #/energia inyectado junto al HERO/área principal"
  else
    # Último fallback: insertar al inicio del return(
    START_RETURN_LINE="$(grep -n 'return[[:space:]]*(' "$DASHBOARD_FILE" | head -n1 | cut -d: -f1 || true)"
    if [ -n "${START_RETURN_LINE:-}" ]; then
      sed -i "$((START_RETURN_LINE+1))i \ \ <div style={{margin:\"10px 0\"}}>\n\ \ \ \ <a href=\"#/energia\" onClick={(e)=>{e.preventDefault(); window.location.hash=\"#/energia\";}}\n\ \ \ \ \ \ className=\"btn btn-primary\" style={{padding:\"6px 10px\", borderRadius:\"8px\"}}>\n\ \ \ \ \ \ Energía\n\ \ \ \ </a>\n\ \ </div>" "$DASHBOARD_FILE"
      echo -e "\033[1;32m[OK]\033[0m Botón JSX a #/energia inyectado dentro del return()"
    else
      echo -e "\033[1;33m[WARN]\033[0m No se pudo ubicar zona de inserción; omito el botón."
    fi
  fi
else
  echo -e "\033[1;32m[OK]\033[0m Ya existe un link visible a #/energia"
fi

# 5) Limpia caché y reinicia Vite
echo -e "\033[1;34m[INFO]\033[0m Limpiando caché de Vite y reiniciando..."
( cd "$ROOT_DIR" && rm -rf node_modules/.vite .vite 2>/dev/null || true )
pkill -f "vite" 2>/dev/null || true
( cd "$ROOT_DIR" && (npm run dev &) ) || true
echo -e "\033[1;32m[OK]\033[0m Vite reiniciado"

echo
echo -e "\033[1;32m[OK]\033[0m Listo. Recarga el navegador:"
echo "  - Deberías ver un **botón/enlace 'Energía'** en el Dashboard."
echo "  - Al hacer clic, te lleva a **#/energia** y el gate existente debe renderizar la vista de Energía."
echo "Si algo queda mal posicionado, dime en qué bloque (nav/tabs) lo necesitas y te genero otro .sh que lo inserte exactamente ahí."
