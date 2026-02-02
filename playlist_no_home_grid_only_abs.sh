#!/bin/sh
set -eu

APPROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$APPROOT/src/App.jsx"
AUTOP="$APPROOT/src/components/AutoPlayer.jsx"

cd "$APPROOT"
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p "$APPROOT/src/components"

echo "== Backups =="
[ -f "$APP" ]   && cp "$APP"   "$APP.bak_$ts"   || true
[ -f "$AUTOP" ] && cp "$AUTOP" "$AUTOP.bak_$ts" || true

echo "== 1) AutoPlayer v5: sede -> siguiente sede (sin volver a HOME) =="
cat > "$AUTOP" <<'EOF'
import React, { useEffect, useMemo, useRef } from "react";

export default function AutoPlayer({
  enabled=false, intervalSec=10, viewSec=10,
  order="downFirst", onlyIncidents=false, loop=true,
  filteredAll=[], route, openInstance
}) {
  const idxRef = useRef(0);
  const timerRef = useRef(null);

  const instanceStats = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const it = map.get(m.instance) || { up:0, down:0, total:0 };
      if (m.latest?.status === 1) it.up++; else if (m.latest?.status === 0) it.down++;
      it.total++; map.set(m.instance, it);
    }
    return map;
  }, [filteredAll]);

  const playlist = useMemo(() => {
    let arr = Array.from(instanceStats.keys());
    if (onlyIncidents) arr = arr.filter(n => (instanceStats.get(n)?.down || 0) > 0);
    if (order === "downFirst") {
      arr.sort((a,b)=> (instanceStats.get(b)?.down||0) - (instanceStats.get(a)?.down||0) || a.localeCompare(b));
    } else {
      arr.sort((a,b)=> a.localeCompare(b));
    }
    return arr;
  }, [instanceStats, onlyIncidents, order]);

  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  useEffect(() => {
    if (typeof window !== "undefined") {
      window.__apDebug = {
        enabled, route: route?.name, count: playlist.length,
        next: playlist.length ? playlist[idxRef.current % playlist.length] : null,
        intervalSec, viewSec, onlyIncidents, order, loop
      };
    }
  }, [enabled, route?.name, playlist.length, intervalSec, viewSec, onlyIncidents, order, loop]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const goByHash = (name) => { window.location.hash = "/sede/" + encodeURIComponent(name); };

    // Avanza a la siguiente sede a partir de la actual (o índice guardado)
    const gotoNextFrom = (currentName) => {
      if (!playlist.length) return;
      let i = currentName ? playlist.indexOf(currentName) : -1;
      let nextIdx = (i >= 0 ? i + 1 : idxRef.current);
      if (nextIdx >= playlist.length) {
        if (!loop) return;
        nextIdx = 0;
      }
      idxRef.current = nextIdx;
      const nextName = playlist[nextIdx];
      if (typeof openInstance === "function") openInstance(nextName); else goByHash(nextName);
    };

    if (route?.name === "home") {
      const delay = (idxRef.current === 0 ? 300 : Math.max(3, intervalSec) * 1000);
      timerRef.current = setTimeout(() => gotoNextFrom(null), delay);
    } else if (route?.name === "sede") {
      timerRef.current = setTimeout(() => gotoNextFrom(route.instance), Math.max(3, viewSec) * 1000);
    }

    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; } };
  }, [enabled, intervalSec, viewSec, route?.name, route?.instance, playlist.length, loop, openInstance]);

  return null;
}
EOF

echo "== 2) Forzar vista GRID siempre =="
# 2.1 Inserta 'const forceGridAlways = true;' justo después del estado 'view'
if ! grep -q 'forceGridAlways' "$APP"; then
  sed -i '/const $$view, setView$$/a\  const forceGridAlways = true;' "$APP"
fi

# 2.2 Inserta un useEffect que fuerce Grid si alguien cambia a Tabla (lo ubicamos antes del return principal)
if ! grep -q 'if (forceGridAlways && view !== "grid") setView("grid")' "$APP"; then
  # Insertar el efecto justo antes de la primera línea que inicia con '  return ('
  # (GNU sed soporta a\ con salto de línea)
  sed -i '/^  return (/i\  // Forzar Grid si alguien cambia a Tabla\n  useEffect(() => { if (forceGridAlways && view !== "grid") setView("grid"); }, [forceGridAlways, view]);\n' "$APP"
fi

# 2.3 Deshabilitar botón "Tabla" (elimina onClick y añade disabled)
sed -i 's/onClick={() => setView("table")}//g' "$APP"
# Añadir disabled en el primer >Tabla</button> que encontremos (si ya no lo tiene)
grep -q '>Tabla</button>' "$APP" && sed -i '0,/>Tabla<\/button>/{s// disabled>Tabla<\/button>/}' "$APP"

# 2.4 Normalizar className dinámico por concatenación (evitamos backticks o restos rotos)
# Grid
sed -i 's/className={`btn tab \${view==="grid"[^}]*}}/className={"btn tab " + (view==="grid" ? "active" : "")}/g' "$APP"
sed -i 's/className={btn tab \${view==="grid"[^}]*}}/className={"btn tab " + (view==="grid" ? "active" : "")}/g' "$APP"
# Table
sed -i 's/className={`btn tab \${view==="table"[^}]*}}/className={"btn tab " + (view==="table" ? "active" : "")}/g' "$APP"
sed -i 's/className={btn tab \${view==="table"[^}]*}}/className={"btn tab " + (view==="table" ? "active" : "")}/g' "$APP"

echo "== 3) Compilando =="
npm run build

echo "== 4) Desplegando =="
rsync -av --delete "$APPROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: rotación sede→sede en loop (sin Home) y vista forzada a Grid."
