import React from "react";
import { breaches } from "../lib/sla";

export default function SLAAlerts({ monitors = [], config, onOpenInstance }) {
  const rows = monitors
    .map(m => ({ m, ...breaches(m.points ?? [], config) }))
    .filter(x => !x.ok);

  if (!rows.length) return null;

  return (
    <div className="alert-panel">
      <strong>Alertas SLA</strong>
      <ul>
        {rows.slice(0, 8).map(({ m, issues }, i) => (
          <li key={i}>
            <span className="chip down">SLA</span>
            <b>{m.info?.monitor_name}</b> en <em>{m.instance}</em>: {issues.join(" · ")} {" "}
            <button className="link" onClick={() => onOpenInstance?.(m.instance)}>abrir sede</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
