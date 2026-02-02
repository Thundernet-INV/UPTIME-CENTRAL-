import React, { useEffect, useState } from "react";

export default function DebugChip() {
  const [snap, setSnap] = useState({ enabled: false, route: "?", count: 0, next: null });

  useEffect(() => {
    const t = setInterval(() => {
      const d = (typeof window !== "undefined" && window.__apDebug) || {};
      setSnap({
        enabled: !!d.enabled,
        route: typeof d.route === "string" ? d.route : "?",
        count: typeof d.count === "number" ? d.count : 0,
        next: d.next || null
      });
    }, 1000);
    return () => clearInterval(t);
  }, []);

  const style = {
    position: "fixed",
    bottom: 10,
    right: 10,
    zIndex: 9999,
    background: "#111827",
    color: "#fff",
    padding: "6px 8px",
    borderRadius: 8,
    fontSize: 12,
    opacity: 0.85,
    fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
  };

  return (
    <div style={style}>
      <b>Playlist</b>{" "}
      {snap.enabled ? "ON" : "OFF"}{" "}
      {"| ruta: "}{snap.route}{" "}
      {"| items: "}{String(snap.count)}{" "}
      {snap.next ? <>{ "| next: " }{ String(snap.next) }</> : null}
    </div>
  );
}
