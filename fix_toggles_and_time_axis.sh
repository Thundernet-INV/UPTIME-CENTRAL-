#!/bin/sh
# Oculta toggle global Grid/Tabla al entrar a sede + activa eje temporal con hora en HistoryChart
set -eu
TS=$(date +%Y%m%d%H%M%S)

need() { [ -f "$1" ] || { echo "[ERROR] Falta $1" >&2; exit 1; }; }

echo "== Validando proyecto =="
need package.json
need vite.config.js
need src/App.jsx
need src/components/HistoryChart.jsx
[ -f src/styles.css ] || touch src/styles.css

echo "== Instalar adapter temporal para Chart.js (date-fns) =="
npm i chartjs-adapter-date-fns --save >/dev/null 2>&1 || true

echo "== Backup de archivos =="
cp src/App.jsx src/App.jsx.bak.$TS
cp src/components/HistoryChart.jsx src/components/HistoryChart.jsx.bak.$TS
cp src/styles.css src/styles.css.bak.$TS

###############################################################################
# 1) App.jsx: data-route={route.name} en el contenedor + .global-toggle y type=button en botones globales
###############################################################################
# a) data-route en contenedor raíz
# Reemplaza: <div className="container">
# por:       <div className="container" data-route={route.name}>
if grep -q 'className="container"' src/App.jsx; then
  sed -i '0,/<div className="container">/s//<div className="container" data-route={route.name}>/' src/App.jsx || true
fi

# b) Dar clase .global-toggle al bloque de botones globales y asegurar type=button + aria-pressed
# Buscamos la primera aparición del par de botones Grid/Tabla junto a los filtros del header.
# Normalizamos a:
#   <div className="global-toggle">
#     <button type="button" ...>Grid</button>
#     <button type="button" ...>Tabla</button>
#   </div>
awk '
  BEGIN{block=0}
  {
    line=$0
    # Marcar el div que contiene los dos botones superiores como global-toggle si detecta ambos botones
    if (line ~ /<div[^>]*display:[^>]*gap:[^>]*>/) {
      print line
      next
    }
    # Si encontramos los botones seguidos (Grid/Tabla) sin class global-toggle, añadimos wrapper
    if (line ~ /<button[^>]*>Grid<\/button>/ && block==0) {
      print "<div className=\"global-toggle\">"
      # Forzar type=button y aria-pressed en Grid
      gsub(/<button([^>]*)>/, "<button type=\"button\" className={`btn tab ${view===\"grid\"?\"active\":\"\"}`} aria-pressed={view===\"grid\"} onClick={()=>setView(\"grid\")} >", line)
      print line
      block=1
      next
    }
    if (block==1 && line ~ /<button[^>]*>Tabla<\/button>/) {
      # Forzar type=button y aria-pressed en Tabla
      gsub(/<button([^>]*)>/, "<button type=\"button\" className={`btn tab ${view===\"table\"?\"active\":\"\"}`} aria-pressed={view===\"table\"} onClick={()=>setView(\"table\")} >", line)
      print line
      print "</div>" # cierra global-toggle
      block=2
      next
    }
    print
  }
' src/App.jsx > src/App.jsx.tmp.$TS && mv src/App.jsx.tmp.$TS src/App.jsx

###############################################################################
# 2) HistoryChart.jsx: eje X de tiempo + hora en ticks y tooltips
###############################################################################
# Reescribimos HistoryChart.jsx con escala temporal y formato hora.
cat > src/components/HistoryChart.jsx <<'JSX'
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

export default function HistoryChart({ series, h=260 }) {
  // Usamos timestamps reales para el eje temporal
  const labels = useMemo(() => series?.lat?.t ?? [], [series]);
  const latVals = series?.lat?.v ?? [];
  const dwnVals = series?.dwn?.v ?? [];

  const data = useMemo(()=>({
    labels,
    datasets: [
      {
        label: "Prom (ms)",
        data: latVals,
        yAxisID: "y",
        borderColor: "#3b82f6",
        backgroundColor: "#3b82f622",
        tension: .35, pointRadius: 0, fill: true, spanGaps: true,
      },
      {
        label: "Downs",
        data: dwnVals,
        yAxisID: "y1",
        borderColor: "#ef4444",
        backgroundColor: "#ef444422",
        tension: .2, pointRadius: 0, fill: true, spanGaps: true,
      }
    ]
  }), [labels, latVals, dwnVals]);

  const options = {
    responsive: true, maintainAspectRatio: false,
    scales: {
      x: {
        type: 'time',
        time: {
          unit: 'minute',
          displayFormats: { minute: 'HH:mm', second: 'HH:mm:ss' },
          tooltipFormat: 'HH:mm:ss',
        },
        ticks: { autoSkip: true, maxTicksLimit: 8 },
        adapters: { date: { locale: es } },
        grid: { color: '#e5e7eb' },
      },
      y:  { position: "left",  grid: { color: "#e5e7eb" } },
      y1: { position: "right", grid: { drawOnChartArea: false } }
    },
    plugins: { legend: { position: "bottom" }, tooltip: { enabled: true } }
  };

  return <div style={{height:h}}><Line data={data} options={options}/></div>;
}
JSX

###############################################################################
# 3) CSS: ocultar el toggle global dentro de sede
###############################################################################
cat >> src/styles.css <<'CSS'

/* Ocultar los botones globales Grid/Tabla cuando estoy en una sede */
[data-route="sede"] .global-toggle { display: none !important; }
CSS

echo
echo "✅ Listo. Ejecuta: npm run dev"
echo "• En sede, desaparece el toggle global; solo queda el de la instancia."
echo "• La gráfica de latencia ahora muestra hora en eje X y en los tooltips."
