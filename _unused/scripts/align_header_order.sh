#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
CSS="$ROOT/src/styles.css"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$APP" ] && cp "$APP" "$APP.bak_$ts" || true
[ -f "$CSS" ] || touch "$CSS"
cp "$CSS" "$CSS.bak_$ts"

echo "== 1) Limpiar restos de inserciones previas en el header =="
# Quita comentarios HTML en JSX si quedaron
sed -i 's#</div><!-- end:header-tools -->#</div>{/* end:header-tools */}#g' "$APP" || true
# Quita cualquier bloque <div className="header-tools"...> previo
awk '
  BEGIN{skip=0}
  {
    if ($0 ~ /<div className="header-tools"/) { skip=1 }
    if (skip && $0 ~ /\{\/\* end:header-tools \*\/\}/) { skip=0; next }
    if (!skip) print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 2) Mover AlertsBanner para que quede DEBAJO de la barra =="
# Reemplaza la primera aparición de AlertsBanner por un marcador y lo reinsertaremos más abajo
if grep -q '<AlertsBanner' "$APP"; then
  sed -i '0,/<AlertsBanner/{s/<AlertsBanner[^>]*\/>/__ALERTS_PLACEHOLDER__/}' "$APP"
fi

echo "== 3) Insertar barra encabezado (Nombre+Home | Filtros+SoloDOWN | Playlist) =="
# Buscamos el contenedor donde está el h1 "Uptime Central" y el botón Home, y justo DESPUÉS insertamos la barra
awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && $0 ~ /<div style=\{\{display:"flex",alignItems:"center",gap:12,flexWrap:"wrap"\}\}>/) {
      # mantenemos el header (Uptime Central + Home) tal como está, y justo después insertamos la barra completa
      print "      {/* ===== Barra: Nombre+Home | Filtros+SoloDOWN | Playlist ===== */}";
      print "      <div className=\"header-bar\" style={{display:\"flex\",alignItems:\"center\",gap:10,flexWrap:\"wrap\",marginTop:6}}>";
      print "        {/* Bloque Nombre + Home (ya está arriba, aquí no repetimos) */}";
      print "        {/* Bloque Filtros (sede -> tipo -> buscar) + Solo DOWN */}";
      print "        <div className=\"filters-inline\" style={{display:\"flex\",gap:6,flexWrap:\"wrap\"}}>";
      print "          <Filters monitors={monitors} value={filters} onChange={setFilters} />";
      print "          <label style={{display:\"flex\",alignItems:\"center\",gap:6}}>";
      print "            <input";
      print "              type=\"checkbox\"";
      print "              checked={effectiveStatus === \"down\"}";
      print "              onChange={(e)=> setStatus(e.target.checked ? \"down\" : \"all\")} />";
      print "            Solo DOWN";
      print "          </label>";
      print "        </div>";
      print "";
      print "        {/* Playlist (a la derecha) */}";
      print "        <div style={{marginLeft:\"auto\"}}>";
      print "          <AutoPlayControls";
      print "            running={autoRun}";
      print "            onToggle={()=>setAutoRun(v=>!v)}";
      print "            sec={autoSec} setSec={setAutoSec}";
      print "            order={autoOrder} setOrder={setAutoOrder}";
      print "            onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}";
      print "            loop={autoLoop} setLoop={setAutoLoop}";
      print "          />";
      print "        </div>";
      print "      </div> {/* end header-bar */}";
      inserted=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 4) Reinsertar AlertsBanner DEBAJO de la barra =="
# Colocamos el marcador justo después de la barra si existe, o sino tras el header wrapper
if grep -q '__ALERTS_PLACEHOLDER__' "$APP"; then
  awk '
    BEGIN{placed=0}
    {
      print
      if (!placed && $0 ~ /<\/div> \{\/* end header-bar \*\/\}/) {
        print "      __ALERTS_PLACEHOLDER__";
        placed=1
      }
    }
  ' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
  # Restaurar el componente
  sed -i 's#__ALERTS_PLACEHOLDER__#<AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS} />#' "$APP"
fi

echo "== 5) Asegurar que NO queden AutoPlayControls/Filters duplicados en el bloque 'controls' =="
# Eliminar AutoPlayControls dentro de <div className="controls"> si quedara alguno
sed -i '/<AutoPlayControls/,+12 d' "$APP" || true
# Eliminar Filters dentro de controls si quedara alguno
sed -i '/<Filters .*onChange={setFilters}.*\/>/d' "$APP" || true

echo "== 6) CSS mínimo para que quede prolijo y responsive =="
cat >> "$CSS" <<'CSS'

/* ===== Header bar ordenada ===== */
.header-bar { gap: 10px; }
.filters-inline { gap: 6px; }
.filters-inline .filters { margin: 0; }
@media (max-width: 1100px) {
  .header-bar { flex-direction: column; align-items: stretch; }
  .header-bar > div[style*="margin-left:\\"auto\\""] { margin-left: 0 !important; }
}
CSS

echo "== 7) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && sudo systemctl reload nginx

echo "✓ Hecho: orden correcto (Nombre+Home | Filtros+SoloDOWN | Playlist) y alertas debajo."
