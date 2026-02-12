import React, { useMemo } from "react";

/**
 * Convierte un punto cualquiera en { ts, ms }
 * Soporta: número simple, {ts,ms}, {x,y}, [ts,ms], {sec}, etc.
 */
function toMsPoint(p, idx) {
  if (p == null) return null;

  // Caso 1: número simple ? índice = ts
  if (typeof p === "number") {
    return { ts: idx, ms: p };
  }

  // Caso 2: objeto o array
  const ts = p.ts ?? p.x ?? (Array.isArray(p) ? p[0] : idx);
  let ms = p.ms ?? p.avgMs ?? null;

  // Intentar convertir segundos ? milisegundos
  if (ms == null) {
    const sec = p.sec ?? p.y ?? (Array.isArray(p) ? p[1] : null);
    if (typeof sec === "number") ms = sec * 1000;
  }

  return typeof ms === "number" ? { ts, ms } : null;
}

export default function Sparkline({
  points = [],
  color = "#16a34a",
  width = 120,
  height = 28,
  strokeWidth = 2,
}) {
  const path = useMemo(() => {
    // Normalizar puntos
    const norm = points
      .map((p, idx) => toMsPoint(p, idx))
      .filter(Boolean);

    // Sin puntos ? nada que dibujar
    if (norm.length === 0) return "";

    // Solo 1 punto ? duplicar para línea plana
    if (norm.length === 1) {
      const p = norm[0];
      norm.push({ ts: p.ts + 1, ms: p.ms });
    }

    const xs = norm.map((p) => p.ts);
    const ys = norm.map((p) => p.ms);

    const minX = Math.min(...xs);
    const maxX = Math.max(...xs);
    const minY = Math.min(...ys);
    const maxY = Math.max(...ys);

    const pad = 3;
    const w = width - pad * 2;
    const h = height - pad * 2;

    const sx = (x) =>
      pad + (w * (x - minX)) / (maxX - minX || 1);

    const sy = (y) =>
      pad + h - (h * (y - minY)) / (maxY - minY || 1);

    // Construcción del path SVG
    let d = "";
    norm.forEach((p, i) => {
      d += `${i === 0 ? "M" : "L"} ${sx(p.ts)} ${sy(p.ms)} `;
    });

    return d;
  }, [points, width, height]);

  // Sin path ? devolver un contenedor vacío
  if (!path) {
    return <div style={{ width, height }} />;
  }

  return (
    <svg width={width} height={height}>
      <path
        d={path}
        fill="none"
        stroke={color}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
      />
    </svg>
  );
}