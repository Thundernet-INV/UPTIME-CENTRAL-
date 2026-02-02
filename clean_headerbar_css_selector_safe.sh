#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"

echo "== Backup de src/ =="
ts=$(date +%Y%m%d_%H%M%S)
cp -r "$ROOT/src" "$ROOT/src.bak_css_$ts"

echo "== 1) Asegurar util .push-right en styles.css =="
grep -q '\.push-right' "$ROOT/src/styles.css" || cat >> "$ROOT/src/styles.css" <<'CSS'

/* Utilidad: empuja a la derecha en el header (evita selectores por [style*="..."]) */
.push-right { margin-left: auto !important; }
CSS

echo "== 2) Usar .push-right en App.jsx para el contenedor del playlist =="
sed -i 's|<div style={{marginLeft:"auto"}}>|<div className="push-right">|g' "$ROOT/src/App.jsx"

echo "== 3) Eliminar reglas con [style*=\"margin-left\"] en TODOS los CSS =="
# Elimina bloques completos (desde la línea del selector hasta la llave de cierre más próxima)
find "$ROOT/src" -type f -name '*.css' | while read -r f; do
  # 3.1 borra bloques multi-línea
  sed -i '/$$style\*\s*=\s*["'\''][^"'\'']*margin-left[^"'\'']*["'\'']$$/,/}/d' "$f"
  # 3.2 borra líneas sueltas con el selector (por si venía en una sola línea)
  sed -i '/$$style\*\s*=\s*["'\''][^"'\'']*margin-left[^"'\'']*["'\'']$$/d' "$f"
done

echo "== 4) Verificación rápida (debería no encontrar coincidencias) =="
grep -RIn '\[style\*\s*=\s*.*margin-left' "$ROOT/src" || echo "OK: no quedan selectores por [style*=margin-left]"

echo "== 5) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Limpieza hecha: no más warnings de CSS por [style*=margin-left]."
