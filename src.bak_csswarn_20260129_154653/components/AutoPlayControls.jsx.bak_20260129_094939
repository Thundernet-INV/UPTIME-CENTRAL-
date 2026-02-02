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
