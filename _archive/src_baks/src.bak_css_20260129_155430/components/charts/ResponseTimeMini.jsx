import React from "react";

export default function ResponseTimeMini({ points = [], width = 140, height = 36, pad = 4 }) {
  const data = points.map(p => p?.responseTime).filter(v => Number.isFinite(v));
  if (!data.length) return <span>—</span>;
  const max = Math.max(1, ...data);
  const step = (width - 2 * pad) / Math.max(1, data.length - 1);
  const line = data.map((v, i) => {
    const x = pad + i * step;
    const y = height - pad - (v / max) * (height - 2 * pad);
    return `${x},${y}`;
  }).join(" ");

  return (
    <svg width={width} height={height} className="spark">
      <polyline fill="none" stroke="#4f46e5" strokeWidth="2" points={line} />
      <line x1={pad} x2={width - pad} y1={height - pad} y2={height - pad} stroke="#ddd" />
    </svg>
  );
}
