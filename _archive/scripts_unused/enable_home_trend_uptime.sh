#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
SG="$ROOT/src/components/ServiceGrid.jsx"
MT="$ROOT/src/components/MonitorsTable.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$SG" ] && cp "$SG" "$SG.bak_$ts" || true
[ -f "$MT" ] && cp "$MT" "$MT.bak_$ts" || true

echo "== 1) Reescribiendo ServiceGrid.jsx: series por monitor (Home Grid) =="
cat > "$SG" <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import MonitorCard from "./MonitorCard.jsx";
import History from "../historyEngine.js";

/**
 * ServiceGrid — Home (grid)
 * - Recibe monitores planos (de todas las instancias, filtrados).
 * - Carga series por monitor (15 min) y refresca cada 10 s.
 * - Pasa 'series' a cada MonitorCard para que pinte el sparkline (y uptime si el card lo muestra).
 */
export default function ServiceGrid({
  monitorsAll = [],
  hiddenSet = new Set(),
  onHideAll,
  onUnhideAll,
  onOpen,
}) {
  // Lista visible (excluye ocultos)
  const list = useMemo(
    () => monitorsAll.filter(m => !hiddenSet.has(JSON.stringify({ i: m.instance, n: m.info?.monitor_name }))),
    [monitorsAll, hiddenSet]
  );

  // series por monitor
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
          list.map(async (m) => {
            const name = m.info?.monitor_name || "";
            const arr  = await History.getSeriesForMonitor(m.instance, name, 15*60*1000);
            return [`${m.instance}::${name}`, Array.isArray(arr) ? arr : []];
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
  }, [list.length, tick]);

  return (
    <div className="k-grid-services">
      {list.map((m, i) => {
        const name = m.info?.monitor_name || "";
        const key  = `${m.instance}::${name}`;
        const series = seriesMap.get(key) || [];
        return (
          <MonitorCard
            key={i}
            monitor={m}
            series={series}
            onHide={(inst, nm) => onHideAll?.(inst) /* conservar compat si tu card usa otros callbacks */}
            onUnhide={(inst, nm) => onUnhideAll?.(inst)}
            onFocus={(nm) => { if (typeof onOpen === 'function') onOpen(m.instance); }}
          />
        );
      })}
    </div>
  );
}
JSX

echo "== 2) Reescribiendo MonitorsTable.jsx: Tendencia + Uptime (Home Tabla) =="
cat > "$MT" <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import Sparkline from "./Sparkline.jsx";
import History from "../historyEngine.js";
import Logo from "./Logo.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

/**
 * MonitorsTable — Home (tabla)
 * - Muestra Servicio | Instancia | Estado | Latencia | Tendencia | Uptime | Acciones
 * - Carga series por monitor (15 min) y refresca cada 10 s.
 * - Tendencia: sparkline (ms)
 * - Uptime %: calcula con status en las muestras si está disponible.
 */
export default function MonitorsTable({
  monitors = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  slaConfig,
}) {
  const visible = useMemo(
    () => monitors.filter(m => !hiddenSet.has(JSON.stringify({ i: m.instance, n: m.info?.monitor_name }))),
    [monitors, hiddenSet]
  );

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
          visible.map(async (m) => {
            const name = m.info?.monitor_name || "";
            const arr  = await History.getSeriesForMonitor(m.instance, name, 15*60*1000);
            return [`${m.instance}::${name}`, Array.isArray(arr) ? arr : []];
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
  }, [visible.length, tick]);

  return (
    <div style={{ overflowX: "auto" }}>
      <table className="k-table">
        <thead>
          <tr>
            <th>Servicio</th>
            <th>Instancia</th>
            <th>Estado</th>
            <th>Latencia</th>
            <th>Tendencia</th>
            <th>Uptime</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          {visible.map((m, i) => {
            const name = m.info?.monitor_name || "";
            const inst = m.instance;
            const st   = m.latest?.status === 1 ? "UP" : "DOWN";
            const icon = st === "UP" ? "🟢" : "🔴";
            const lat  = (typeof m.latest?.responseTime === "number") ? `${m.latest.responseTime} ms` : "—";
            const host = hostFromUrl(m.info?.monitor_url || "");
            const series = seriesMap.get(`${inst}::${name}`) || [];

            // Uptime % a partir de status
            const stSamples = (series || []).filter(p => typeof p?.status === "number");
            let uptime = null;
            if (stSamples.length >= 2) {
              const ups = stSamples.filter(p => p.status === 1).length;
              uptime = Math.round((ups / stSamples.length) * 100);
            }

            return (
              <tr key={i}>
                <td className="k-cell-service">
                  <Logo monitor={m} size={18} href={m.info?.monitor_url || ""} />
                  <div className="k-service-text">
                    <div className="k-service-name">{name}</div>
                    <div className="k-service-sub">{host || (m.info?.monitor_url || "")}</div>
                  </div>
                </td>
                <td>{inst}</td>
                <td style={{ fontWeight:'bold', color: st==="UP" ? "#16a34a" : "#dc2626" }}>{icon} {st}</td>
                <td>{lat}</td>
                <td style={{minWidth:140}}>
                  <Sparkline
                    points={series}
                    width={140}
                    height={28}
                    color={st==="UP" ? "#16a34a" : "#dc2626"}
                  />
                </td>
                <td>{uptime != null ? `${uptime}%` : "—"}</td>
                <td>
                  <button className="k-btn k-btn--ghost" onClick={() => onHide?.(inst, name)}>Ocultar</button>
                  <button className="k-btn k-btn--ghost" style={{marginLeft:6}} onClick={() => onUnhide?.(inst, name)}>Mostrar</button>
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

echo "== 3) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Home: Grid con sparkline en cards y Tabla con Tendencia + Uptime."
