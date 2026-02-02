import React from "react";

export default function UptimeBarMini({ points = [], width = 140, height = 12 }) {
  if (!points.length) return <span>—</span>;
  const w = Math.max(1, Math.floor(width / points.length));
  return (
    <svg width={width} height={height} className="bars">
      {points.map((p, i) => {
        const up = p?.status === 1;
        return (
          <rect
            key={i} x={i * w} y={0} width={w - 1} height={height}
            fill={up ? "#16a34a" : "#dc2626"} opacity={up ? 0.8 : 0.9}
          />
        );
      })}
    </svg>
  );
}
