import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import { Chart as ChartJS } from "chart.js/auto";
import "chartjs-adapter-date-fns";
import { es } from "date-fns/locale";

// Ventana de 1 hora en milisegundos
const ONE_HOUR_MS = 60 * 60 * 1000;

/** Normalizadores universales */
function toMs(p) {
  // p puede ser: [ts, sec], {x,y},{ts,sec},{ms|avgMs}, etc.
  if (p == null) return null;
  const ts = p.x ?? p.ts ?? (Array.isArray(p) ? p[0] : null);
  let ms = p.ms ?? p.avgMs ?? null;
  if (ms == null) {
    const sec = p.y ?? p.sec ?? (Array.isArray(p) ? p[1] : null);
    if (typeof sec === "number") ms = sec * 1000;
  }
  return ts != null && typeof ms === "number" ? { ts, ms } : null;
}

// Convierte array de puntos -> { t:[], v:[] } (valores en ms)
function normalizeSeriesMon(seriesMon = []) {
  const arr = Array.isArray(seriesMon) ? seriesMon : [];
  const out = arr.map(toMs).filter(Boolean).sort((a, b) => a.ts - b.ts);
  return { t: out.map((p) => p.ts), v: out.map((p) => p.ms) };
}

// Agrega por minuto un OBJETO { name: puntos[] } -> { t:[], v:[] } (promedio ms)
function aggregateInstanceObject(seriesObj = {}, bucketMs = 60_000) {
  const sum = new Map(); // bucketTs -> suma ms
  const cnt = new Map(); // bucketTs -> n
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
  const ts = Array.from(sum.keys()).sort((a, b) => a - b);
  const v = ts.map((t) => sum.get(t) / Math.max(1, cnt.get(t)));
  return { t: ts, v };
}

export default function HistoryChart({
  mode = "instance",
  series,
  seriesMon,
  seriesMulti = [],
  title = "Latencia (ms)",
  h = 260,
}) {
  /**
   * Entrada admitida:
   *  - mode==="monitor":   seriesMon = Array<punto>
   *  - mode==="instance":  series = { lat:{t,v}?, dwn:{v}? }  O  series = { monitorName: Array<punto>, ... }
   *  - mode==="multi":     seriesMulti = [{ id,label,color,points[] }, ...]
   */

  const base = useMemo(() => {
    if (mode === "multi") {
      // En multi usaremos seriesMulti directamente
      return { t: [], v: [], label: "", dwn: [] };
    }

    if (mode === "monitor") {
      return { ...normalizeSeriesMon(seriesMon), label: title };
    }
    // Modo sede: si vienen lat/dwn ya armados, úsalo
    if (series?.lat?.t && series?.lat?.v) {
      return {
        t: series.lat.t,
        v: series.lat.v,
        label: "Prom (ms)",
        dwn: series?.dwn?.v ?? [],
      };
    }
    // De lo contrario, viene como objeto { name: puntos[] } ? lo agregamos por minuto
    const agg = aggregateInstanceObject(series || {}, 60_000);
    return { t: agg.t, v: agg.v, label: "Prom (ms)", dwn: [] };
  }, [mode, series, seriesMon, title, seriesMulti]);

  // Pico (opcional, solo en modos instance/monitor)
  const maxInfo = useMemo(() => {
    if (mode === "multi") return null;
    const vals = base.v || [];
    let idx = -1,
      max = -Infinity;
    vals.forEach((x, i) => {
      if (x != null && x > max) {
        max = x;
        idx = i;
      }
    });
    if (idx < 0) return null;
    const ts = base.t[idx];
    return { idx, ts, val: Math.round(max) };
  }, [mode, base]);

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
    // --- MODO MULTI: varias líneas (una por sede) ---
    if (mode === "multi") {
      if (!Array.isArray(seriesMulti) || seriesMulti.length === 0) {
        return { labels: [], datasets: [] };
      }

      const first = normalizeSeriesMon(seriesMulti[0].points);
      const labels = first.t || [];

      const datasets = seriesMulti.map((serie, idx) => {
        const norm = normalizeSeriesMon(serie.points);
        return {
          label: serie.label || `Serie ${idx + 1}`,
          data: norm.v,
          yAxisID: "y",
          borderColor: serie.color || "#3b82f6",
          backgroundColor: "transparent",
          tension: 0.35,
          pointRadius: 0,
          borderWidth: 2,
          fill: false,
          spanGaps: true,
        };
      });

      return { labels, datasets };
    }

    // --- MODO MONITOR: una sola línea ---
    const labels = base.t || [];
    if (mode === "monitor") {
      const ds = [
        {
          label: base.label,
          data: base.v, // ms
          yAxisID: "y",
          borderColor: "#3b82f6",
          backgroundColor: "#3b82f622",
          tension: 0.35,
          pointRadius: 0,
          borderWidth: 2,
          fill: true,
          spanGaps: true,
        },
      ];
      if (peakDataset) ds.push(peakDataset);
      return { labels, datasets: ds };
    }

    // --- MODO INSTANCE (SEDE) ---
    const ds = [
      {
        label: "Prom (ms)",
        data: base.v, // ms
        yAxisID: "y",
        borderColor: "#3b82f6",
        backgroundColor: "#3b82f622",
        tension: 0.35,
        pointRadius: 0,
        borderWidth: 2,
        fill: true,
        spanGaps: true,
      },
      {
        label: "Downs",
        data: series?.dwn?.v ?? [], // si existe en tu shape legado
        yAxisID: "y1",
        borderColor: "#ef4444",
        backgroundColor: "#ef444422",
        tension: 0.2,
        pointRadius: 0,
        borderWidth: 2,
        fill: true,
        spanGaps: true,
      },
    ];
    if (peakDataset) ds.push(peakDataset);
    return { labels, datasets: ds };
  }, [mode, base, series, peakDataset, seriesMulti]);

  const options = useMemo(() => {
    const labels = data?.labels || [];
    let xMin;
    let xMax;

    if (labels.length > 0) {
      const lastLabel = labels[labels.length - 1];
      const lastTs =
        typeof lastLabel === "number"
          ? lastLabel
          : new Date(lastLabel).getTime();

      xMax = lastTs;
      xMin = lastTs - ONE_HOUR_MS; // solo la última hora
    }

    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: false, // sin animación para evitar parpadeos
      interaction: {
        mode: "nearest",
        intersect: false,
      },
      scales: {
        x: {
          type: "time",
          time: {
            unit: "minute",
            displayFormats: { minute: "HH:mm", second: "HH:mm:ss" },
            tooltipFormat: "HH:mm:ss",
          },
          min: xMin,
          max: xMax,
          ticks: { autoSkip: true, maxTicksLimit: 8 },
          adapters: { date: { locale: es } },
          grid: { color: "#e5e7eb" },
        },
        y: {
          position: "left",
          grid: { color: "#e5e7eb" },
          title: { display: true, text: "ms" },
        },
        y1: {
          position: "right",
          grid: { drawOnChartArea: false },
        },
      },
      plugins: {
        legend: { position: "bottom" },
        tooltip: {
          enabled: true,
          callbacks: {
            label(context) {
              const label = context.dataset.label || "";
              const y = context.parsed.y;
              const ms = typeof y === "number" ? Math.round(y) : y;
              return `${label}: ${ms} ms`;
            },
          },
        },
      },
    };
  }, [data]);

  const chip = maxInfo ? (
    <div className="k-chip" style={{ marginBottom: 6 }}>
      Máximo: <strong>{maxInfo.val} ms</strong> —{" "}
      {new Date(maxInfo.ts).toLocaleTimeString("es-VE", {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      })}
    </div>
  ) : null;

  return (
    <div>
      {chip}
      <div style={{ height: h }}>
        <Line data={data} options={options} style={{ width: "100%", height: "100%" }} />
      </div>
    </div>
  );
}