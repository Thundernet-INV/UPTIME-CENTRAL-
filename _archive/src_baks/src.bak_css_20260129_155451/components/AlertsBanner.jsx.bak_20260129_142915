import React, { useEffect } from "react";

export default function AlertsBanner({ alerts=[], onClose=()=>{}, autoCloseMs=10000 }) {
  useEffect(() => {
    const timers = alerts.map(a => setTimeout(() => onClose(a.id), autoCloseMs));
    return () => timers.forEach(t => clearTimeout(t));
  }, [alerts, autoCloseMs, onClose]);

  if (!alerts.length) return null;

  return (
    <div style={{
      position:"sticky", top:8, zIndex:20, display:"flex", flexWrap:"wrap", gap:8,
      background:"transparent", padding:0, marginBottom:8
    }}>
      {alerts.slice(-6).map((a,i) => (
        <div key={a.id || i} style={{
          background:"#111827", color:"#fff", padding:"6px 10px", borderRadius:8,
          boxShadow:"0 2px 6px rgba(0,0,0,.15)", display:"flex", alignItems:"center", gap:8
        }}>
          <strong>Alerta</strong>
          <span>
            {/* Si viene mensaje específico, úsalo; de lo contrario, genérico */}
            {a.msg
              ? a.msg
              : `Evento en ${a.name || 'servicio'} (${a.instance || ''})`}
          </span>
          <button
            type="button"
            onClick={()=>onClose(a.id)}
            style={{ marginLeft:8, border:"1px solid #374151", background:"transparent", color:"#fff",
                     borderRadius:6, padding:"2px 6px", cursor:"pointer" }}
          >
            Cerrar
          </button>
        </div>
      ))}
    </div>
  );
}
