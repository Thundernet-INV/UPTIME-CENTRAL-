#!/bin/bash
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
AUTO="$ROOT/src/components/AutoPlayer.jsx"
DBG="$ROOT/src/components/DebugChip.jsx"
CSS="$ROOT/src/styles.css"

need(){ [ -f "$1" ] || { echo "[ERR] Falta $1"; exit 1; }; }

echo "== Validando =="
need "$ROOT/package.json"; need "$APP"; mkdir -p "$ROOT/src/components"; [ -f "$CSS" ] || touch "$CSS"
TS=$(date +%Y%m%d_%H%M%S)
cp "$APP" "$APP.bak.$TS"

echo "== Reescribiendo AutoPlayer.jsx (exposición + logs) =="
cat > "$AUTO" <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v3 (forzado)
 * - HOME: abre la primera sede en ~300ms si enabled; luego usa intervalSec.
 * - SEDE: espera viewSec y vuelve a HOME.
 * - Siempre expone window.__apDebug; loguea montaje en consola.
 */
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

  // Exponer estado de depuración SIEMPRE que el componente se renderiza
  useEffect(() => {
    window.__apDebug = {
      enabled, route: route?.name, count: playlist.length,
      next: playlist.length ? playlist[idxRef.current % playlist.length] : null,
      intervalSec, viewSec, onlyIncidents, order, loop
    };
  }, [enabled, route?.name, playlist.length, intervalSec, viewSec, onlyIncidents, order, loop]);

  // Log de montaje (para confirmar que realmente se monta en runtime)
  useEffect(() => {
    console.log("[AutoPlayer] mounted", { enabled, route: route?.name });
  }, []);

  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const goByHash = (name) => { window.location.hash = "/sede/" + encodeURIComponent(name); };
    const goNext = () => {
      if (!playlist.length) return;
      if (idxRef.current >= playlist.length) {
        if (!loop) return;
        idxRef.current = 0;
      }
      const name = playlist[idxRef.current++];
      if (typeof openInstance === "function") openInstance(name); else goByHash(name);
    };
    const backHome = () => { window.location.hash = ""; };

    if (route?.name === "home") {
      const delay = (idxRef.current === 0 ? 300 : Math.max(3, intervalSec) * 1000);
      timerRef.current = setTimeout(goNext, delay);
    } else if (route?.name === "sede") {
      timerRef.current = setTimeout(backHome, Math.max(3, viewSec) * 1000);
    }
    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; } };
  }, [enabled, intervalSec, viewSec, route?.name, playlist.length, loop, openInstance]);

  return null;
}
JSX

echo "== Escribiendo DebugChip.jsx =="
cat > "$DBG" <<'JSX'
import React, { useEffect, useState } from "react";
export default function DebugChip(){
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
  const style = { position:'fixed', bottom:10, right:10, zIndex:9999, background:'#111827', color:'#fff',
                  padding:'6px 8px', borderRadius:8, fontSize:12, opacity:.85 };
  return (
    <div style={style}>
      <b>Playlist</b> {snap.enabled ? 'ON' : 'OFF'} | ruta: {snap.route} | items: {snap.count} {snap.next ? | next: ${snap.next} : ''}
    </div>
  );
}
JSX

echo "== Asegurando imports en App.jsx =="
grep -q 'from "./components/AutoPlayer.jsx"' "$APP" || \
  sed -i 's~from "./components/AutoPlayControls.jsx";~from "./components/AutoPlayControls.jsx";\
import AutoPlayer from "./components/AutoPlayer.jsx";\
import DebugChip from "./components/DebugChip.jsx";~' "$APP"

echo "== Inyectando un useEffect global en App.jsx que expone window.__apDebug (backup si AutoPlayer no montara) =="
# Solo lo inyectamos si no existe referencia a __apDebug en App.jsx
if ! grep -q '__apDebug' "$APP"; then
  awk '
    BEGIN{done=0}
    {
      print
      if (!done && /^export default function App$$$$ \{/){
        done=1;
        print "  // Exposición de debug global (backup, se actualiza con la ruta actual)"
        print "  useEffect(() => {"
        print "    window._apDebug = window._apDebug || {}; "
        print "    window.__apDebug.route = getRoute().name; "
        print "    window.__apDebug.enabled = false; "
        print "  }, [route.name]);"
      }
    }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
fi

echo "== Insertando render de AutoPlayer + DebugChip inmediatamente después de <Filters .../> (si faltara) =="
if ! grep -q '<AutoPlayer' "$APP"; then
  sed -i '/<Filters monitors={monitors} value={filters} onChange={setFilters} \/>/a \
        {/* AUTOPLAY ENGINE (forzado) */}\
        \n        <AutoPlayer\
        \n          enabled={autoRun}\
        \n          intervalSec={autoIntervalSec}\
        \n          viewSec={autoViewSec}\
        \n          order={autoOrder}\
        \n          onlyIncidents={autoOnlyIncidents}\
        \n          loop={autoLoop}\
        \n          filteredAll={filteredAll}\
        \n          route={route}\
        \n          openInstance={openInstance}\
        \n        />\
        \n        <DebugChip />' "$APP"
fi

echo "== Compilando =="
cd "$ROOT"
npm run build

echo
echo "✔ Listo. Ahora despliega y abre con bust de caché:"
echo "  sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "  sudo nginx -t && sudo systemctl reload nginx"
echo "  # En el navegador: http://10.10.31.31:8081/?v=$(date +%s)  (Ctrl+F5)"
