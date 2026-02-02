#!/usr/bin/env bash
set -e

echo "[INFO] Instalando componentes PRO..."

mkdir -p src/components

########################################
# Sparkline.jsx
########################################
cat > src/components/Sparkline.jsx <<'EOF'
export function Sparkline({ data = [], w = 120, h = 32, color = "#2563eb" }) {
  if (!data.length) return <svg width={w} height={h} />;
  const ys = data.map(p => typeof p === "number" ? p : p.responseTime ?? 0);
  const min = Math.min(...ys), max = Math.max(...ys);
  const dx = w / Math.max(ys.length - 1, 1);
  const y = v => (max === min) ? h/2 : h - ((v - min) / (max - min)) * (h - 2) - 1;
  const pts = ys.map((v,i) => `${i * dx},${y(v)}`).join(" ");
  return (
    <svg width={w} height={h}><polyline fill="none" stroke={color} strokeWidth="2" points={pts}/></svg>
  );
}
EOF

########################################
# Cards.jsx
########################################
cat > src/components/Cards.jsx <<'EOF'
export default function Cards({ summary }) {
  const card = (label,val)=>(
    <div style={{padding:16,borderRadius:12,background:"#fff",boxShadow:"0 1px 8px rgba(0,0,0,0.08)"}}>
      <div style={{color:"#6b7280",fontSize:12}}>{label}</div>
      <div style={{fontSize:22,fontWeight:600}}>{val}</div>
    </div>
  );
  return (
    <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:16}}>
      {card("UP", summary.up ?? 0)}
      {card("DOWN", summary.down ?? 0)}
      {card("Total", summary.total ?? 0)}
      {card("Prom (ms)", summary.avgResponseTimeMs ?? "—")}
    </div>
  );
}
EOF

########################################
# Filters.jsx
########################################
cat > src/components/Filters.jsx <<'EOF'
export default function Filters({ monitors, value, onChange }) {
  const instances = [...new Set(monitors.map(m=>m.instance))].sort();
  const types = [...new Set(monitors.map(m=>m.info?.monitor_type).filter(Boolean))].sort();
  const set = (k,v)=>onChange({...value,[k]:v});

  return (
    <div style={{display:"flex",gap:12,flexWrap:"wrap",margin:"20px 0"}}>
      <select value={value.instance} onChange={e=>set("instance",e.target.value)}>
        <option value="">Todas las sedes</option>
        {instances.map(i=><option key={i}>{i}</option>)}
      </select>

      <select value={value.type} onChange={e=>set("type",e.target.value)}>
        <option value="">Todos los tipos</option>
        {types.map(t=><option key={t}>{t}</option>)}
      </select>

      <input
        placeholder="Buscar…"
        value={value.q}
        onChange={e=>set("q",e.target.value)}
        style={{padding:"4px 8px"}}
      />

      <label>
        <input type="checkbox"
          checked={value.onlyDown}
          onChange={e=>set("onlyDown",e.target.checked)}
        /> Solo DOWN
      </label>
    </div>
  );
}
EOF

########################################
# ServiceCard.jsx
########################################
cat > src/components/ServiceCard.jsx <<'EOF'
import { Sparkline } from "./Sparkline.jsx";

export default function ServiceCard({ sede, data, onHideAll, onUnhideAll, onOpen }) {
  const downs = (data.monitors||[]).filter(m=>m.latest?.status===0).length;
  const ratio = data.total ? downs/data.total : 0;
  const color = ratio>=0.3? "#dc2626" : ratio>=0.1? "#f59e0b" : "#10b981";

  return (
    <div style={card} onClick={()=>onOpen(sede)}>
      <h3>{sede}</h3>
      <Sparkline data={data.trend||[]} w={220} h={40} color={color}/>
      <div style={{display:"flex",gap:10}}>
        <div>UP: {data.up}</div>
        <div>DOWN: {data.down}</div>
        <div>Total: {data.total}</div>
      </div>

      <div style={{display:"flex",gap:8,marginTop:10}}>
        <button onClick={e=>{e.stopPropagation();onHideAll(sede)}}>Ocultar todos</button>
        <button onClick={e=>{e.stopPropagation();onUnhideAll(sede)}}>Mostrar todos</button>
      </div>
    </div>
  );
}

const card = {
  background:"#fff",
  border:"1px solid #e5e7eb",
  padding:16,
  borderRadius:12,
  boxShadow:"0 1px 6px rgba(0,0,0,.06)",
  cursor:"pointer"
};
EOF

########################################
# ServiceGrid.jsx
########################################
cat > src/components/ServiceGrid.jsx <<'EOF'
import ServiceCard from "./ServiceCard.jsx";

export default function ServiceGrid({ monitorsAll, hiddenSet, onHideAll, onUnhideAll, onOpen }) {
  const by = monitorsAll.reduce((a,m)=>{
    (a[m.instance]=a[m.instance]||[]).push(m);
    return a;
  },{});

  const make = (inst,arr)=>{
    const visible = arr.filter(m=>!hiddenSet.has(`${m.instance}|${m.info.monitor_name}`));
    const up = visible.filter(m=>m.latest?.status===1).length;
    const down = visible.filter(m=>m.latest?.status===0).length;
    const total = visible.length;
    const avg = visible.map(m=>m.latest?.responseTime).filter(Boolean);
    const avgMs = avg.length? Math.round(avg.reduce((a,b)=>a+b,0)/avg.length):null;

    const len = Math.min(...visible.map(m=>m.points?.length||9999));
    const trend = Array.from({length:Math.min(len,50)},(_,i)=>{
      const vals = visible.map(m=>m.points[m.points.length-len+i]?.responseTime).filter(Boolean);
      return vals.length? vals.reduce((a,b)=>a+b,0)/vals.length:0;
    });

    return { sede:inst, data:{up,down,total,avg:avgMs,trend,monitors:arr } };
  };

  const cards = Object.entries(by).map(([inst,arr])=>make(inst,arr));

  return (
    <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(260px,1fr))",gap:16}}>
      {cards.map(c=>
        <ServiceCard key={c.sede} sede={c.sede} data={c.data}
          onHideAll={onHideAll} onUnhideAll={onUnhideAll}
          onOpen={onOpen}/>
      )}
    </div>
  );
}
EOF

########################################
# MonitorCard.jsx
########################################
cat > src/components/MonitorCard.jsx <<'EOF'
import { Sparkline } from "./Sparkline.jsx";

export default function MonitorCard({ m, hiddenSet, onHide, onUnhide }) {
  const hidden = hiddenSet.has(`${m.instance}|${m.info.monitor_name}`);
  const ok = m.latest?.status===1;

  return (
    <div style={{...box,opacity:hidden?0.5:1}}>
      <h4>{m.info.monitor_name}</h4>
      <div>{m.latest?.responseTime ?? "—"} ms</div>
      <Sparkline data={m.points||[]} w={200} h={40}/>
      {!hidden ?
         <button onClick={()=>onHide(m.instance,m.info.monitor_name)}>Ocultar</button> :
         <button onClick={()=>onUnhide(m.instance,m.info.monitor_name)}>Mostrar</button>}
    </div>
  );
}

const box = {
  background:"#fff",
  border:"1px solid #e5e7eb",
  padding:12,
  borderRadius:10,
  boxShadow:"0 1px 4px rgba(0,0,0,0.08)"
};
EOF

########################################
# InstanceDetail.jsx
########################################
cat > src/components/InstanceDetail.jsx <<'EOF'
import MonitorCard from "./MonitorCard.jsx";
import { useMemo, useState } from "react";

export default function InstanceDetail({ instanceName, monitorsAll, hiddenSet, onHide, onUnhide, onHideAll, onUnhideAll }) {
  const all = useMemo(()=>monitorsAll.filter(m=>m.instance===instanceName),[monitorsAll,instanceName]);
  const [showHidden,setShowHidden]=useState(false);

  const filtered = all.filter(m=>{
    if(!showHidden && hiddenSet.has(`${m.instance}|${m.info.monitor_name}`)) return false;
    return true;
  });

  return (
    <div style={{padding:20}}>
      <h2>{instanceName}</h2>
      <button onClick={()=>history.back()}>← Volver</button>
      <button onClick={()=>onHideAll(instanceName)}>Ocultar todos</button>
      <button onClick={()=>onUnhideAll(instanceName)}>Mostrar todos</button>
      <label>
        <input type="checkbox"
          checked={showHidden}
          onChange={e=>setShowHidden(e.target.checked)}
        />
        Ver ocultos
      </label>
      <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fill,minmax(260px,1fr))",gap:16}}>
        {filtered.map(m=>(
          <MonitorCard key={m.key} m={m} hiddenSet={hiddenSet} onHide={onHide} onUnhide={onUnhide}/>))}
      </div>  
    </div>
  );
}
EOF

########################################
# MonitorsTable.jsx
########################################
cat > src/components/MonitorsTable.jsx <<'EOF'
export default function MonitorsTable({ monitors, hiddenSet, onHide, onUnhide }) {
  return (
    <table border="1" cellPadding="4" style={{width:"100%",marginTop:20}}>
      <thead><tr>
        <th>Monitor</th><th>Instancia</th><th>Estado</th><th>Latencia</th><th>Acción</th>
      </tr></thead>
      <tbody>
        {monitors.map(m=>{
          const hidden = hiddenSet.has(`${m.instance}|${m.info.monitor_name}`);
          return (
            <tr key={m.key} style={{opacity:hidden?0.5:1}}>
              <td>{m.info.monitor_name}</td>
              <td>{m.instance}</td>
              <td>{m.latest?.status===1?"UP":"DOWN"}</td>
              <td>{m.latest?.responseTime ?? "—"}</td>
              <td>
                {!hidden ?
                  <button onClick={()=>onHide(m.instance,m.info.monitor_name)}>Ocultar</button> :
                  <button onClick={()=>onUnhide(m.instance,m.info.monitor_name)}>Mostrar</button>}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
EOF

echo "[INFO] Componentes PRO instalados."
