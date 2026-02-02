#!/bin/sh
set -eu
APP="/home/thunder/kuma-dashboard-clean/kuma-ui/src/App.jsx"

# Backup
cp "$APP" "$APP.bak_$(date +%Y%m%d_%H%M%S)"

# 1) Eliminar cualquier rastro de forceGridAlways
sed -i /forceGridAlways/d "$APP"

# 2) Asegurar que el botón "Tabla" queda inactivo (sin onClick y disabled)
sed -i 's/onClick={() => setView("table")}//g' "$APP"
grep -q '>Tabla</button>' "$APP" && sed -i '0,/>Tabla<\/button>/{s// disabled>Tabla<\/button>/}' "$APP"

# 3) Reemplazar un efecto viejo que usaba forceGridAlways por uno sin variables
sed -i 's/useEffect(() => { if (forceGridAlways && view !== "grid") setView("grid"); }, $$forceGridAlways, view$$);/useEffect(() => { if (view !== "grid") setView("grid"); }, [view]);/g' "$APP"

# 4) Si no existe el efecto que fuerza Grid, insertarlo antes del return principal (idempotente)
grep -q 'useEffect(() => { if (view !== "grid") setView("grid"); }, $$view$$);' "$APP" || \
  sed -i '/^  return (/i\  // Forzar Grid en tiempo de ejecución\n  useEffect(() => { if (view !== "grid") setView("grid"); }, [view]);\n' "$APP"

echo "OK - parche aplicado"
