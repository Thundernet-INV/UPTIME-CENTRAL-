import React from "react";

/**
 * Fallback simple para cuando la gráfica de historial
 * no puede renderizarse (sin datos, error, etc.).
 */
export default function ChartFallback({ message = "No hay datos de historial disponibles." }) {
  return (
    <div
      style={{
        padding: 12,
        borderRadius: 8,
        border: "1px dashed #e5e7eb",
        fontSize: 12,
        color: "#6b7280",
        textAlign: "center",
      }}
    >
      {message}
    </div>
  );
}
