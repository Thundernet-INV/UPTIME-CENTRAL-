#!/bin/sh
set -eu
APP="/home/thunder/kuma-dashboard-clean/kuma-ui/src/App.jsx"

cp "$APP" "$APP.bak_fixheader_$(date +%Y%m%d_%H%M%S)"

# 1) Normaliza cualquier comentario HTML dejado antes en JSX
sed -i "s#</div><!-- end:header-tools -->#</div>{/* end:header-tools */}#g" "$APP"

# 2) Sustituye de forma segura SOLO el bloque del header por una versión correcta y balanceada.
#    Sustituimos desde la línea que abre el header (div con h1 Uptime Central) hasta justo antes de AlertsBanner.
awk '
  BEGIN{
    in=0
  }
  {
    # Detecta inicio del bloque con el h1 y Home
    if ($0 ~ /<div style=\{\{display:"flex",alignItems:"center",gap:12,flexWrap:"wrap"\}\}>/ && in==0) {
      in=1
      print $0
      print "  <h1 style={{margin:0}}>Uptime Central</h1>"
      print "  <button className=\"home-btn\" type=\"button\" onClick={()=>{window.location.hash=\"\";}} title=\"Ir al inicio\">Home</button>"
      print "</div>"
      print ""
      print "{/* ===== Barra: Nombre+Home (arriba) | Filtros+Solo DOWN | Playlist (abajo) ===== */}"
      print "<div className=\"header-bar\" style={{display:\"flex\",alignItems:\"center\",gap:10,flexWrap:\"wrap\",marginTop:6}}>"
      print "  {/* Filtros (Sede -> Tipo -> Buscar) + Solo DOWN */}"
      print "  <div className=\"filters-inline\" style={{display:\"flex\",gap:6,flexWrap:\"wrap\"}}>"
      print "    <Filters monitors={monitors} value={filters} onChange={setFilters} />"
      print "    <label style={{display:\"flex\",alignItems:\"center\",gap:6}}>"
      print "      <input"
      print "        type=\"checkbox\""
      print "        checked={effectiveStatus === \"down\"}"
      print "        onChange={(e)=> setStatus(e.target.checked ? \"down\" : \"all\")}"
      print "      />"
      print "      Solo DOWN"
      print "    </label>"
      print "  </div>"
      print ""
      print "  {/* Playlist a la derecha */}"
      print "  <div style={{marginLeft:\"auto\"}}>"
      print "    <AutoPlayControls"
      print "      running={autoRun}"
      print "      onToggle={()=>setAutoRun(v=>!v)}"
      print "      sec={autoSec} setSec={setAutoSec}"
      print "      order={autoOrder} setOrder={setAutoOrder}"
      print "      onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}"
      print "      loop={autoLoop} setLoop={setAutoLoop}"
      print "    />"
      print "  </div>"
      print "</div>"
      print ""
      next
    }
    # Cortamos la primera AlertsBanner que encontremos y la reinsertamos luego, para asegurar posición
    if ($0 ~ /<AlertsBanner[^>]*\/>/ && in==1) {
      print "<AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS} />"
      in=2
      next
    }
    # Si ya colocamos la barra y el AlertsBanner, seguimos imprimiendo normal
    if (in==2) { print; next }
    # Si estamos dentro del rango de sustitución (después del header y antes del AlertsBanner), omitimos
    if (in==1) { next }
    # Fuera del rango, imprimimos normal
    print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3) Quita posibles duplicados de AutoPlayControls / Filters que hayan quedado en el bloque "controls"
sed -i "/<AutoPlayControls/,+15 d" "$APP"
sed -i "/<Filters .*onChange={setFilters}.*\/>/d" "$APP"

echo "Header bar reescrita correctamente. Compilando…"
cd /home/thunder/kuma-dashboard-clean/kuma-ui
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "OK: Header arreglado y desplegado."
