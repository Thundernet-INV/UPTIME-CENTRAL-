#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
SG="$ROOT/src/components/ServiceGrid.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$SG" ] && cp "$SG" "$SG.bak_counters_$ts" || true

cat > "$SG" <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import MonitorCard from "./MonitorCard.jsx";
import History from "../historyEngine.js";

/**
 * HOME (GRID) por INSTANCIA, usando el MISMO MonitorCard:
 * - Subtítulo: "X UP · Y DOWN · Z servicios"
 * - Badge y bordes dinámicos: latest.status (DOWN si algún servicio está DOWN)
 * - Latencia: promedio ms de la sede
 * - Sparkline: promedio de sede (15 min)
 */
export default function ServiceGrid({
  monitorsAll = [],
  hiddenSet = new Set(),
  onHideAll,
  onUnhideAll,
  onOpen,     // openInstance(name)
}) {
  // (1) Agrupar por instancia excluyendo ocultos (instancia,monitor)
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

  // (2) Series promedio por instancia (15 min) con refresco 10s
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

  // (3) Construir "monitor" sintético para que MonitorCard pinte con MISMO estilo/clases
  function asMonitor(inst) {
    const arr = grouped.get(inst) || [];
    const up    = arr.filter(m => m.latest?.status === 1).length;
    const down  = arr.filter(m => m.latest?.status === 0).length;
    const total = arr.length;

    const anyDown = down > 0;
    const rts = arr.map(m => m.latest?.responseTime).filter(v => typeof v === "number");
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0) / rts.length) : null;

    // Subtítulo mostrado por MonitorCard: hostFromUrl(url) || url → texto plano OK
    const subtitle = `${up} UP · ${down} DOWN · ${total} servicios`;

    return {
      instance: inst,
      info: {
        monitor_name: inst,       // título = nombre de la sede
        monitor_url: subtitle,    // subtítulo = contador UP/DOWN/TOTAL
        monitor_type: "instance",
      },
      latest: {
        status: anyDown ? 0 : 1,  // badge/bordes dinámicos
        responseTime: avgMs,      // "Latencia: xxx ms"
      }
    };
  }

  // (4) Render: una tarjeta por instancia con el MISMO MonitorCard
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
            onHide={(i/*=instancia*/, _name) => onHideAll?.(i)}         // ocultar toda la sede
            onUnhide={(i/*=instancia*/, _name) => onUnhideAll?.(i)}     // mostrar toda la sede
            onFocus={() => onOpen?.(inst)}                               // clic → abrir sede
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
echo "✓ Listo: contador UP/DOWN/TOTAL en cards de INSTANCIAS (mismo estilo que servicios)."
