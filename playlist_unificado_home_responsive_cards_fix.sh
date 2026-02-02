#!/bin/sh
set -eu

APPROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$APPROOT/src/App.jsx"
CTRL="$APPROOT/src/components/AutoPlayControls.jsx"
AUTOP="$APPROOT/src/components/AutoPlayer.jsx"
CSS="$APPROOT/src/styles.css"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p "$APPROOT/src/components"
[ -f "$APP" ]   && cp "$APP"   "$APP.bak_$ts"   || true
[ -f "$CTRL" ]  && cp "$CTRL"  "$CTRL.bak_$ts"  || true
[ -f "$AUTOP" ] && cp "$AUTOP" "$AUTOP.bak_$ts" || true
[ -f "$CSS" ]   || touch "$CSS"
cp "$CSS" "$CSS.bak_$ts"

echo "== 1) AutoPlayControls: una sola casilla 'Tiempo (s)' =="
sudo tee "$CTRL" >/dev/null <<'JSX'
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

echo "== 2) AutoPlayer v6: usa 'sec' y rota sede→sede sin volver a Home (respeta >5s) =="
sudo tee "$AUTOP" >/dev/null <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v6
 * - Un solo tiempo: sec (segundos).
 * - HOME: primer salto en ~300 ms.
 * - SEDE: tras sec segundos → siguiente sede (loop), sin pasar por HOME.
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

  useEffect(() => {
    if (typeof window !== "undefined") {
      window.__apDebug = {
        enabled, route: route?.name, count: playlist.length,
        next: playlist.length ? playlist[idxRef.current % playlist.length] : null,
        sec, onlyIncidents, order, loop
      };
    }
  }, [enabled, route?.name, playlist.length, sec, onlyIncidents, order, loop]);

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
      if (typeof openInstance === "function") openInstance(nextName); else goByHash(nextName);
    };

    if (route?.name === "home") {
      timerRef.current = setTimeout(() => gotoNextFrom(null), 300);
    } else if (route?.name === "sede") {
      timerRef.current = setTimeout(() => gotoNextFrom(route.instance), SEC * 1000);
    }
    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; } };
  }, [enabled, sec, route?.name, route?.instance, playlist.length, loop, openInstance]);

  return null;
}
JSX

echo "== 3) App.jsx completo (con botón Home y estados unificados) =="
sudo tee "$APP" >/dev/null <<'JSX'
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

/** Ruteo por hash: #/sede/<instancia> | vacío -> home */
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

  // Hash routing
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

  // Visibles
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

        {/* Selector Grid/Tabla (Tabla queda deshabilitada por CSS/JS externo si lo deseas) */}
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

echo "== 4) CSS responsive + anti-overflow (títulos y badges) =="
sudo tee -a "$CSS" >/dev/null <<'CSS'

/* ====== Copilot UI patch: Responsive + Cards ordenadas ====== */
.container { max-width: 1600px; margin: 0 auto; padding: 12px; }
.home-btn { border:1px solid #e5e7eb; border-radius:8px; padding:6px 10px; background:#fff; color:#111827; cursor:pointer; }
.home-btn:hover { background:#f3f4f6; }

.cards-grid, .services-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:14px; }

.card, .monitor-card, .service-card { display:flex; flex-direction:column; gap:10px; background:#fff; border:1px solid #e5e7eb; border-radius:12px; padding:12px; min-width:0; box-sizing:border-box; }

.card > *:first-child, .monitor-card > *:first-child, .service-card > *:first-child,
.card-head, .monitor-card__head, .service-card__head { position:relative; display:flex; align-items:center; gap:10px; min-width:0; }

.card img, .monitor-card img, .service-card img, .card-logo, .monitor-card__logo, .service-card__logo { flex:0 0 auto; width:22px; height:22px; border-radius:6px; object-fit:contain; }

.card > *:first-child > :nth-child(2),
.monitor-card > *:first-child > :nth-child(2),
.service-card > *:first-child > :nth-child(2),
.card-head__texts, .monitor-card__texts, .service-card__texts { display:flex; flex-direction:column; min-width:0; overflow:hidden; padding-right:84px; }

.card > *:first-child > :nth-child(2) > :first-child,
.monitor-card > *:first-child > :nth-child(2) > :first-child,
.service-card > *:first-child > :nth-child(2) > :first-child,
.card-title, .monitor-card__title, .service-card__title {
  color:#111827; font-weight:600; min-width:0; overflow:hidden;
  display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical;
  text-overflow:ellipsis; white-space:normal; line-height:1.2; font-size:15px;
  overflow-wrap:anywhere; word-break:break-word; max-height: calc(1.2em * 2);
}
.card > *:first-child > :nth-child(2) > :nth-child(2),
.monitor-card > *:first-child > :nth-child(2) > :nth-child(2),
.service-card > *:first-child > :nth-child(2) > :nth-child(2),
.card-subtitle, .monitor-card__subtitle, .service-card__subtitle { color:#6b7280; font-size:12.5px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0; }

.card > *:first-child .badge, .monitor-card > *:first-child .badge, .service-card > *:first-child .badge,
.status-badge, .monitor-card__badge, .service-card__badge {
  position:absolute; top:8px; right:10px; max-width:72px; padding:2px 8px; border-radius:9999px;
  font-size:11px; font-weight:700; line-height:1.6; text-align:center; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
}
.badge--up  { background:#e8f8ef !important; color:#0e9f6e !important; }
.badge--down{ background:#fde8e8 !important; color:#d93025 !important; }

.card-foot, .monitor-card__foot, .service-card__foot { display:flex; align-items:center; gap:10px; min-width:0; }
.sparkline, .monitor-card__sparkline, .service-card__sparkline { min-width:0; width:100%; height:44px; }

.autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.autoplay-controls input, .autoplay-controls select { border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827; }

@media (min-width:1800px) {
  .container { max-width: 1920px; }
  .cards-grid, .services-grid { grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:16px; }
}
@media (max-width:480px) {
  .cards-grid, .services-grid { grid-template-columns:1fr; }
  .card > *:first-child .badge, .status-badge, .monitor-card__badge, .service-card__badge { top:6px; right:8px; max-width:64px; font-size:10.5px; }
  .card > *:first-child > :nth-child(2), .card-head__texts, .monitor-card__texts, .service-card__texts { padding-right:72px; }
}
/* ====== /Copilot UI patch ====== */
CSS

echo "== 5) Compilando =="
cd "$APPROOT"
npm run build

echo "== 6) Desplegando =="
rsync -av --delete "$APPROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Hecho: un solo tiempo, botón Home, responsive y cards sin desbordes."
