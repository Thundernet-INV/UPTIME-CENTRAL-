#!/bin/sh
# Arreglo del playlist v3:
# - HOME -> (300ms) -> abre primera SEDE
# - SEDE -> (viewSec) -> HOME -> siguiente
# - DebugChip visible con estado/playlist
set -eu

APP="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP"

mkdir -p src/components
ts=$(date +%Y%m%d%H%M%S)

# Backups
[ -f src/App.jsx ] && cp src/App.jsx src/App.jsx.bak.$ts
[ -f src/components/AutoPlayControls.jsx ] && cp src/components/AutoPlayControls.jsx src/components/AutoPlayControls.jsx.bak.$ts 2>/dev/null || true
[ -f src/components/AutoPlayer.jsx ] && cp src/components/AutoPlayer.jsx src/components/AutoPlayer.jsx.bak.$ts 2>/dev/null || true
[ -f src/styles.css ] || touch src/styles.css

###############################################################################
# 1) AutoPlayer v3 – dispara inicio rápido y expone debug
###############################################################################
cat > src/components/AutoPlayer.jsx <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v3
 * - En HOME: tras 300ms al activar (enabled) abre la primera sede; luego usa intervalSec
 * - En SEDE: tras viewSec vuelve a HOME; al volver, HOME programa la siguiente
 * - Orden: "downFirst" o "alpha"; filtro "onlyIncidents"; loop
 * - Expone window.__apDebug para diagnóstico rápido (DebugChip)
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

  // Mantener un "preview" del siguiente nombre
  const nextName = useMemo(() => {
    if (!playlist.length) return null;
    const i = idxRef.current % playlist.length;
    return playlist[i];
  }, [playlist.length, idxRef.current]); // idxRef.current no re-renderiza, pero sirve de orientación

  // Exponer debug global (para un chip visual o console)
  useEffect(() => {
    window.__apDebug = {
      enabled, route: route?.name, count: playlist.length,
      next: nextName, intervalSec, viewSec, onlyIncidents, order, loop
    };
    // console.debug('[AutoPlayer]', window.__apDebug);
  }, [enabled, route?.name, playlist.length, nextName, intervalSec, viewSec, onlyIncidents, order, loop]);

  // Mantener índice válido si cambia la lista
  useEffect(() => {
    if (idxRef.current >= playlist.length) idxRef.current = 0;
  }, [playlist.length]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const goNext = () => {
      if (!playlist.length) return;
      if (idxRef.current >= playlist.length) {
        if (!loop) return;
        idxRef.current = 0;
      }
      const name = playlist[idxRef.current++];
      openInstance?.(name);
    };

    const backHome = () => { window.location.hash = ""; };

    if (route?.name === "home") {
      // Si acabo de activar, dispara casi inmediato (300ms) la primera sede
      if (idxRef.current === 0) {
        timerRef.current = setTimeout(goNext, 300);
      } else {
        timerRef.current = setTimeout(goNext, Math.max(3, intervalSec) * 1000);
      }
    } else if (route?.name === "sede") {
      // Permanecer en sede viewSec y retroceder a HOME
      timerRef.current = setTimeout(backHome, Math.max(3, viewSec) * 1000);
    }
    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; } };
  }, [enabled, intervalSec, viewSec, route?.name, playlist.length, loop, openInstance]);

  return null;
}
JSX

###############################################################################
# 2) DebugChip – muestra enabled, ruta y tamaño del playlist
###############################################################################
cat > src/components/DebugChip.jsx <<'JSX'
import React, { useEffect, useState } from "react";

/** Lee window.__apDebug cada 1s y lo muestra */
export default function DebugChip() {
  const [snap, setSnap] = useState({ enabled:false, route:'?', count:0, next:null });
  useEffect(() => {
    const t = setInterval(() => {
      const d = window.__apDebug || {};
      setSnap({
        enabled: !!d.enabled,
        route: d.route || '?',
        count: typeof d.count === 'number' ? d.count : 0,
        next: d.next || null
      });
    }, 1000);
    return () => clearInterval(t);
  }, []);

  const style = {
    position:'fixed', bottom:10, right:10, zIndex:9999,
    background:'#111827', color:'#fff', padding:'6px 8px', borderRadius:8, fontSize:12, opacity:.85
  };
  return (
    <div style={style}>
      <b>Playlist</b> {snap.enabled ? 'ON' : 'OFF'} | ruta: {snap.route} | items: {snap.count} {snap.next ? | next: ${snap.next} : ''}
    </div>
  );
}
JSX

###############################################################################
# 3) Asegurar imports y estados en App.jsx
###############################################################################
# Imports
grep -q 'AutoPlayControls' src/App.jsx || sed -i 's~import SLAAlerts from "./components/SLAAlerts.jsx";~import SLAAlerts from "./components/SLAAlerts.jsx";\
import AutoPlayControls from "./components/AutoPlayControls.jsx";\
import AutoPlayer from "./components/AutoPlayer.jsx";\
import DebugChip from "./components/DebugChip.jsx";~' src/App.jsx

# Estados (incluye autoViewSec)
awk '
  BEGIN{need=0}
  /export default function App$$$$ \{/ {print; print "  // Playlist v3"; print "  const [autoRun, setAutoRun] = useState(false);"; print "  const [autoIntervalSec, setAutoIntervalSec] = useState(10);"; print "  const [autoOrder, setAutoOrder] = useState(\"downFirst\");"; print "  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);"; print "  const [autoLoop, setAutoLoop] = useState(true);"; print "  const [autoViewSec, setAutoViewSec] = useState(10);"; next }
  { print }
' src/App.jsx > src/App.jsx.tmp.$ts

# Si ya estaban, no duplicar (limpieza simple: eliminar líneas duplicadas consecutivas)
awk '!x[$0]++' src/App.jsx.tmp.$ts > src/App.jsx && rm -f src/App.jsx.tmp.$ts

###############################################################################
# 4) Insertar controles debajo de <Filters .../>
###############################################################################
if ! grep -q '<AutoPlayControls' src/App.jsx; then
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
    }' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx
fi

###############################################################################
# 5) Renderizar AutoPlayer y DebugChip justo debajo del bloque .controls
###############################################################################
if ! grep -q '<AutoPlayer' src/App.jsx; then
  awk '
    BEGIN{printed=0}
    {
      if (!printed && /<\/div>/ && prev ~ /className="controls"/) {
        print
        print "      {/* Motor de autoplay y chip de depuración */}"
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
        print "      <DebugChip />"
        printed=1; next
      }
      print
      prev=$0
    }' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx
fi

###############################################################################
# 6) CSS mínimo (opcional)
###############################################################################
grep -q "autoplay-controls" src/styles.css || cat >> src/styles.css <<'CSS'
/* Autoplay / Playlist */
.autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.autoplay-controls input, .autoplay-controls select { border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827; }
CSS

echo
echo "✅ fix_autoplay_v3 aplicado. Compila y despliega:"
echo "   npm run build"
echo "   sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo
echo "Abre HOME, pon Intervalo 3s y Play. Verás un chip 'Playlist ON | ruta: home | items: N'."
echo "Si items=0, revisa filtros o desmarca 'Solo incidencias'."
