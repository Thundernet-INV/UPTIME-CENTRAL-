#!/bin/sh
set -eu

APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP_DIR"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p src/components
[ -f src/App.jsx ] && cp src/App.jsx src/App.jsx.bak.$ts || true
[ -f src/components/AutoPlayer.jsx ] && cp src/components/AutoPlayer.jsx src/components/AutoPlayer.jsx.bak.$ts || true
[ -f src/components/DebugChip.jsx ] && cp src/components/DebugChip.jsx src/components/DebugChip.jsx.bak.$ts || true

echo "== Escribiendo App.jsx limpio (con playlist) =="
cat > src/App.jsx <<'JSX'
import { useEffect, useMemo, useState, useRef } from "react";
import Cards from "./components/Cards.jsx";
import Filters from "./components/Filters.jsx";
import ServiceGrid from "./components/ServiceGrid.jsx";
import MonitorsTable from "./components/MonitorsTable.jsx";
import InstanceDetail from "./components/InstanceDetail.jsx";
import SLAAlerts from "./components/SLAAlerts.jsx";
import AutoPlayControls from "./components/AutoPlayControls.jsx";
import AutoPlayer from "./components/AutoPlayer.jsx";
import DebugChip from "./components/DebugChip.jsx";
import AlertsBanner from "./components/AlertsBanner.jsx";
import { fetchAll, getBlocklist, saveBlocklist } from "./api.js";
import History from "./historyEngine.js";

const SLA_CONFIG = { uptimeTarget: 99.9, maxLatencyMs: 800 };
const ALERT_AUTOCLOSE_MS = 10000;

function getRoute() {
  const parts = (window.location.hash || "").slice(1).split("/").filter(Boolean);
  if (parts[0] === "sede" && parts[1]) return { name: "sede", instance: decodeURIComponent(parts[1]) };
  return { name: "home" };
}
const keyFor = (i, n = "") => JSON.stringify({ i, n });
const fromKey = (k) => { try { return JSON.parse(k); } catch { return { i: "", n: "" }; } };

export default function App() {
  // Playlist
  const [autoRun, setAutoRun] = useState(false);
  const [autoIntervalSec, setAutoIntervalSec] = useState(10);
  const [autoOrder, setAutoOrder] = useState("downFirst");
  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);
  const [autoLoop, setAutoLoop] = useState(true);
  const [autoViewSec, setAutoViewSec] = useState(10);

  // Estado general
  const [monitors, setMonitors]   = useState([]);
  const [instances, setInstances] = useState([]);
  const [filters, setFilters]     = useState({ instance:"", type:"", q:"", status:"all" });
  const [hidden, setHidden]       = useState(new Set());
  const [view, setView]           = useState("grid");
  const [route, setRoute]         = useState(getRoute());
  const [alerts, setAlerts]       = useState([]);

  useEffect(() => {
    const onHash = () => setRoute(getRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  // Init
  const didInit = useRef(false);
  useEffect(() => {
    if (didInit.current) return;
    didInit.current = true;
    (async () => {
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances);
        setMonitors(monitors);
        History.addSnapshot(monitors);
        try {
          const bl = await getBlocklist();
          setHidden(new Set((bl?.monitors ?? []).map(k => keyFor(k.instance, k.name))));
        } catch {}
      } catch (e) { console.error(e); }
    })();
  }, []);

  // Polling + alertas DOWN (1->0)
  const lastStatus = useRef(new Map());
  useEffect(() => {
    const m = new Map();
    for (const x of monitors) m.set(keyFor(x.instance, x.info?.monitor_name), x.latest?.status ?? 1);
    lastStatus.current = m;
  }, []); // inicial

  useEffect(() => {
    let stop = false;
    async function loop() {
      if (stop) return;
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances);
        setMonitors(monitors);
        History.addSnapshot(monitors);

        const prev = lastStatus.current, next = new Map(), newDowns=[];
        for (const m of monitors) {
          const k = keyFor(m.instance, m.info?.monitor_name), st = m.latest?.status ?? 1, was = prev.get(k);
          if (was === 1 && st === 0) newDowns.push({ id:k, instance:m.instance, name:m.info?.monitor_name, ts:Date.now() });
          next.set(k, st);
        }
        lastStatus.current = next;

        if (newDowns.length) setAlerts(a => {
          const ids = new Set(a.map(x=>x.id)); const add = newDowns.filter(d=>!ids.has(d.id)); return [...a, ...add];
        });
        setAlerts(a => a.filter(x => next.get(x.id) === 0));
      } catch {}
      setTimeout(loop, 5000);
    }
    loop(); return () => { stop = true; };
  }, []);

  // Filtro base (sin estado UP/DOWN)
  const baseMonitors = useMemo(() => monitors.filter(m => {
    if (filters.instance && m.instance !== filters.instance) return false;
    if (filters.type && m.info?.monitor_type !== filters.type) return false;
    if (filters.q) {
      const hay = ${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""}.toLowerCase();
      if (!hay.includes(filters.q.toLowerCase())) return false;
    }
    return true;
  }), [monitors, filters.instance, filters.type, filters.q]);

  // Métricas header
  const headerCounts = useMemo(() => {
    const up = baseMonitors.filter(m => m.latest?.status === 1).length;
    const down = baseMonitors.filter(m => m.latest?.status === 0).length;
    const total = baseMonitors.length;
    const rts = baseMonitors.map(m => m.latest?.responseTime).filter(v => v != null);
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length) : null;
    return { up, down, total, avgMs };
  }, [baseMonitors]);

  // Estado efectivo (UP/DOWN)
  const effectiveStatus = filters.status;
  function setStatus(s){ setFilters(p => ({ ...p, status:s })); }

  // Lista final (con estado)
  const filteredAll = useMemo(() => baseMonitors.filter(m => {
    if (effectiveStatus === "up"   && m.latest?.status !== 1) return false;
    if (effectiveStatus === "down" && m.latest?.status !== 0) return false;
    return true;
  }), [baseMonitors, effectiveStatus]);

  // Visibles (sin hidden)
  const visible = filteredAll.filter(m => !hidden.has(keyFor(m.instance, m.info?.monitor_name)));

  // Hidden / blocklist
  async function persistHidden(next) {
    const arr = [...next].map(k => { const {i,n}=fromKey(k); return {instance:i,name:n}; });
    try { await saveBlocklist({ monitors: arr }); } catch {}
    setHidden(next);
  }
  function onHide(i,n){ const s=new Set(hidden); s.add(keyFor(i,n)); persistHidden(s); }
  function onUnhide(i,n){ const s=new Set(hidden); s.delete(keyFor(i,n)); persistHidden(s); }
  function onHideAll(instance){ const s=new Set(hidden); filteredAll.filter(m=>m.instance===instance).forEach(m=>s.add(keyFor(m.instance, m.info?.monitor_name))); persistHidden(s); }
  async function onUnhideAll(instance){
    const bl = await getBlocklist(); const nextArr = (bl?.monitors ?? []).filter(k => k.instance !== instance);
    try { await saveBlocklist({ monitors: nextArr }); } catch {}
    setHidden(new Set(nextArr.map(k=>keyFor(k.instance,k.name))));
  }

  function openInstance(name){ window.location.hash = "/sede/" + encodeURIComponent(name); }

  // Render
  return (
    <div className="container" data-route={route.name}>
      <h1>Uptime Central</h1>

      <AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS}/>
      <Cards counts={headerCounts} status={effectiveStatus} onSetStatus={setStatus} />

      <div className="controls">
        {/* Controles de autoplay (playlist) */}
        <AutoPlayControls
          running={autoRun}
          onToggle={()=>setAutoRun(v=>!v)}
          intervalSec={autoIntervalSec} setIntervalSec={setAutoIntervalSec}
          order={autoOrder} setOrder={setAutoOrder}
          onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}
          loop={autoLoop} setLoop={setAutoLoop}
          viewSec={autoViewSec} setViewSec={setAutoViewSec}
        />

        <Filters monitors={monitors} value={filters} onChange={setFilters} />

        {/* AUTOPLAY ENGINE */}
        <AutoPlayer
          enabled={autoRun}
          intervalSec={autoIntervalSec}
          viewSec={autoViewSec}
          order={autoOrder}
          onlyIncidents={autoOnlyIncidents}
          loop={autoLoop}
          filteredAll={filteredAll}
          route={route}
          openInstance={openInstance}
        />

        {/* DEBUG CHIP */}
        <DebugChip />

        {route.name!=="sede" && (
          <div className="global-toggle" style={{ display:"flex", gap:8 }}>
            <button type="button" className={btn tab ${view==="grid"?"active":""}} onClick={()=>setView("grid")}>Grid</button>
            <button type="button" className={btn tab ${view==="table"?"active":""}} onClick={()=>setView("table")}>Tabla</button>
          </div>
        )}
      </div>

      <SLAAlerts monitors={visible} config={SLA_CONFIG} onOpenInstance={openInstance} />

      {route.name==="sede" ? (
        <div className="container">
          <InstanceDetail instanceName={route.instance} monitorsAll={filteredAll} hiddenSet={hidden}
            onHide={onHide} onUnhide={onUnhide} onHideAll={onHideAll} onUnhideAll={onUnhideAll}/>
        </div>
      ) : view==="grid" ? (
        <ServiceGrid monitorsAll={filteredAll} hiddenSet={hidden} onHideAll={onHideAll} onUnhideAll={onUnhideAll} onOpen={openInstance} />
      ) : (
        <MonitorsTable monitors={visible} hiddenSet={hidden} onHide={onHide} onUnhide={onUnhide} slaConfig={SLA_CONFIG}/>
      )}
    </div>
  );
}
JSX

echo "== Escribiendo AutoPlayer.jsx (v3) =="
cat > src/components/AutoPlayer.jsx <<'JSX'
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

  useEffect(() => {
    window.__apDebug = {
      enabled, route: route?.name, count: playlist.length,
      next: playlist.length ? playlist[idxRef.current % playlist.length] : null,
      intervalSec, viewSec, onlyIncidents, order, loop
    };
  }, [enabled, route?.name, playlist.length, intervalSec, viewSec, onlyIncidents, order, loop]);

  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; }
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
    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; } };
  }, [enabled, intervalSec, viewSec, route?.name, playlist.length, loop, openInstance]);

  return null;
}
JSX

echo "== Escribiendo DebugChip.jsx =="
cat > src/components/DebugChip.jsx <<'JSX'
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

echo "== Verificando que no existan restos de la línea rota =="
grep -n 'const hay = \\${m.info' -n src/App.jsx && { echo '[ERR] Aún hay linea rota'; exit 1; } || true
grep -n 'const hay = ' src/App.jsx

echo "== Listo. Ahora compila: npm run build =="
