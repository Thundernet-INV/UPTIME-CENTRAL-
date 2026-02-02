import React, { useMemo } from "react";

/**
 * Sparkline (SVG) robusto:
 * - Acepta arrays de puntos en múltiples formas:
 *   [ts, y], {x,y}, {ts,sec}, {ms|avgMs}, etc.
 * - Dibuja en milisegundos (ms).
 * - Si hay <2 puntos, muestra "—".
 */
function toMsPoint(p) {
  if (p == null) return null;
  const ts = (p.x ?? p.ts ?? (Array.isArray(p) ? p[0] : null));
  let ms = (p.ms ?? p.avgMs ?? null);
  if (ms == null) {
    const sec = (p.y ?? p.sec ?? (Array.isArray(p) ? p[1] : null));
    if (typeof sec === "number") ms = sec * 1000;
  }
  return (ts != null && typeof ms === "number") ? { ts, ms } : null;
}

export default function Sparkline({
  points = [],
  color = "#16a34a",
  width = 120,
  height = 28,
  strokeWidth = 2,
  showArea = false,
  className = ""
}) {
  const data = useMemo(() => {
    const arr = Array.isArray(points) ? points : [];
    const norm = arr.map(toMsPoint).filter(Boolean).sort((a,b)=>a.ts-b.ts);
    if (norm.length < 2) return { path: "", area: "", ok:false };
    const xs = norm.map(p => p.ts);
    const ys = norm.map(p => p.ms);
    const minX = Math.min(...xs), maxX = Math.max(...xs);
    const minY = Math.min(...ys), maxY = Math.max(...ys);
    const padX = 2, padY = 4;
    const w = Math.max(10, width - padX*2);
    const h = Math.max(8, height - padY*2);

    const sx = (x) => padX + (w * (x - minX)) / Math.max(1, maxX - minX);
    const sy = (y) => padY + (h * (1 - (y - minY) / Math.max(1, maxY - minY)));

    let d = "";
    norm.forEach((p,i) => { d += (i===0 ? `M ${sx(p.ts)} ${sy(p.ms)}` : ` L ${sx(p.ts)} ${sy(p.ms)}`); });

    let a = "";
    if (showArea) {
      const first = norm[0], last = norm[norm.length-1];
      a = `${d} L ${sx(last.ts)} ${height-padY} L ${sx(first.ts)} ${height-padY} Z`;
    }
    return { path: d, area: a, ok:true };
  }, [points, width, height, showArea]);

  if (!data.ok) {
    return <span style={{ color:"#9ca3af" }}>—</span>;
  }

  return (
    <svg
      className={className}
      width={width} height={height}
      viewBox={`0 0 ${width} ${height}`}
      role="img" aria-label="sparkline"
    >
      {showArea && data.area && (
        <path d={data.area} fill={`${color}22`} stroke="none" />
      )}
      <path d={data.path} fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round"/>
    </svg>
  );
}
