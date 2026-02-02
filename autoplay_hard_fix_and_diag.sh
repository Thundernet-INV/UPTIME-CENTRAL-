#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
CTRL="$ROOT/src/components/AutoPlayControls.jsx"
AUTO="$ROOT/src/components/AutoPlayer.jsx"
DBG="$ROOT/src/components/DebugChip.jsx"
CSS="$ROOT/src/styles.css"

need(){ [ -f "$1" ] || { echo "[ERR] Falta $1"; exit 1; }; }

echo "== Validando =="
need "$ROOT/package.json"; need "$APP"; mkdir -p "$ROOT/src/components"; [ -f "$CSS" ] || touch "$CSS"

TS=$(date +%Y%m%d%H%M%S)
cp "$APP" "$APP.bak.$TS"

echo "== Escribiendo/actualizando componentes =="
# AutoPlayer v3 (expone __apDebug y realiza HOME->SEDE->HOME)
cat > "$AUTO" <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

export default function AutoPlayer({
  enabled=false, intervalSec=10, viewSec=10,
  order="downFirst", onlyIncidents=false, loop=true,
  filteredAll=[], route, openInstance
}) {
  const idxRef = useRef(0);
  const timerRef = useRef(null);

  const instanceStats = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const it = map.get(m.instance) || { up:0, down:0, total:0 };
      if (m.latest?.status === 1) it.up++; else if (m.latest?.status === 0) it.down++;
      it.total++; map.set(m.instance, it);
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

  const nextName = useMemo(() => {
    if (!playlist.length) return null;
    const i = idxRef.current % playlist.length;
    return playlist[i];
  }, [playlist.length]);

  useEffect(() => {
    window.__apDebug = {
      enabled, route: route?.name, count: playlist.length,
      next: nextName, intervalSec, viewSec, onlyIncidents, order, loop
    };
  }, [enabled, route?.name, playlist.length, nextName, intervalSec, viewSec, onlyIncidents, order, loop]);

  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const goNext = () => {
      if (!playlist.length) return;
      if (idxRef.current >= playlist.length) {
        if (!loop) return;
        idxRef.current = 0;
      }
      openInstance?.(playlist[idxRef.current++]);
    };
    const backHome = () => { window.location.hash = ""; };

    if (route?.name === "home") {
      // Primer salto rápido si es la primera vez; luego intervalSec
      const delay = (idxRef.current === 0 ? 300 : Math.max(3, intervalSec) * 1000);
      timerRef.current = setTimeout(goNext, delay);
    } else if (route?.name === "sede") {
      timerRef.current = setTimeout(backHome, Math.max(3, viewSec) * 1000);
    }
    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; } };
  }, [enabled, intervalSec, viewSec, route?.name, playlist.length, loop, openInstance]);

  return null;
}
JSX

# Controles con viewSec
cat > "$CTRL" <<'JSX'
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
      <button type="button" className="k-btn"
        style={{borderColor: running ? "#dc2626" : "#16a34a", color: running ? "#dc2626" : "#16a34a"}}
        onClick={onToggle}>
        {running ? "⏸️ Pausar" : "▶️ Reproducir"}
      </button>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Intervalo (s)
        <input type="number" min="3" step="1" value={intervalSec}
          onChange={(e)=>setIntervalSec(Math.max(3, parseInt(e.target.value||"10",10)))} style={{width:64, padding:"4px 6px"}}/>
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
          onChange={(e)=>setViewSec(Math.max(3, parseInt(e.target.value||"10",10)))} style={{width:64, padding:"4px 6px"}}/>
      </label>

      <span style={{marginLeft:"auto", color:"#6b7280"}}>Playlist de instancias</span>
    </div>
  );
}
JSX

# Chip de debug
cat > "$DBG" <<'JSX'
import React, { useEffect, useState } from "react";
export default function DebugChip(){
  const [snap, setSnap] = useState({ enabled:false, route:'?', count:0, next:null });
  useEffect(() => {
    const t = setInterval(() => {
      const d = window.__apDebug || {};
      setSnap({ enabled: !!d.enabled, route: d.route || '?', count: d.count || 0, next: d.next || null });
    }, 1000);
    return () => clearInterval(t);
  }, []);
  const style = { position:'fixed', bottom:10, right:10, zIndex:9999, background:'#111827', color:'#fff',
                  padding:'6px 8px', borderRadius:8, fontSize:12, opacity:.85 };
  return (
    <div style={style}>
      <b>Playlist</b> {snap.enabled ? 'ON' : 'OFF'} | ruta: {snap.route} | items: {snap.count} {snap.next ? | next: ${snap.next} : ''}
    </div>
  );
}
JSX

echo "== Inyectando imports en App.jsx (si faltan) =="
if ! grep -q 'AutoPlayControls' "$APP"; then
  first_imp=$(grep -n '^import ' "$APP" | head -1 | cut -d: -f1 || true)
  if [ -n "$first_imp" ]; then
    awk -v n="$first_imp" 'NR==n{print;print "import AutoPlayControls from \"./components/AutoPlayControls.jsx\";";print "import AutoPlayer from \"./components/AutoPlayer.jsx\";";print "import DebugChip from \"./components/DebugChip.jsx\";";next}1' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
  else
    sed -i '1i import AutoPlayControls from "./components/AutoPlayControls.jsx";\nimport AutoPlayer from "./components/AutoPlayer.jsx";\nimport DebugChip from "./components/DebugChip.jsx";' "$APP"
  fi
fi

echo "== Inyectando estados del playlist (si faltan) =="
need_states=false
for k in autoRun autoIntervalSec autoOrder autoOnlyIncidents autoLoop autoViewSec; do
  grep -q "$k" "$APP" || need_states=true
done
if $need_states; then
  awk '
    BEGIN{done=0}
    {
      print
      if (!done && /^export default function App$$$$ \{$/) {
        print "  // Playlist v3"
        print "  const [autoRun, setAutoRun] = useState(false);"
        print "  const [autoIntervalSec, setAutoIntervalSec] = useState(10);"
        print "  const [autoOrder, setAutoOrder] = useState(\"downFirst\");"
        print "  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);"
        print "  const [autoLoop, setAutoLoop] = useState(true);"
        print "  const [autoViewSec, setAutoViewSec] = useState(10);"
        done=1
      }
    }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
fi

echo "== Insertando controles debajo de Filters o al inicio de .controls =="
if ! grep -q '<AutoPlayControls' "$APP"; then
  if grep -q '<Filters monitors=\{monitors\} value=\{filters\} onChange=\{setFilters\} \/>'; then
    sed -i 's~<Filters monitors={monitors} value={filters} onChange={setFilters} /><Filters monitors={monitors} value={filters} onChange={setFilters} />\n        <AutoPlayControls running={autoRun} onToggle={()=>setAutoRun(v=>!v)} intervalSec={autoIntervalSec} setIntervalSec={setAutoIntervalSec} order={autoOrder} setOrder={setAutoOrder} onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents} loop={autoLoop} setLoop={setAutoLoop} viewSec={autoViewSec} setViewSec={setAutoViewSec} />' "$APP" || true
  fi
  # Fallback: insertar al comienzo del bloque .controls
  awk '
    BEGIN{done=0}
    {
      if (!done && /className="controls"/) {
        print
        print "        <AutoPlayControls"
        print "          running={autoRun}"
        print "          onToggle={()=>setAutoRun(v=>!v)}"
        print "          intervalSec={autoIntervalSec} setIntervalSec={setAutoIntervalSec}"
        print "          order={autoOrder} setOrder={setAutoOrder}"
        print "          onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}"
        print "          loop={autoLoop} setLoop={setAutoLoop}"
        print "          viewSec={autoViewSec} setViewSec={setAutoViewSec}"
        print "        />"
        done=1; next
      }
      print
    }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
fi

echo "== Insertando AutoPlayer y DebugChip dentro del bloque .controls =="
if ! grep -q '<AutoPlayer' "$APP"; then
  awk '
    BEGIN{ins=0}
    {
      if (!ins && /<\/div>/ && prev ~ /className="controls"/) {
        print
        print "      {/* Autoplay + Debug */}"
        print "      <AutoPlayer enabled={autoRun} intervalSec={autoIntervalSec} viewSec={autoViewSec} order={autoOrder} onlyIncidents={autoOnlyIncidents} loop={autoLoop} filteredAll={filteredAll} route={route} openInstance={openInstance} />"
        print "      <DebugChip />"
        ins=1; next
      }
      print
      prev=$0
    }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
fi

grep -q "autoplay-controls" "$CSS" || cat >> "$CSS" <<'CSS'
/* Autoplay / Playlist */
.autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.autoplay-controls input, .autoplay-controls select { border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827; }
CSS

echo "== RESUMEN =="
echo "- Imports presentes?"; grep -n 'AutoPlayControls\|AutoPlayer\|DebugChip' "$APP" || true
echo "- Estados presentes?"; grep -n 'autoRun\|autoIntervalSec\|autoOrder\|autoOnlyIncidents\|autoLoop\|autoViewSec' "$APP" || true
echo "- Controles presentes?"; grep -n '<AutoPlayControls' "$APP" || true
echo "- Motor y chip presentes?"; grep -n '<AutoPlayer\|<DebugChip' "$APP" || true

echo "== Compilando =="
cd "$ROOT"
npm run build

echo "== Despliegue sugerido =="
echo "sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "sudo nginx -t && sudo systemctl reload nginx"
