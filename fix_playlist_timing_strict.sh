#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
CTRL="$ROOT/src/components/AutoPlayControls.jsx"
AUTOP="$ROOT/src/components/AutoPlayer.jsx"
CSS="$ROOT/src/styles.css"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p "$ROOT/src/components"

# Backups
[ -f "$APP" ]   && cp "$APP"   "$APP.bak_$ts"   || true
[ -f "$CTRL" ]  && cp "$CTRL"  "$CTRL.bak_$ts"  || true
[ -f "$AUTOP" ] && cp "$AUTOP" "$AUTOP.bak_$ts" || true
[ -f "$CSS" ]   || touch "$CSS"

echo "== 1) AutoPlayControls: 1 sola casilla 'Tiempo (s)' =="
cat > "$CTRL" <<'JSX'
import React from "react";

export default function AutoPlayControls({
  running=false, onToggle=()=>{},
  sec=10, setSec=()=>{},
  order="downFirst", setOrder=()=>{},
  onlyIncidents=false, setOnlyIncidents=()=>{},
  loop=true, setLoop=()=>{}
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
        Tiempo (s)
        <input
          type="number" min="1" step="1" value={sec}
          onChange={(e)=> {
            const v = parseInt(e.target.value || "10", 10);
            setSec(Number.isFinite(v) ? Math.max(1, v) : 10);
          }}
          style={{width:72, padding:"4px 6px"}}
        />
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

      <span style={{marginLeft:"auto", color:"#6b7280"}}>Playlist de instancias</span>
    </div>
  );
}
JSX

echo "== 2) AutoPlayer v6 instrumentado (respeta 'sec' y loguea cada programación) =="
cat > "$AUTOP" <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v6 (instrumentado)
 * - Un solo tiempo: sec (s).
 * - HOME: primer salto ~300ms.
 * - SEDE: tras sec s -> siguiente sede (loop), sin pasar por HOME.
 * - Logs a consola para ver exactamente qué se programa.
 */
export default function AutoPlayer({
  enabled=false,
  sec=10,
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

  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  // Debug global (útil para leer desde consola)
  useEffect(() => {
    if (typeof window !== "undefined") {
      window.__apDebug = {
        enabled, route: route?.name, instance: route?.instance || null,
        count: playlist.length,
        next: playlist.length ? playlist[idxRef.current % playlist.length] : null,
        sec, onlyIncidents, order, loop
      };
      // console.log("[AP] state", window.__apDebug);
    }
  }, [enabled, route?.name, route?.instance, playlist.length, sec, onlyIncidents, order, loop]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const SEC = Math.max(1, Number(sec) || 10);
    const goByHash = (name) => { window.location.hash = "/sede/" + encodeURIComponent(name); };

    const gotoNextFrom = (currentName) => {
      if (!playlist.length) return;
      let i = currentName ? playlist.indexOf(currentName) : -1;
      let nextIdx = (i >= 0 ? i + 1 : idxRef.current);
      if (nextIdx >= playlist.length) {
        if (!loop) return;
        nextIdx = 0;
      }
      idxRef.current = nextIdx;
      const nextName = playlist[nextIdx];
      console.log("[AP] gotoNext:", { from: currentName || "(home)", to: nextName, sec: SEC });
      if (typeof openInstance === "function") openInstance(nextName); else goByHash(nextName);
    };

    if (route?.name === "home") {
      console.log("[AP] schedule@home:", 300, "ms", { sec: SEC, items: playlist.length });
      timerRef.current = setTimeout(() => gotoNextFrom(null), 300);
    } else if (route?.name === "sede") {
      console.log("[AP] schedule@sede:", SEC * 1000, "ms", { sec: SEC, current: route?.instance });
      timerRef.current = setTimeout(() => gotoNextFrom(route.instance), SEC * 1000);
    }

    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; } };
  }, [enabled, sec, route?.name, route?.instance, playlist.length, loop, openInstance]);

  return null;
}
JSX

echo "== 3) App.jsx limpio (sin fallbacks viejos, con botón Home y 'sec' unificado) =="
cat > "$APP" <<'JSX'
import { useEffect, useMemo, useState, useRef } from "react";
import Cards from "./components/Cards.jsx";
import Filters from "./components/Filters.jsx";
import ServiceGrid from "./components/ServiceGrid.jsx";
import MonitorsTable from "./components/MonitorsTable.jsx";
import InstanceDetail from "./components/InstanceDetail.jsx";
import SLAAlerts from "./components/SLAAlerts.jsx";
import AutoPlayControls from "./components/AutoPlayControls.jsx";
import AutoPlayer from "./components/AutoPlayer.jsx";
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
const keyFor  = (i, n="") => JSON.stringify({ i, n });
const fromKey = (k) => { try { return JSON.parse(k); } catch { return { i:"", n:"" }; } };

export default function App() {
  // ===== Playlist =====
  const [autoRun, setAutoRun]           = useState(false);
  const [autoSec, setAutoSec]           = useState(10);
  const [autoOrder, setAutoOrder]       = useState("downFirst");
  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);
  const [autoLoop, setAutoLoop]         = useState(true);

  // ===== Estado base =====
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

  // Polling 5s + alertas DOWN (1->0)
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
      const hay = ((m.info?.monitor_name ?? "") + " " + (m.info?.monitor_url ?? "")).toLowerCase();
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

  const visible = filteredAll.filter(m => !hidden.has(keyFor(m.instance, m.info?.monitor_name)));

  // Hidden / blocklist
  async function persistHidden(next) {
    const arr = [...next].map(k => { const {i,n}=fromKey(k); return {instance:i,name:n}; });
    try { await saveBlocklist({ monitors: arr }); } catch {}
    setHidden(next);
  }
  function onHide(i,n){ const s=new Set(hidden); s.add(keyFor(i,n)); persistHidden(s); }
  function onUnhide(i,n){ const s=new Set(hidden); s.delete(keyFor(i,n)); persistHidden(s); }
  function onHideAll(instance){
    const s = new Set(hidden);
    filteredAll.filter(m=>m.instance===instance).forEach(m=>s.add(keyFor(m.instance, m.info?.monitor_name)));
    persistHidden(s);
  }
  async function onUnhideAll(instance){
    const bl = await getBlocklist(); const nextArr = (bl?.monitors ?? []).filter(k => k.instance !== instance);
    try { await saveBlocklist({ monitors: nextArr }); } catch {}
    setHidden(new Set(nextArr.map(k=>keyFor(k.instance,k.name))));
  }

  function openInstance(name){ window.location.hash = "/sede/" + encodeURIComponent(name); }

  // ===== Render =====
  return (
    <div className="container" data-route={route.name}>

      {/* Título + botón Home */}
      <div style={{display:"flex",alignItems:"center",gap:12,flexWrap:"wrap"}}>
        <h1 style={{margin:0}}>Uptime Central</h1>
        <button className="home-btn" type="button" onClick={()=>{window.location.hash="";}} title="Ir al inicio">Home</button>
      </div>

      <AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS}/>
      <Cards counts={headerCounts} status={effectiveStatus} onSetStatus={setStatus} />

      <div className="controls">
        {/* Controles del playlist */}
        <AutoPlayControls
          running={autoRun}
          onToggle={()=>setAutoRun(v=>!v)}
          sec={autoSec} setSec={setAutoSec}
          order={autoOrder} setOrder={setAutoOrder}
          onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}
          loop={autoLoop} setLoop={setAutoLoop}
        />

        <Filters monitors={monitors} value={filters} onChange={setFilters} />

        {/* AUTOPLAY ENGINE */}
        <AutoPlayer
          enabled={autoRun}
          sec={autoSec}
          order={autoOrder}
          onlyIncidents={autoOnlyIncidents}
          loop={autoLoop}
          filteredAll={filteredAll}
          route={route}
          openInstance={openInstance}
        />

        {route.name !== "sede" && (
          <div className="global-toggle" style={{ display:"flex", gap:8 }}>
            <button
              type="button"
              className={"btn tab " + (view==="grid" ? "active" : "")}
              onClick={()=>setView("grid")}
            >
              Grid
            </button>
            <button
              type="button"
              className={"btn tab " + (view==="table" ? "active" : "")}
              onClick={()=>setView("table")}
              disabled
            >
              Tabla
            </button>
          </div>
        )}
      </div>

      <SLAAlerts monitors={visible} config={SLA_CONFIG} onOpenInstance={openInstance} />

      {route.name==="sede" ? (
        <div className="container">
          <InstanceDetail
            instanceName={route.instance}
            monitorsAll={filteredAll}
            hiddenSet={hidden}
            onHide={onHide} onUnhide={onUnhide}
            onHideAll={onHideAll} onUnhideAll={onUnhideAll}
          />
        </div>
      ) : view==="grid" ? (
        <ServiceGrid
          monitorsAll={filteredAll} hiddenSet={hidden}
          onHideAll={onHideAll} onUnhideAll={onUnhideAll}
          onOpen={openInstance}
        />
      ) : (
        <MonitorsTable
          monitors={visible} hiddenSet={hidden}
          onHide={onHide} onUnhide={onUnhide}
          slaConfig={SLA_CONFIG}
        />
      )}
    </div>
  );
}
JSX

echo "== 4) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: temporizador unificado y respetado; logs en consola para validar."
