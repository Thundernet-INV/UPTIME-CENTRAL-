#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"

echo "== Backup de CSS =="
ts=$(date +%Y%m%d_%H%M%S)
find "$ROOT/src" -type f -name '*.css' -print0 | xargs -0 -I{} cp "{}" "{}.bak_$ts"

echo "== 1) Asegurar util .push-right y su uso en App.jsx =="
# Añade la clase si no existiera
grep -q '\.push-right' "$ROOT/src/styles.css" || cat >> "$ROOT/src/styles.css" <<'CSS'

/* Utilidad: empuja a la derecha en el header */
.push-right { margin-left: auto !important; }
CSS

# Sustituye cualquier style inline por la clase
sed -i 's|<div style={{marginLeft:"auto"}}>|<div className="push-right">|g' "$ROOT/src/App.jsx"

echo "== 2) Eliminar en TODOS los CSS cualquier regla con [style*=\"margin-left\"] (bloque completo) =="
# Patrón robusto: elimina DESDE la línea que contiene el selector con [style*=margin-left ...]
# HASTA la llave de cierre del bloque correspondiente.
clean_file() {
  f="$1"
  awk '
    BEGIN{skip=0; depth=0}
    {
      line=$0
      # Si detectamos el atributo [style*=...margin-left...], empezamos a saltar hasta cerrar el bloque
      if (skip==0 && line ~ /$$style\*\s*=\s*["'\'']?[^"'\'']*margin-left[^"'\'']*["'\'']?$$/) {
        skip=1
        # contamos llaves de ese bloque por si hay anidadas en reglas @media
        depth += gsub(/\{/, "{", line)
        depth -= gsub(/\}/, "}", line)
        next
      }
      if (skip==1) {
        depth += gsub(/\{/, "{", line)
        depth -= gsub(/\}/, "}", line)
        if (depth <= 0) { skip=0 }  # bloque cerrado
        next
      }
      print
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

export -f clean_file
find "$ROOT/src" -type f -name '*.css' -print0 | xargs -0 -I{} bash -lc 'clean_file "$@"' _ {}

echo "== 3) Rebuild & deploy =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Limpieza hecha: selector por [style*=margin-left] eliminado; warning no volverá."
