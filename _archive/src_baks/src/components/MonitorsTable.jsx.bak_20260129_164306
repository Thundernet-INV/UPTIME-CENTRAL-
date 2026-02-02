import React from "react";
import Logo from "./Logo.jsx";
import ResponseTimeMini from "./charts/ResponseTimeMini.jsx";
import UptimeBarMini from "./charts/UptimeBarMini.jsx";
import { uptimePct, breaches } from "../lib/sla";

export default function MonitorsTable({ monitors = [], hiddenSet, onHide, onUnhide, slaConfig }) {
  return (
    <table className="table">
      <thead>
        <tr>
          <th>Logo</th>
          <th>Estado</th>
          <th>Monitor</th>
          <th>Instancia</th>
          <th>Tipo</th>
          <th>Objetivo</th>
          <th>Tendencia</th>
          <th>Uptime</th>
          <th>SLA</th>
          <th>Latencia</th>
          <th>Acción</th>
        </tr>
      </thead>
      <tbody>
        {monitors.map((m) => {
          const key = `${m.instance}::${m.info?.monitor_name}`;
          const hidden = hiddenSet.has(key);
          const up = m.latest?.status === 1;
          const objetivo = m.info?.monitor_url || m.info?.monitor_hostname || "—";
          const latency = m.latest?.responseTime != null ? `${m.latest.responseTime} ms` : "—";
          const points = m.points ?? [];
          const uptime = uptimePct(points);
          const sla = breaches(points, slaConfig);

          return (
            <tr key={key} className={hidden ? "row-muted" : undefined}>
              <td><Logo monitor={m} /></td>
              <td><span className={`chip ${up ? "up" : "down"}`}>{up ? "UP" : "DOWN"}</span></td>
              <td><strong>{m.info?.monitor_name}</strong></td>
              <td>{m.instance}</td>
              <td>{m.info?.monitor_type}</td>
              <td>{objetivo}</td>
              <td><ResponseTimeMini points={points} /></td>
              <td title={`${uptime}%`}><UptimeBarMini points={points} /></td>
              <td>
                {sla.ok ? (
                  <span className="chip up">OK</span>
                ) : (
                  <span className="chip warn" title={sla.issues.join(" | ")}>BRECHA</span>
                )}
              </td>
              <td>{latency}</td>
              <td>
                {!hidden ? (
                  <button className="btn" onClick={() => onHide(m.instance, m.info?.monitor_name)}>Ocultar</button>
                ) : (
                  <button className="btn" onClick={() => onUnhide(m.instance, m.info?.monitor_name)}>Mostrar</button>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
