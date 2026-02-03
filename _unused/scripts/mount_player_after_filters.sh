#!/bin/bash
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
AUTO="$ROOT/src/components/AutoPlayer.jsx"
DBG="$ROOT/src/components/DebugChip.jsx"
CSS="$ROOT/src/styles.css"

need(){ [ -f "$1" ] || { echo "[ERR] Falta $1"; exit 1; }; }

echo "== Validando proyecto =="
need "$ROOT/package.json"; need "$APP"; mkdir -p "$ROOT/src/components"; [ -f "$CSS" ] || touch "$CSS"

TS=$(date +%Y%m%d_%H%M%S)
cp "$APP" "$APP.bak.$TS"

echo "== Escribiendo AutoPlayer.jsx (v3 con fallback) =="
cat > "$AUTO" <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v3
 * - HOME: dispara primera sede a ~300ms al activar; luego usa intervalSec.
 * - SEDE: espera viewSec y vuelve a HOME.
 * - window.__apDebug para diagnóstico.
 * - Si no llega openInstance, navega por hash.
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

    const openByHash = (name) => { window.location.hash = "/sede/" + encodeURIComponent(name); };
    const goNext = () => {
      if (!playlist.length) return;
      if (idxRef.current >= playlist.length) {
        if (!loop) return;
        idxRef.current = 0;
      }
      const name = playlist[idxRef.current++];
      if (typeof openInstance === "function") openInstance(name); else openByHash(name);
    };
    const backHome = () => { window.location.hash = ""; };

    if (route?.name === "home") {
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
  const style = {
    position:'fixed', bottom:10, right:10, zIndex:9999,
    background:'#111827', color:'#fff', padding:'6px 8px',
    borderRadius:8, fontSize:12, opacity:.85
  };
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

echo "== Insertando render de AutoPlayer + DebugChip justo después de <Filters .../> =="
if ! grep -q '<AutoPlayer' "$APP"; then
  # Inserción portable: agregar líneas *después* de Filters con el comando 'a\'
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
echo "✔ Ahora despliega:"
echo "sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "sudo nginx -t && sudo systemctl reload nginx"
