#!/usr/bin/env bash
set -e

echo "[UI] Añadiendo estilos globales (CSS)…"
cat > src/styles.css <<'CSS'
:root{
  --bg:#f7f8fa; --card:#ffffff; --muted:#6b7280; --text:#111827;
  --ok:#16a34a; --warn:#f59e0b; --down:#dc2626; --info:#2563eb; --violet:#7c3aed;
  --border:#e5e7eb; --shadow:0 1px 8px rgba(0,0,0,.08);
}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Ubuntu,"Helvetica Neue",Arial,"Noto Sans",sans-serif;}
h1{font-size:28px;margin:16px 0 10px 0}
h2{font-size:20px;margin:0}
.container{max-width:1200px;margin:0 auto;padding:24px}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:12px}
.kpi{background:var(--card);border-radius:12px;box-shadow:var(--shadow);padding:14px;border-left:6px solid var(--info)}
.kpi .label{font-size:12px;color:var(--muted)}
.kpi.ok{border-left-color:var(--ok)}
.kpi.down{border-left-color:var(--down)}
.kpi.info{border-left-color:var(--info)}
.kpi.violet{border-left-color:var(--violet)}

.controls{display:flex;align-items:center;justify-content:space-between;margin:10px 0 16px 0;gap:12px;flex-wrap:wrap}
.sel, .btn, .input{border:1px solid var(--border);border-radius:8px;background:#fff;padding:8px 10px}
.btn{cursor:pointer}
.btn.primary{border-color:var(--info);color:var(--info)}
.btn.danger{border-color:var(--down);color:var(--down)}
.btn.dark{background:#111827;color:#fff;border-color:#111827}
.btn.tab{background:#fff}
.btn.tab.active{background:#111827;color:#fff}

.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px}
.card{background:#fff;border:1px solid var(--border);border-radius:12px;box-shadow:var(--shadow);padding:14px}
.click{cursor:pointer}

.badge{display:inline-block;padding:2px 8px;border-radius:999px;color:#fff;font-size:12px}
.badge.up{background:var(--ok)} .badge.down{background:var(--down)} .muted{color:var(--muted);font-size:12px}

.table{width:100%;border-collapse:collapse;background:#fff;border:1px solid var(--border);box-shadow:var(--shadow)}
.table th{background:#fafafa;border-bottom:1px solid var(--border);padding:10px;text-align:left}
.table td{border-bottom:1px solid var(--border);padding:8px}
.align-right{text-align:right}

.spark{width:100%;height:36px}
CSS

echo "[UI] Asegurando main.jsx importe el CSS…"
cat > src/main.jsx <<'JSX'
import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./styles.css";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
JSX

echo "[UI] Sparkline robusto…"
cat > src/components/Sparkline.jsx <<'JSX'
export function Sparkline({ data = [], w = 220, h = 40, color = "#2563eb" }) {
  const ys = (data || []).map(p => typeof p === "number" ? p : (p?.responseTime ?? 0)).filter(v => Number.isFinite(v));
  if (!ys.length) return <svg className="spark" width={w} height={h} />;
  const min = Math.min(...ys), max = Math.max(...ys);
  const dx = w / Math.max(ys.length - 1, 1);
  const y = v => (max === min) ? h/2 : h - ((v - min) / (max - min)) * (h - 4) - 2;
  const pts = ys.map((v,i) => `${i*dx},${y(v)}`).join(" ");
  return <svg className="spark" width={w} height={h}><polyline fill="none" stroke={color} strokeWidth="2" points={pts} /></svg>;
}
JSX

echo "[UI] Cards (KPIs) con colores…"
cat > src/components/Cards.jsx <<'JSX'
export default function Cards({ summary = {} }) {
  const k = (cls,label,val)=>(<div className={`kpi ${cls}`}><div className="label">{label}</div><div style={{fontSize:22,fontWeight:600}}>{val ?? 0}</div></div>);
  return (
    <div className="kpis">
      {k("ok","UP",summary.up)}
      {k("down","DOWN",summary.down)}
      {k("info","Total",summary.total)}
      {k("violet","Prom (ms)",summary.avgResponseTimeMs ?? "—")}
    </div>
  );
}
JSX

echo "[UI] Filters con estilos…"
cat > src/components/Filters.jsx <<'JSX'
export default function Filters({ monitors = [], value, onChange }) {
  const instances = [...new Set(monitors.map(m=>m.instance))].sort();
  const types = [...new Set(monitors.map(m=>m.info?.monitor_type).filter(Boolean))].sort();
  const set = (k,v)=>onChange({ ...value, [k]: v });
  return (
    <div className="controls">
      <div style={{display:"flex",gap:10,flexWrap:"wrap"}}>
        <select className="sel" value={value.instance} onChange={e=>set("instance",e.target.value)}>
          <option value="">Todas las sedes</option>
          {instances.map(i=><option key={i} value={i}>{i}</option>)}
        </select>
        <select className="sel" value={value.type} onChange={e=>set("type",e.target.value)}>
          <option value="">Todos los tipos</option>
          {types.map(t=><option key={t} value={t}>{t}</option>)}
        </select>
        <input className="input" style={{width:240}} placeholder="Buscar…" value={value.q} onChange={e=>set("q",e.target.value)} />
        <label className="muted">
          <input type="checkbox" checked={value.onlyDown} onChange={e=>set("onlyDown",e.target.checked)} /> Solo DOWN
        </label>
      </div>
    </div>
  );
}
JSX

echo "[UI] ServiceCard con color y botones…"
cat > src/components/ServiceCard.jsx <<'JSX'
import { Sparkline } from "./Sparkline.jsx";
export default function ServiceCard({ sede, data, onHideAll, onUnhideAll, onOpen }) {
  const downs = (data.monitors||[]).filter(m=>m.latest?.status===0).length;
  const ratio = data.total ? (downs/data.total) : 0;
  const color = ratio>=0.3? "#dc2626" : ratio>=0.1? "#f59e0b" : "#16a34a";
  return (
    <div className="card click" onClick={()=>onOpen(sede)}>
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:6}}>
        <h3 style={{margin:0}}>{sede}</h3>
        <span className={`badge ${downs>0?"down":"up"}`}>{downs>0? "Incidencias" : "OK"}</span>
      </div>
      <Sparkline data={data.trend||[]} color={color} />
      <div style={{display:"flex",gap:12,marginTop:8,fontSize:14}}>
        <div>UP: <b>{data.up}</b></div>
        <div>DOWN: <b style={{color:"#dc2626"}}>{data.down}</b></div>
        <div>Total: <b>{data.total}</b></div>
        <div>Prom: <b>{data.avg ?? "—"} ms</b></div>
      </div>
      <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:10}}>
        <button className="btn danger" onClick={(e)=>{e.stopPropagation();onHideAll(sede)}}>Ocultar todos</button>
        <button className="btn primary" onClick={(e)=>{e.stopPropagation();onUnhideAll(sede)}}>Mostrar todos</button>
      </div>
    </div>
  );
}
JSX

echo "[UI] ServiceGrid con guardas (no se buguea)…"
cat > src/components/ServiceGrid.jsx <<'JSX'
import ServiceCard from "./ServiceCard.jsx";
export default function ServiceGrid({ monitorsAll = [], hiddenSet, onHideAll, onUnhideAll, onOpen }) {
  const by = (monitorsAll||[]).reduce((a,m)=>{ (a[m.instance]=a[m.instance]||[]).push(m); return a; },{});
  const make = (inst,arr)=>{
    const visible = arr.filter(m=>!hiddenSet.has(`${m.instance}|${m.info?.monitor_name}`));
    const up = visible.filter(m=>m.latest?.status===1).length;
    const down = visible.filter(m=>m.latest?.status===0).length;
    const total = visible.length;
    const rts = visible.map(m=>m.latest?.responseTime).filter(v=>v!=null);
    const avg = rts.length? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length):null;
    const len = Math.min(...visible.map(m=>(m.points||[]).length).filter(Boolean));
    const trend = Number.isFinite(len) ? Array.from({length:Math.min(len,50)},(_,i)=>{
      const vals = visible.map(m=>m.points[m.points.length-len+i]?.responseTime).filter(v=>v!=null);
      return vals.length? vals.reduce((a,b)=>a+b,0)/vals.length : 0;
    }) : [];
    return { sede:inst, data:{ up,down,total,avg, trend, monitors:arr } };
  };
  const cards = Object.entries(by).map(([inst,arr])=>make(inst,arr));
  if (!cards.length) return <div className="muted">No hay datos para la cuadrícula (ver filtros o sedes).</div>;
  return <div className="grid">{cards.map(c=> <ServiceCard key={c.sede} {...c} onHideAll={onHideAll} onUnhideAll={onUnhideAll} onOpen={onOpen}/>)}</div>;
}
JSX

echo "[UI] MonitorCard…"
cat > src/components/MonitorCard.jsx <<'JSX'
import { Sparkline } from "./Sparkline.jsx";
export default function MonitorCard({ m, hiddenSet, onHide, onUnhide }) {
  const hidden = hiddenSet.has(`${m.instance}|${m.info?.monitor_name}`);
  const up = m.latest?.status===1;
  return (
    <div className="card" style={{opacity:hidden?.valueOf()?0.5:1}}>
      <div style={{display:"flex",justifyContent:"space-between",alignItems:"baseline",gap:8}}>
        <h4 style={{margin:"2px 0"}}>{m.info?.monitor_name}</h4>
        <span className={`badge ${up? "up":"down"}`}>{up?"UP":"DOWN"}</span>
      </div>
      <div className="muted">{m.info?.monitor_url || m.info?.monitor_hostname || "-"}</div>
      <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",margin:"6px 0 8px 0"}}>
        <div>Latencia: <b>{m.latest?.responseTime ?? "—"} ms</b></div>
      </div>
      <Sparkline data={m.points||[]} color={up? "#10b981" : "#ef4444"} />
      <div style={{display:"flex",gap:8,justifyContent:"flex-end",marginTop:10}}>
        {!hidden
          ? <button className="btn danger" onClick={()=>onHide(m.instance,m.info?.monitor_name)}>Ocultar</button>
          : <button className="btn primary" onClick={()=>onUnhide(m.instance,m.info?.monitor_name)}>Mostrar</button>}
      </div>
    </div>
  );
}
JSX

echo "[UI] InstanceDetail…"
cat > src/components/InstanceDetail.jsx <<'JSX'
import { useMemo, useState } from "react";
import MonitorCard from "./MonitorCard.jsx";
import { Sparkline } from "./Sparkline.jsx";

export default function InstanceDetail({ instanceName, monitorsAll = [], hiddenSet, onHide, onUnhide, onHideAll, onUnhideAll }) {
  const [q,setQ] = useState(""); const [type,setType] = useState(""); const [showHidden,setShowHidden]=useState(false);
  const all = useMemo(()=> (monitorsAll||[]).filter(m=>m.instance===instanceName), [monitorsAll, instanceName]);
  const filtered = all.filter(m=>{
    if (type && m.info?.monitor_type !== type) return false;
    if (!showHidden && hiddenSet.has(`${m.instance}|${m.info?.monitor_name}`)) return false;
    if (q && !(`${m.info?.monitor_name||""} ${m.info?.monitor_url||""} ${m.info?.monitor_hostname||""}`.toLowerCase().includes(q.toLowerCase()))) return false;
    return true;
  });
  const vis = all.filter(m=>!hiddenSet.has(`${m.instance}|${m.info?.monitor_name}`));
  const up=vis.filter(m=>m.latest?.status===1).length, down=vis.filter(m=>m.latest?.status===0).length, total=vis.length;
  const rts=vis.map(m=>m.latest?.responseTime).filter(v=>v!=null); const avg=rts.length?Math.round(rts.reduce((a,b)=>a+b,0)/rts.length):null;
  const len = Math.min(...vis.map(m=>(m.points||[]).length).filter(Boolean));
  const trend = Number.isFinite(len) ? Array.from({length:Math.min(len,50)},(_,i)=>{
    const vals = vis.map(m=>m.points[m.points.length-len+i]?.responseTime).filter(v=>v!=null);
    return vals.length? vals.reduce((a,b)=>a+b,0)/vals.length : 0;
  }) : [];

  const types = [...new Set(all.map(m=>m.info?.monitor_type).filter(Boolean))].sort();

  return (
    <div className="container" style={{paddingTop:0}}>
      <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:8}}>
        <div style={{display:"flex",gap:10,alignItems:"center"}}>
          <button className="btn" onClick={()=>history.back()}>← Volver</button>
          <h2>{instanceName}</h2>
        </div>
        <div className="kpis" style={{gridTemplateColumns:"repeat(4,auto)",gap:10}}>
          <div className="kpi ok"><div className="label">UP</div><div style={{fontSize:18,fontWeight:600}}>{up}</div></div>
          <div className="kpi down"><div className="label">DOWN</div><div style={{fontSize:18,fontWeight:600}}>{down}</div></div>
          <div className="kpi info"><div className="label">Total</div><div style={{fontSize:18,fontWeight:600}}>{total}</div></div>
          <div className="kpi violet"><div className="label">Prom (ms)</div><div style={{fontSize:18,fontWeight:600}}>{avg ?? "—"}</div></div>
        </div>
      </div>

      <Sparkline data={trend} color="#0ea5e9" />

      <div className="controls" style={{marginTop:12}}>
        <div style={{display:"flex",gap:10,flexWrap:"wrap"}}>
          <select className="sel" value={type} onChange={e=>setType(e.target.value)}>
            <option value="">Todos los tipos</option>
            {types.map(t=><option key={t} value={t}>{t}</option>)}
          </select>
          <input className="input" style={{width:240}} placeholder="Buscar servicio…" value={q} onChange={e=>setQ(e.target.value)} />
          <label className="muted"><input type="checkbox" checked={showHidden} onChange={e=>setShowHidden(e.target.checked)} /> Ver ocultos</label>
        </div>
        <div style={{display:"flex",gap:8}}>
          <button className="btn danger" onClick={()=>onHideAll(instanceName)}>Ocultar todos</button>
          <button className="btn primary" onClick={()=>onUnhideAll(instanceName)}>Mostrar todos</button>
        </div>
      </div>

      {filtered.length
        ? <div className="grid">{filtered.map(m=> <MonitorCard key={m.key} m={m} hiddenSet={hiddenSet} onHide={onHide} onUnhide={onUnhide} />)}</div>
        : <div className="muted">No hay monitores para los filtros actuales.</div>}
    </div>
  );
}
JSX

echo "[UI] MonitorsTable con badges UP/DOWN…"
cat > src/components/MonitorsTable.jsx <<'JSX'
export default function MonitorsTable({ monitors = [], hiddenSet, onHide, onUnhide }) {
  return (
    <div className="card">
      <table className="table">
        <thead>
          <tr>
            <th>Estado</th><th>Monitor</th><th>Instancia</th><th>Tipo</th><th>Objetivo</th>
            <th className="align-right">Latencia</th><th>Acción</th>
          </tr>
        </thead>
        <tbody>
          {monitors.map(m=>{
            const hidden = hiddenSet.has(`${m.instance}|${m.info?.monitor_name}`);
            const up = m.latest?.status===1;
            return (
              <tr key={m.key} style={{opacity:hidden?0.5:1}}>
                <td><span className={`badge ${up?"up":"down"}`}>{up?"UP":"DOWN"}</span></td>
                <td><b>{m.info?.monitor_name}</b></td>
                <td>{m.instance}</td>
                <td>{m.info?.monitor_type}</td>
                <td>{m.info?.monitor_url || m.info?.monitor_hostname || "-"}</td>
                <td className="align-right">{m.latest?.responseTime ?? "—"}</td>
                <td>
                  {!hidden
                    ? <button className="btn danger" onClick={()=>onHide(m.instance,m.info?.monitor_name)}>Ocultar</button>
                    : <button className="btn primary" onClick={()=>onUnhide(m.instance,m.info?.monitor_name)}>Mostrar</button>}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
JSX

echo "[UI] App.jsx con tabs y navegación estable…"
cat > src/App.jsx <<'JSX'
import { useEffect, useMemo, useState } from "react";
import Cards from "./components/Cards.jsx";
import Filters from "./components/Filters.jsx";
import ServiceGrid from "./components/ServiceGrid.jsx";
import MonitorsTable from "./components/MonitorsTable.jsx";
import InstanceDetail from "./components/InstanceDetail.jsx";
import { fetchSummary, fetchMonitors, openStream, getBlocklist, saveBlocklist } from "./api.js";

function getRoute(){
  const parts = (window.location.hash||"").slice(1).split("/").filter(Boolean);
  if (parts[0]==="sede" && parts[1]) return { name:"sede", instance: decodeURIComponent(parts[1]) };
  return { name:"home" };
}

export default function App(){
  const [summary,setSummary]=useState({up:0,down:0,total:0,avgResponseTimeMs:null});
  const [monitors,setMonitors]=useState([]);
  const [filters,setFilters]=useState({instance:"",type:"",q:"",onlyDown:false});
  const [hidden,setHidden]=useState(new Set());
  const [view,setView]=useState("grid");
  const [route,setRoute]=useState(getRoute());

  useEffect(()=>{
    const onHash=()=>setRoute(getRoute());
    window.addEventListener("hashchange",onHash);
    return ()=>window.removeEventListener("hashchange",onHash);
  },[]);

  useEffect(()=>{
    (async ()=>{
      try{
        const s=await fetchSummary(); setSummary(s||{});
        const ms=await fetchMonitors(); setMonitors(ms||[]);
        const bl=await getBlocklist(); setHidden(new Set((bl?.monitors||[]).map(k=>`${k.instance}|${k.name}`)));
      }catch{ /* ignora para producción simple */ }
    })();
    const close = openStream(p=>{
      const ms=p?.monitors||[];
      setMonitors(ms);
      const up=ms.filter(m=>m.latest?.status===1).length;
      const down=ms.filter(m=>m.latest?.status===0).length;
      const rt=ms.map(m=>m.latest?.responseTime).filter(v=>v!=null);
      setSummary({up,down,total:ms.length,avgResponseTimeMs: rt.length? Math.round(rt.reduce((a,b)=>a+b,0)/rt.length):null});
    });
    return close;
  },[]);

  const filteredAll = useMemo(()=> (monitors||[]).filter(m=>{
    if (filters.instance && m.instance!==filters.instance) return false;
    if (filters.type && m.info?.monitor_type!==filters.type) return false;
    if (filters.onlyDown && m.latest?.status!==0) return false;
    if (filters.q){
      const hay = `${m.info?.monitor_name||""} ${m.info?.monitor_url||""} ${m.info?.monitor_hostname||""}`.toLowerCase();
      if (!hay.includes(filters.q.toLowerCase())) return false;
    }
    return true;
  }), [monitors,filters]);

  const visible = filteredAll.filter(m=>!hidden.has(`${m.instance}|${m.info?.monitor_name}`));

  async function persistHidden(next){
    const arr=[...next].map(k=>{const [instance,name]=k.split("|");return {instance,name};});
    await saveBlocklist({monitors:arr}); setHidden(next);
  }
  function onHide(instance,name){ const next=new Set(hidden); next.add(`${instance}|${name}`); persistHidden(next); }
  function onUnhide(instance,name){ const next=new Set(hidden); next.delete(`${instance}|${name}`); persistHidden(next); }
  function onHideAll(instance){
    const next = new Set(hidden);
    filteredAll.filter(m=>m.instance===instance).forEach(m=>next.add(`${m.instance}|${m.info?.monitor_name}`));
    persistHidden(next);
  }
  async function onUnhideAll(instance){
    const bl=await getBlocklist();
    const nextArr=(bl?.monitors||[]).filter(k=>k.instance!==instance);
    await saveBlocklist({monitors:nextArr});
    setHidden(new Set(nextArr.map(k=>`${k.instance}|${k.name}`)));
  }

  function openInstance(name){ window.location.hash="/sede/"+encodeURIComponent(name); }
  function tabBtn(v,t){ return <button className={`btn tab ${view===v?"active":""}`} onClick={()=>setView(v)}>{t}</button>; }

  if (route.name==="sede"){
    return (
      <div className="container">
        <InstanceDetail
          instanceName={route.instance}
          monitorsAll={filteredAll}
          hiddenSet={hidden}
          onHide={onHide} onUnhide={onUnhide}
          onHideAll={onHideAll} onUnhideAll={onUnhideAll}
        />
      </div>
    );
  }

  return (
    <div className="container">
      <h1>Uptime Central</h1>
      <Cards summary={summary}/>
      <div className="controls">
        <Filters monitors={monitors} value={filters} onChange={setFilters}/>
        <div style={{display:"flex",gap:8}}>
          {tabBtn("grid","Grid")}
          {tabBtn("table","Tabla")}
        </div>
      </div>
      {view==="grid"
        ? <ServiceGrid monitorsAll={filteredAll} hiddenSet={hidden} onHideAll={onHideAll} onUnhideAll={onUnhideAll} onOpen={openInstance}/>
        : <MonitorsTable monitors={visible} hiddenSet={hidden} onHide={onHide} onUnhide={onUnhide}/>}
    </div>
  );
}
JSX

echo "[UI] Patch aplicado."

