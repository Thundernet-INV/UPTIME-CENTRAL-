#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
FILE="$ROOT/src/components/HistoryChart.jsx"
BAK="$FILE.bak_$(date +%Y%m%d_%H%M%S)"

[ -f "$FILE" ] && cp "$FILE" "$BAK" || true

cat > "$FILE" <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Tooltip,
  Legend,
  Filler,
} from "chart.js";
import 'chartjs-adapter-date-fns';
import { es } from 'date-fns/locale';

ChartJS.register(LineElement, PointElement, LinearScale, TimeScale, Tooltip, Legend, Filler);

/** Normalizadores universales */
function toMs(p) {
  // p puede ser: [ts, sec], {x,y},{ts,sec},{ms|avgMs}, etc.
  if (p == null) return null;
  const ts = (p.x ?? p.ts ?? (Array.isArray(p) ? p[0] : null));
  let ms = (p.ms ?? p.avgMs ?? null);
  if (ms == null) {
    const sec = (p.y ?? p.sec ?? (Array.isArray(p) ? p[1] : null));
    if (typeof sec === 'number') ms = sec * 1000;
  }
  return (ts != null && typeof ms === 'number') ? { ts, ms } : null;
}

// Convierte array de puntos -> { t:[], v:[] } (valores en ms)
function normalizeSeriesMon(seriesMon = []) {
  const arr = Array.isArray(seriesMon) ? seriesMon : [];
  const out = arr.map(toMs).filter(Boolean).sort((a,b)=>a.ts-b.ts);
  return { t: out.map(p=>p.ts), v: out.map(p=>p.ms) };
}

// Agrega por minuto un OBJETO { name: puntos[] } -> { t:[], v:[] } (promedio ms)
function aggregateInstanceObject(seriesObj = {}, bucketMs = 60_000) {
  const sum = new Map();  // bucketTs -> suma ms
  const cnt = new Map();  // bucketTs -> n
  for (const arr of Object.values(seriesObj || {})) {
    if (!Array.isArray(arr)) continue;
    for (const raw of arr) {
      const p = toMs(raw);
      if (!p) continue;
      const b = Math.floor(p.ts / bucketMs) * bucketMs;
      sum.set(b, (sum.get(b) || 0) + p.ms);
      cnt.set(b, (cnt.get(b) || 0) + 1);
    }
  }
  const ts = Array.from(sum.keys()).sort((a,b)=>a-b);
  const v  = ts.map(t => (sum.get(t) / Math.max(1, cnt.get(t))));
  return { t: ts, v };
}

export default function HistoryChart({ mode="instance", series, seriesMon, title="Latencia (ms)", h=260 }) {
  /**
   * Entrada admitida:
   *  - mode==="monitor":   seriesMon = Array<punto>
   *  - mode==="instance":  series = { lat:{t,v}?, dwn:{v}? }  O  series = { monitorName: Array<punto>, ... }
   * Salida interna:
   *  - base.t = timestamps (ms epoch), base.v = valores en ms
   */
  const base = useMemo(() => {
    if (mode === "monitor") {
      return { ...normalizeSeriesMon(seriesMon), label: title };
    }
    // Modo sede: si vienen lat/dwn ya armados, úsalo
    if (series?.lat?.t && series?.lat?.v) {
      return { t: series.lat.t, v: series.lat.v, label: "Prom (ms)", dwn: series?.dwn?.v ?? [] };
    }
    // De lo contrario, viene como objeto { name: puntos[] } → lo agregamos por minuto
    const agg = aggregateInstanceObject(series || {}, 60_000);
    return { t: agg.t, v: agg.v, label: "Prom (ms)", dwn: [] };
  }, [mode, series, seriesMon, title]);

  // Pico (opcional)
  const maxInfo = useMemo(() => {
    const vals = base.v || [];
    let idx = -1, max = -Infinity;
    vals.forEach((x, i) => { if (x != null && x > max) { max = x; idx = i; }});
    if (idx < 0) return null;
    const ts = base.t[idx];
    return { idx, ts, val: Math.round(max) };
  }, [base]);

  const peakDataset = useMemo(() => {
    if (!maxInfo) return null;
    const arr = new Array(base.v.length).fill(null);
    arr[maxInfo.idx] = maxInfo.val;
    return {
      label: "pico",
      data: arr,
      yAxisID: "y",
      borderColor: "transparent",
      backgroundColor: "#ef4444",
      pointBackgroundColor: "#ef4444",
      pointBorderColor: "#fff",
      pointBorderWidth: 2,
      pointRadius: 5,
      showLine: false,
      hoverRadius: 6,
    };
  }, [base, maxInfo]);

  const data = useMemo(() => {
    const labels = base.t || [];
    if (mode === "monitor") {
      const ds = [{
        label: base.label,
        data: base.v,              // ms
        yAxisID: "y",
        borderColor: "#3b82f6",
        backgroundColor: "#3b82f622",
        tension: .35, pointRadius: 0, fill: true, spanGaps: true,
      }];
      if (peakDataset) ds.push(peakDataset);
      return { labels, datasets: ds };
    }
    // instance
    const ds = [
      {
        label: "Prom (ms)",
        data: base.v,              // ms
        yAxisID: "y",
        borderColor: "#3b82f6",
        backgroundColor: "#3b82f622",
        tension: .35, pointRadius: 0, fill: true, spanGaps: true,
      },
      {
        label: "Downs",
        data: series?.dwn?.v ?? [],  // si existe en tu shape legado
        yAxisID: "y1",
        borderColor: "#ef4444",
        backgroundColor: "#ef444422",
        tension: .2, pointRadius: 0, fill: true, spanGaps: true,
      }
    ];
    if (peakDataset) ds.push(peakDataset);
    return { labels, datasets: ds };
  }, [mode, base, series, peakDataset]);

  const options = {
    responsive: true, maintainAspectRatio: false,
    scales: {
      x: {
        type: 'time',
        time: { unit: 'minute', displayFormats: { minute: 'HH:mm', second: 'HH:mm:ss' }, tooltipFormat: 'HH:mm:ss' },
        ticks: { autoSkip: true, maxTicksLimit: 8 },
        adapters: { date: { locale: es } },
        grid: { color: '#e5e7eb' },
      },
      y:  { position: "left",  grid: { color: "#e5e7eb" }, title: { display: true, text: 'ms' } },
      y1: { position: "right", grid: { drawOnChartArea: false } }
    },
    plugins: { legend: { position: "bottom" }, tooltip: { enabled: true } }
  };

  const chip = maxInfo ? (
    <div className="k-chip" style={{marginBottom: 6}}>
      Máximo: <strong>{maxInfo.val} ms</strong> — {new Date(maxInfo.ts).toLocaleTimeString('es-VE', {hour:'2-digit',minute:'2-digit',second:'2-digit'})}
    </div>
  ) : null;

  return (
    <div>
      {chip}
      <div style={{height:h}}>
        <Line data={data} options={options}/>
      </div>
    </div>
  );
}
JSX

echo "== Compilando =="
cd "$ROOT"
npm run build

echo "== Desplegando =="
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ HistoryChart adaptado: acepta array de puntos y objeto por sede; dibuja en ms."
