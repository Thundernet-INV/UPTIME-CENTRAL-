import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";

/**
 * Home — TABLA por INSTANCIA
 * Columnas:
 * - Instancia | UP | DOWN | Total | Prom (ms) | Tendencia | Uptime | Acciones
 */
export default function MonitorsTable({
  monitors = [],
  hiddenSet = new Set(),
  onHide, onUnhide,   // mantenemos firma pero aquí no aplican por instancia
  slaConfig,
  onOpen,             // abrir sede
}) {
  // Agrupar por instancia excluyendo ocultos por (instancia,monitor)
  const grouped = useMemo(() => {
    const map = new Map();
    for (const m of monitors) {
      const key = JSON.stringify({ i:m.instance, n:m.info?.monitor_name });
      if (hiddenSet.has(key)) continue;
      const arr = map.get(m.instance) || [];
      arr.push(m);
      map.set(m.instance, arr);
    }
    return map;
  }, [monitors, hiddenSet]);
  const instances = useMemo(() => Array.from(grouped.keys()), [grouped]);

  // series por instancia: promedio de sede (15 min)
  const [seriesMap, setSeriesMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 10000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const pairs = await Promise.all(
          instances.map(async (inst) => {
            const arr = await History.getAvgSeriesByInstance(inst, 15*60*1000);
            return [inst, Array.isArray(arr) ? arr : []];
          })
        );
        if (!alive) return;
        setSeriesMap(new Map(pairs));
      } catch {
        if (!alive) return;
        setSeriesMap(new Map());
      }
    })();
    return () => { alive = false; };
  }, [instances.length, tick]);

  function metricsFor(inst) {
    const arr = grouped.get(inst) || [];
    const up    = arr.filter(m => m.latest?.status === 1).length;
    const down  = arr.filter(m => m.latest?.status === 0).length;
    const total = arr.length;
    const rts   = arr.map(m => m.latest?.responseTime).filter(v => typeof v === 'number');
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0) / rts.length) : null;
    const uptime = total ? Math.round((up/total)*100) : null;
    return { up, down, total, avgMs, uptime };
  }

  return (
    <div style={{ overflowX:"auto" }}>
      <table className="k-table">
        <thead>
          <tr>
            <th>Instancia</th>
            <th>UP</th>
            <th>DOWN</th>
            <th>Total</th>
            <th>Prom (ms)</th>
            <th>Tendencia</th>
            <th>Uptime</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          {instances.map((inst, i) => {
            const s = seriesMap.get(inst) || [];
            const m = metricsFor(inst);
            return (
              <tr key={inst}>
                <td style={{ fontWeight:600, color:"#111827" }}>{inst}</td>
                <td style={{ color:"#16a34a", fontWeight:600 }}>{m.up}</td>
                <td style={{ color:"#dc2626", fontWeight:600 }}>{m.down}</td>
                <td>{m.total}</td>
                <td>{m.avgMs!=null ? `${m.avgMs} ms` : "—"}</td>
                <td style={{ minWidth:160 }}>
                  <Sparkline
                    points={s}
                    width={160}
                    height={32}
                    color="#3b82f6"
                  />
                </td>
                <td>{m.uptime!=null ? `${m.uptime}%` : "—"}</td>
                <td>
                  <button className="k-btn k-btn--ghost" onClick={() => onOpen?.(inst)}>Ver sede</button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
