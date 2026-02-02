#!/bin/sh
# Playlist seguro: HOME -> SEDE -> HOME -> siguiente sede (con Play/Pause, intervalo, viewSec, orden, solo incidencias, loop)
# Idempotente: inserta solo si faltan imports/estados/controles/motor.
set -eu

APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP_JS="$APP_DIR/src/App.jsx"
CTRL_JS="$APP_DIR/src/components/AutoPlayControls.jsx"
AUTO_JS="$APP_DIR/src/components/AutoPlayer.jsx"
CSS="$APP_DIR/src/styles.css"

need() { [ -f "$1" ] || { echo "[ERR] Falta $1"; exit 1; }; }
need "$APP_DIR/package.json"
need "$APP_DIR/src/App.jsx"

ts=$(date +%Y%m%d%H%M%S)
mkdir -p "$APP_DIR/src/components"
[ -f "$APP_JS" ] && cp "$APP_JS" "$APP_JS.bak.$ts"
[ -f "$CTRL_JS" ] && cp "$CTRL_JS" "$CTRL_JS.bak.$ts" 2>/dev/null || true
[ -f "$AUTO_JS" ] && cp "$AUTO_JS" "$AUTO_JS.bak.$ts" 2>/dev/null || true
[ -f "$CSS" ] || touch "$CSS"

echo "== 1) Escribiendo AutoPlayControls.jsx (con viewSec) =="
cat > "$CTRL_JS" <<'JSX'
import React from "react";

export default function AutoPlayControls({
  running=false, onToggle=()=>{},
  intervalSec=10, setIntervalSec=()=>{},
  order="downFirst", setOrder=()=>{},
  onlyIncidents=false, setOnlyIncidents=()=>{},
  loop=true, setLoop=()=>{},
  viewSec=10, setViewSec=()=>{}
}) {
  return (
    <div className="autoplay-controls" style={{
      display:"flex", gap:8, alignItems:"center", flexWrap:"wrap",
      border:"1px solid #e5e7eb", padding:"8px 10px", borderRadius:8, background:"#fff"
    }}>
      <button
        type="button"
        className="k-btn"
        style={{borderColor: running ? "#dc2626" : "#16a34a", color: running ? "#dc2626" : "#16a34a"}}
        onClick={onToggle}
        title={running ? "Pausar rotación" : "Iniciar rotación"}
      >
        {running ? "⏸️ Pausar" : "▶️ Reproducir"}
      </button>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Intervalo (s)
        <input type="number" min="3" step="1" value={intervalSec}
          onChange={(e)=>setIntervalSec(Math.max(3, parseInt(e.target.value||"10",10)))}
          style={{width:64, padding:"4px 6px"}}/>
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Orden
        <select value={order} onChange={(e)=>setOrder(e.target.value)} style={{padding:"4px 6px"}}>
          <option value="downFirst">DOWN primero</option>
          <option value="alpha">Alfabético</option>
        </select>
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        <input type="checkbox" checked={onlyIncidents} onChange={(e)=>setOnlyIncidents(e.target.checked)}/>
        Solo incidencias
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        <input type="checkbox" checked={loop} onChange={(e)=>setLoop(e.target.checked)}/>
        Loop
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Ver (sede) s
        <input type="number" min="3" step="1" value={viewSec}
          onChange={(e)=>setViewSec(Math.max(3, parseInt(e.target.value||"10",10)))}
          style={{width:64, padding:"4px 6px"}}/>
      </label>

      <span style={{marginLeft:"auto", color:"#6b7280"}}>Playlist de instancias</span>
    </div>
  );
}
JSX

echo "== 2) Escribiendo AutoPlayer.jsx (HOME->SEDE->HOME) =="
cat > "$AUTO_JS" <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v2
 * - En HOME: tras intervalSec abre la próxima sede.
 * - En SEDE: tras viewSec vuelve a HOME; al volver, HOME abre la próxima sede.
 * - Orden: "downFirst" o "alpha"; filtro "onlyIncidents"; loop.
 */
export default function AutoPlayer({
  enabled=false,
  intervalSec=10,
  viewSec=10,
  order="downFirst",
  onlyIncidents=false,
  loop=true,
  filteredAll=[],
  route,
  openInstance
}) {
  const idxRef = useRef(0);
  const timerRef = useRef(null);

  const instanceStats = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const it = map.get(m.instance) || { up:0, down:0, total:0 };
      if (m.latest?.status === 1) it.up++; else if (m.latest?.status === 0) it.down++;
      it.total++;
      map.set(m.instance, it);
    }
    return map;
  }, [filteredAll]);

  const playlist = useMemo(() => {
    let arr = Array.from(instanceStats.keys());
    if (onlyIncidents) arr = arr.filter(n => (instanceStats.get(n)?.down || 0) > 0);
    if (order === "downFirst") {
      arr.sort((a,b)=> (instanceStats.get(b)?.down||0) - (instanceStats.get(a)?.down||0) || a.localeCompare(b));
    } else {
      arr.sort((a,b)=> a.localeCompare(b));
    }
    return arr;
  }, [instanceStats, onlyIncidents, order]);

  // Mantener índice válido al cambiar el tamaño de la lista
  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  useEffect(() => {
    // limpiar timer previo
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    if (route?.name === "home") {
      // Programar apertura de la próxima sede
      const goNext = () => {
        if (!playlist.length) return;
        if (idxRef.current >= playlist.length) {
          if (!loop) return;
          idxRef.current = 0;
        }
        const name = playlist[idxRef.current++];
        openInstance?.(name);
      };
      timerRef.current = setTimeout(goNext, Math.max(3, intervalSec) * 1000);
    } else if (route?.name === "sede") {
      // Permanecer en la sede viewSec y regresar a HOME para continuar
      const backHome = () => { window.location.hash = ""; };
      timerRef.current = setTimeout(backHome, Math.max(3, viewSec) * 1000);
    }

    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; } };
  }, [enabled, intervalSec, viewSec, route?.name, playlist.length, loop, openInstance]);

  return null;
}
JSX

echo "== 3) Parchando App.jsx: imports, estados, controles y motor =="

# 3.1 Imports: AutoPlayControls y AutoPlayer (si faltan)
if ! grep -q 'AutoPlayControls' "$APP_JS"; then
  # insertar tras import de SLAAlerts si existe; si no, tras el primer import
  if grep -q 'import SLAAlerts from "./components/SLAAlerts.jsx";' "$APP_JS"; then
    sed -i 's~import SLAAlerts from "./components/SLAAlerts.jsx";~import SLAAlerts from "./components/SLAAlerts.jsx";\
import AutoPlayControls from "./components/AutoPlayControls.jsx";\
import AutoPlayer from "./components/AutoPlayer.jsx";~' "$APP_JS"
  else
    # primera línea import
    first_imp=$(grep -n '^import ' "$APP_JS" | head -1 | cut -d: -f1 || true)
    if [ -n "${first_imp:-}" ]; then
      awk -v n="$first_imp" 'NR==n{print;print "import AutoPlayControls from \"./components/AutoPlayControls.jsx\";";print "import AutoPlayer from \"./components/AutoPlayer.jsx\";";next}1' "$APP_JS" > "$APP_JS.tmp" && mv "$APP_JS.tmp" "$APP_JS"
    else
      sed -i '1i import AutoPlayControls from "./components/AutoPlayControls.jsx";\nimport AutoPlayer from "./components/AutoPlayer.jsx";' "$APP_JS"
    fi
  fi
fi

# 3.2 Estados: si faltan, agregarlos justo después de la firma del componente
add_states='
  // === Playlist (v2) ===
  const [autoRun, setAutoRun] = useState(false);
  const [autoIntervalSec, setAutoIntervalSec] = useState(10);
  const [autoOrder, setAutoOrder] = useState("downFirst");
  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);
  const [autoLoop, setAutoLoop] = useState(true);
  const [autoViewSec, setAutoViewSec] = useState(10);
'
need_states=false
for k in autoRun autoIntervalSec autoOrder autoOnlyIncidents autoLoop autoViewSec; do
  grep -q "$k" "$APP_JS" || need_states=true
done

if $need_states; then
  awk -v block="$add_states" '
    BEGIN{done=0}
    {
      print
      if (!done && $0 ~ /^export default function App$$$$ \{/) { print block; done=1 }
    }' "$APP_JS" > "$APP_JS.tmp" && mv "$APP_JS.tmp" "$APP_JS"
fi

# 3.3 Controles: insertar debajo de <Filters .../> si no existen
if ! grep -q '<AutoPlayControls' "$APP_JS"; then
  awk '
    BEGIN{inserted=0}
    {
      print
      if (!inserted && $0 ~ /<Filters monitors=\{monitors\} value=\{filters\} onChange=\{setFilters\} \/>/) {
        print "        <AutoPlayControls"
        print "          running={autoRun}"
        print "          onToggle={()=>setAutoRun(v=>!v)}"
        print "          intervalSec={autoIntervalSec} setIntervalSec={setAutoIntervalSec}"
        print "          order={autoOrder} setOrder={setAutoOrder}"
        print "          onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}"
        print "          loop={autoLoop} setLoop={setAutoLoop}"
        print "          viewSec={autoViewSec} setViewSec={setAutoViewSec}"
        print "        />"
        inserted=1
      }
    }' "$APP_JS" > "$APP_JS.tmp" && mv "$APP_JS.tmp" "$APP_JS"
fi

# 3.4 Motor: insertar AutoPlayer (bajo el bloque .controls) si no existe
if ! grep -q '<AutoPlayer' "$APP_JS"; then
  # buscamos cierre de la .controls en el primer nivel: línea que contiene </div> y la palabra controls en el bloque
  awk '
    BEGIN{printed=0}
    {
      if (!printed && $0 ~ /<\/div>/ && prev ~ /className="controls"/) {
        print
        print "      {/* Motor de autoplay (no visible) */}"
        print "      <AutoPlayer"
        print "        enabled={autoRun}"
        print "        intervalSec={autoIntervalSec}"
        print "        viewSec={autoViewSec}"
        print "        order={autoOrder}"
        print "        onlyIncidents={autoOnlyIncidents}"
        print "        loop={autoLoop}"
        print "        filteredAll={filteredAll}"
        print "        route={route}"
        print "        openInstance={openInstance}"
        print "      />"
        printed=1
        next
      }
      print
      prev=$0
    }' "$APP_JS" > "$APP_JS.tmp" && mv "$APP_JS.tmp" "$APP_JS"
fi

echo "== 4) CSS mínimo para controles =="
grep -q "autoplay-controls" "$CSS" || cat >> "$CSS" <<'CSS'
/* Autoplay / Playlist */
.autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.autoplay-controls input, .autoplay-controls select { border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827; }
CSS

echo
echo "✅ Parche aplicado. Ahora compila y despliega:"
echo "   npm run build"
echo "   sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo
echo "Abrir en HOME (no dentro de una sede) y usar el módulo 'Playlist de instancias'."
