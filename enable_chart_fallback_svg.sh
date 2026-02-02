#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
CF="$ROOT/src/components/ChartFallback.jsx"
ID="$ROOT/src/components/InstanceDetail.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$CF" ] && cp "$CF" "$CF.bak_$ts" || true
[ -f "$ID" ] && cp "$ID" "$ID.bak_$ts" || true

echo "== 1) Creando ChartFallback.jsx =="
cat > "$CF" <<'JSX'
import React, { useEffect, useState } from "react";

/**
 * Fallback de gráfico: si la gráfica oficial no pinta nada,
 * esta capa dibuja un SVG simple usando los datos reales.
 * - Usa window.__hist.getAvgSeriesByInstance(instancia, ventanaMs)
 * - Escala el eje Y en SEGUNDOS (0.1s ... 2s aprox), que es como viene el eje de tu UI.
 */
export default function ChartFallback({ instance, minutes=15, height=180 }) {
  const [pts, setPts] = useState([]);
  const [active, setActive] = useState(false); // sólo se muestra si detectamos que la UI no dibuja

  useEffect(() => {
    let mounted = true;
    async function load() {
      try {
        if (!window.__hist) return;
        const arr = await window.__hist.getAvgSeriesByInstance(instance, minutes*60*1000);
        // arr: [{ts,x,y,ms,sec,xy},...]; elegimos y(segundos)
        const data = (arr||[]).map(p => ({ x: p.x ?? p.ts, y: p.y ?? (p.ms/1000) ?? p.sec ?? 0 }));
        if (!mounted) return;
        setPts(data);
      } catch {}
    }
    // Primera carga rápida y refresco cada 5s para seguir dibujando
    load();
    const t = setInterval(load, 5000);
    return () => { mounted = false; clearInterval(t); };
  }, [instance, minutes]);

  // Si la UI "oficial" no pinta (0 o muy pocos puntos), activamos fallback
  useEffect(() => {
    const should = (pts && pts.length >= 2);
    setActive(should);
  }, [pts]);

  if (!active) return null;

  // Escalado
  const W = Math.max(300, window.innerWidth - 200);
  const H = height;
  const pad = { l: 40, r: 10, t: 10, b: 25 };
  const w = W - pad.l - pad.r;
  const h = H - pad.t - pad.b;

  const xs = pts.map(p => p.x);
  const ys = pts.map(p => p.y ?? 0);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = Math.min(...ys, 0), maxY = Math.max(...ys, 1);

  const sx = (x) => pad.l + (w * (x - minX)) / Math.max(1, maxX - minX);
  const sy = (y) => pad.t + (h * (1 - (y - minY) / Math.max(0.001, maxY - minY)));

  const d = pts
    .sort((a,b)=> (a.x - b.x))
    .map((p,i) => (i===0 ? `M ${sx(p.x)} ${sy(p.y)}` : `L ${sx(p.x)} ${sy(p.y)}`))
    .join(" ");

  // Eje Y simple con etiquetas 0.1, 0.5, 1.0, 2.0 (segundos)
  const ticks = [0.1, 0.5, 1.0, 2.0].filter(v => v >= minY && v <= Math.max(maxY, 2));

  return (
    <div style={{ marginTop: 8, background:"#fff", border:"1px solid #e5e7eb", borderRadius:8, padding:8 }}>
      <div style={{ fontSize:12, color:"#6b7280", marginBottom:4 }}>
        Fallback de gráfica (promedio sede, {minutes} min) — puntos: {pts.length}
      </div>
      <svg width={W} height={H} role="img" aria-label="fallback-chart">
        {/* Ejes */}
        <line x1={pad.l} y1={H-pad.b} x2={W-pad.r} y2={H-pad.b} stroke="#dadde1" />
        <line x1={pad.l} y1={pad.t} x2={pad.l} y2={H-pad.b} stroke="#dadde1" />

        {/* Ticks Y */}
        {ticks.map((t, i) => (
          <g key={i}>
            <line x1={pad.l-4} y1={sy(t)} x2={pad.l} y2={sy(t)} stroke="#9ca3af" />
            <text x={pad.l-8} y={sy(t)+4} fontSize="10" textAnchor="end" fill="#6b7280">{t.toFixed(1)}</text>
          </g>
        ))}

        {/* Línea */}
        <path d={d} fill="none" stroke="#3b82f6" strokeWidth="2" />
      </svg>
    </div>
  );
}
JSX

echo "== 2) Inyectando ChartFallback debajo de la gráfica original en InstanceDetail.jsx =="
# Insertar import si no existe
grep -q 'ChartFallback' "$ID" || sed -i '1i import ChartFallback from "./ChartFallback.jsx";' "$ID"

# Tras el contenedor de la gráfica oficial, montamos el fallback
# Buscamos una referencia común: el texto "Mostrando:" que suele estar arriba del chart
if ! grep -q 'ChartFallback' "$ID"; then
  sed -i '/Mostrando:/,/Servicios/{ /Servicios/ i \
        {/* Fallback de gráfica (se muestra si la oficial no pinta) */}\
        <ChartFallback instance={instanceName || (route?.instance)} minutes={15} />\
  }' "$ID"
fi

echo "== 3) Compilando y desplegando =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Fallback SVG activado — si la gráfica oficial no pinta, verás esta línea azul."
