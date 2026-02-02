import React from "react";
export default function Filters({ monitors, value, onChange }) {
  function set(k,v){ onChange({ ...value, [k]: v }); }
  function toggleDown(e){ set("status", e.target.checked ? "down" : "all"); }
  return (
    <div className="filters">
      <select value={value.instance} onChange={(e)=>set("instance", e.target.value)}>
        <option value="">Todas las sedes</option>
        {[...new Set(monitors.map(m=>m.instance))].sort().map(n=><option key={n} value={n}>{n}</option>)}
      </select>
      <select value={value.type} onChange={(e)=>set("type", e.target.value)}>
        <option value="">Todos los tipos</option>
        {[...new Set(monitors.map(m=>m.info?.monitor_type))].sort().map(t=><option key={t} value={t}>{t}</option>)}
      </select>
      <input type="text" placeholder="Buscar..." value={value.q} onChange={(e)=>set("q", e.target.value)} />
      <label style={{ marginLeft: 12 }}>
        <input type="checkbox" checked={value.status==="down"} onChange={toggleDown} />{" "}Solo DOWN
      </label>
    </div>
  );
}
