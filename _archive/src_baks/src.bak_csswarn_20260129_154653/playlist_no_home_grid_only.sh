#!/bin/sh
set -eu
APP="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p src/components

# Backups
[ -f src/components/AutoPlayer.jsx ] && cp src/components/AutoPlayer.jsx src/components/AutoPlayer.jsx.bak_$ts || true
[ -f src/App.jsx ] && cp src/App.jsx src/App.jsx.bak_$ts || true

echo "== 1) AutoPlayer v5: SEDE -> siguiente SEDE (sin volver a HOME) =="
# Sustituimos AutoPlayer por una versión que:
# - En HOME: inicia en ~300ms.
# - En SEDE: tras viewSec salta directamente a la siguiente SEDE del playlist (loop).
# - Expone window.__apDebug para el chip/logs.
sudo tee src/components/AutoPlayer.jsx > /dev/null <<'EOF'
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

    // Navega a la próxima sede en la lista (respetando loop)
    const gotoNextFrom = (currentName) => {
      if (!playlist.length) return;
      let i = currentName ? playlist.indexOf(currentName) : -1;
      let nextIdx = (i >= 0 ? i + 1 : idxRef.current);
      if (nextIdx >= playlist.length) {
        if (!loop) return;
        nextIdx = 0;
      }
      idxRef.current = nextIdx; // mantener progreso
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

echo "== 2) Forzar vista GRID siempre (bloquear Tabla y autocorregir) =="
# 2.1 Asegurar un efecto que fuerce grid si alguien cambia a table
grep -q 'forceGridAlways' src/App.jsx || sudo awk '
  BEGIN{done=0}
  {
    print
    if (!done && $0 ~ /const $$view, setView$$/) {
      print "  // Forzar Grid siempre"
      print "  const forceGridAlways = true;"
      done=1
    }
  }' src/App.jsx > src/App.jsx.tmp && sudo mv src/App.jsx.tmp src/App.jsx

grep -q 'if (forceGridAlways' src/App.jsx || sudo awk '
  BEGIN{ins=0}
  {
    print
    if (!ins && $0 ~ /useEffect$$\($$ => \{/) { next } # no tocar otros effects
  }
  END{ }
' src/App.jsx > /dev/null 2>&1 || true

# Inserta un efecto dedicado para forzar grid
grep -q 'useEffect(() => { if (forceGridAlways' src/App.jsx || sudo awk '
  BEGIN{inserted=0}
  {
    if (!inserted && $0 ~ /  \/\/ ===== Filtros base/) {
      print "  // Efecto dedicado: si alguien cambia a tabla, volver a grid"
      print "  useEffect(() => { if (forceGridAlways && view !== \"grid\") setView(\"grid\"); }, [forceGridAlways, view]);"
      inserted=1
    }
    print
  }' src/App.jsx > src/App.jsx.tmp && sudo mv src/App.jsx.tmp src/App.jsx

# 2.2 Deshabilitar el botón "Tabla" (que no haga nada)
# Reemplazar el botón Tabla por uno disabled sin onClick
sudo sed -i 's|<button$$.$$className={"btn tab " \+ (view==="table" \? "active" : "")}$$.$$onClick={() => setView("table")}$$.*$$>Tabla</button>|<button\1className={"btn tab " + (view==="table" ? "active" : "")} disabled\3>Tabla</button>|' src/App.jsx

echo "== 3) Compilando =="
sudo npm run build

echo "== 4) Desplegando =="
sudo rsync -av --delete dist/ /var/www/uptime8081/dist/
sudo nginx -t && sudo systemctl reload nginx

echo "✓ Listo. En HOME pulsa Reproducir: abrirá la primera sede y luego avanzará sede→sede en loop, sin volver a HOME. La vista permanecerá en Grid."
