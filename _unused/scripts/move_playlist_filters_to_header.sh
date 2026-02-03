#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
CSS="$ROOT/src/styles.css"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$APP" ] && cp "$APP" "$APP.bak_$ts" || true
[ -f "$CSS" ] || touch "$CSS"
cp "$CSS" "$CSS.bak_$ts"

echo "== 1) Limpiar posibles restos de 'header-tools' anteriores =="
# Quita cualquier bloque anterior con clase header-tools (si lo hubiera)
awk '
  BEGIN{skip=0}
  {
    if ($0 ~ /<div className="header-tools"/) { skip=1 }
    if (skip && $0 ~ /<\/div>\s*<!--\s*end:header-tools\s*-->/) { skip=0; next }
    if (!skip) print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 2) Insertar barra header-tools al lado de Home =="
# Insertamos después del contenedor del encabezado (donde está Uptime Central + botón Home)
# Buscamos el wrapper que contiene <h1>Uptime Central</h1> y el botón Home
awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && $0 ~ /<div style=\{\{display:"flex",alignItems:"center",gap:12,flexWrap:"wrap"\}\}>/) {
      print "        <div className=\"header-tools\" style={{display:\"flex\",gap:8,alignItems:\"center\",flexWrap:\"wrap\",marginLeft:\"auto\"}}>";
      print "          {/* Playlist (compacto) */}";
      print "          <AutoPlayControls";
      print "            running={autoRun}";
      print "            onToggle={()=>setAutoRun(v=>!v)}";
      print "            sec={autoSec} setSec={setAutoSec}";
      print "            order={autoOrder} setOrder={setAutoOrder}";
      print "            onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}";
      print "            loop={autoLoop} setLoop={setAutoLoop}";
      print "          />";
      print "          {/* Filtros */}";
      print "          <div className=\"header-filters\" style={{minWidth:260}}>";
      print "            <Filters monitors={monitors} value={filters} onChange={setFilters} />";
      print "          </div>";
      print "        </div><!-- end:header-tools -->";
      inserted=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 3) Quitar render original de AutoPlayControls y Filters del bloque 'controls' =="
# Elimina AutoPlayControls donde aparece dentro del <div className="controls">
sed -i '/<AutoPlayControls/,+7 d' "$APP" || true
# Elimina Filters donde aparece dentro de controls (si persistiera)
sed -i '/<Filters .*onChange={setFilters}.*\/>/d' "$APP" || true

echo "== 4) Asegurar que AutoPlayer quede en controls (no lo removemos) =="
# No tocamos AutoPlayer; sólo garantizamos que no se elimine por accidente (no se hace nada si no aplica)

echo "== 5) CSS: estilo básico para la barra del header =="
cat >> "$CSS" <<'CSS'

/* ===== Header tools (playlist + filtros junto a Home) ===== */
.header-tools { gap: 8px; }
.header-tools .autoplay-controls {
  border: 1px solid #e5e7eb; border-radius: 8px; padding: 6px 8px; background: #fff;
}
.header-tools .autoplay-controls label { font-size: 12px; color: #374151; }
.header-tools .autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.header-tools .autoplay-controls input, 
.header-tools .autoplay-controls select {
  border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827;
}
.header-filters .filters { margin: 0; } /* por si tu Filters usa clase interna */
@media (max-width: 980px) {
  .header-tools { width: 100%; }
  .header-filters { flex: 1 1 auto; min-width: 200px; }
}
CSS

echo "== 6) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: Playlist + Filtros movidos al header, junto al botón Home."
