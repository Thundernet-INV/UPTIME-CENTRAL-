#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
SG="$ROOT/src/components/ServiceGrid.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$SG" ] && cp "$SG" "$SG.bak_instas_as_cards_$ts" || true

cat > "$SG" <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import MonitorCard from "./MonitorCard.jsx";
import History from "../historyEngine.js";

/**
 * HOME (GRID) por INSTANCIA, reusando el MISMO MonitorCard (mismo estilo/funcionalidades).
 * - Agrupa por instancia y crea un "monitor" sintético con:
 *    - info.monitor_name = nombre de la sede
 *    - latest.status = 0 si algún servicio de la sede está DOWN; 1 en caso contrario
 *    - latest.responseTime = promedio de responseTime de la sede (ms)
 * - Serie para sparkline: promedio de la sede (15 min) con History.getAvgSeriesByInstance
 * - onHide/onUnhide: aplican sobre la sede completa usando onHideAll/onUnhideAll del padre
 * - onFocus: abre la sede (navega)
 */
export default function ServiceGrid({
  monitorsAll = [],
  hiddenSet = new Set(),
  onHideAll,
  onUnhideAll,
  onOpen,     // openInstance(name)
}) {
  // (1) Agrupar por instancia excluyendo monitores ocultos (tal como haces en Home)
  const grouped = useMemo(() => {
    const map = new Map();
    for (const m of monitorsAll) {
      const k = JSON.stringify({ i: m.instance, n: m.info?.monitor_name });
      if (hiddenSet.has(k)) continue;
      const arr = map.get(m.instance) || [];
      arr.push(m);
      map.set(m.instance, arr);
    }
    return map; // Map<instancia, monitor[]>
  }, [monitorsAll, hiddenSet]);

  const instances = useMemo(() => Array.from(grouped.keys()).sort(), [grouped]);

  // (2) Series promedio por instancia (para el sparkline), con refresco cada 10s
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
            const arr = await History.getAvgSeriesByInstance(inst, 15 * 60 * 1000);
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

  // (3) “Sintetiza” un monitor para que MonitorCard pinte con el MISMO estilo/clases
  function asMonitor(inst) {
    const arr = grouped.get(inst) || [];
    const anyDown = arr.some(m => m.latest?.status === 0);
    const rts = arr.map(m => m.latest?.responseTime).filter(v => typeof v === "number");
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0) / rts.length) : null;

    return {
      instance: inst,
      info: {
        monitor_name: inst,
        monitor_url: "",          // Logo usará default si no hay URL
        monitor_type: "instance", // etiqueta informativa; no afecta estilos
      },
      latest: {
        status: anyDown ? 0 : 1,  // badge/borde dinámico igual que en servicios
        responseTime: avgMs,      // “Latencia: xxx ms”
      }
    };
  }

  // (4) Render: una tarjeta por instancia usando el MISMO MonitorCard
  return (
    <div className="services-grid">
      {instances.map((inst) => {
        const monLike = asMonitor(inst);
        const series  = seriesMap.get(inst) || [];

        return (
          <MonitorCard
            key={inst}
            monitor={monLike}
            series={series}
            // Mantén las MISMAS acciones que en servicios:
            onHide={(i/*=instancia*/, _name) => onHideAll?.(i)}         // Ocultar toda la sede
            onUnhide={(i/*=instancia*/, _name) => onUnhideAll?.(i)}     // Mostrar toda la sede
            onFocus={() => onOpen?.(inst)}                               // Clic en la card → abrir sede
          />
        );
      })}
    </div>
  );
}
JSX

echo "== Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx
echo "✓ Home: tarjetas de INSTANCIAS idénticas a las de SERVICIOS (MonitorCard)."
