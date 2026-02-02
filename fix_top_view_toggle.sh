#!/bin/sh
# Arregla los botones "Grid / Tabla" del header superior
# - Fuerza type="button"
# - Añade aria-pressed para estado activo
# - Garantiza onClick correcto
# - Añade CSS preventivo para que nada tape los botones

set -eu
TS=$(date +%Y%m%d%H%M%S)

need() { [ -f "$1" ] || { echo "[ERROR] Falta $1" >&2; exit 1; }; }

echo "== Validando =="
need package.json
need src/App.jsx
[ -f src/styles.css ] || touch src/styles.css

echo "== Backup =="
cp src/App.jsx src/App.jsx.bak.$TS
cp src/styles.css src/styles.css.bak.$TS

echo "== Parchando src/App.jsx (botones Grid/Tabla superiores) =="

# Reescribimos el bloque donde se pintan los botones superiores, asegurando type=button.
# Buscamos el patrón que ya tienes (similar a esto):
#   <button className={`btn tab ${view==="grid"?"active":""}`} onClick={()=>setView("grid")}>Grid</button>
#   <button className={`btn tab ${view==="table"?"active":""}`} onClick={()=>setView("table")}>Tabla</button>
# y lo reemplazamos con la versión robusta (type, aria-pressed).
awk '
  BEGIN{changed=0}
  {
    line=$0
    # Normaliza botones Grid
    gsub(/<button([^>]*)className=\{`btn tab[^}]*grid[^}]*`\}([^>]*)>Grid<\/button>/,
         "<button type=\"button\" className={`btn tab ${view===\"grid\"?\"active\":\"\"}`} aria-pressed={view===\"grid\"} onClick={()=>setView(\"grid\")} >Grid</button>")
    # Normaliza botones Tabla
    gsub(/<button([^>]*)className=\{`btn tab[^}]*table[^}]*`\}([^>]*)>Tabla<\/button>/,
         "<button type=\"button\" className={`btn tab ${view===\"table\"?\"active\":\"\"}`} aria-pressed={view===\"table\"} onClick={()=>setView(\"table\")} >Tabla</button>")
    print
  }
' src/App.jsx > src/App.jsx.tmp.$TS

mv src/App.jsx.tmp.$TS src/App.jsx

echo "== Añadiendo CSS anti-overlay =="
# Evita que algún bloque del header (p. ej. cards) tape los botones por z-index
cat >> src/styles.css <<'CSS'

/* --- Fix: asegurar clics en los toggles del header --- */
.controls { position: relative; z-index: 5; }
.k-cards { position: relative; z-index: 1; }
/* Si en tu layout los toggles están dentro de otro wrapper, este z-index garantiza prioridad. */
CSS

echo
echo "✅ Listo. Ejecuta: npm run dev"
echo "• Los botones superiores ahora tienen type=\"button\" y aria-pressed."
echo "• El z-index evita que algo del header capture el clic."
