#!/bin/sh
set -eu
APP="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP"

# 1) Backup
cp src/components/AutoPlayer.jsx src/components/AutoPlayer.jsx.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
cp src/components/AutoPlayControls.jsx src/components/AutoPlayControls.jsx.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
cp src/App.jsx src/App.jsx.bak.$(date +%Y%m%d%H%M%S)

# 2) Reescribir AutoPlayer con lógica: home->sede (espera N seg)->home->siguiente
cat > src/components/AutoPlayer.jsx <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer (v2):
 * - Si está en HOME y enabled -> abre siguiente sede tras intervalSec.
 * - Si está en SEDE y enabled -> vuelve a HOME tras viewSec y continúa.
 */
export default function AutoPlayer({
  enabled=false,
  intervalSec=10,
  viewSec=10,
  order="downFirst",
  onlyIncidents=false,
  loop=true,
  filteredAll=[],
  route,
  openInstance
}) {
  const idxRef = useRef(0);
  const timerRef = useRef(null);

  const instanceStats = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const it = map.get(m.instance) || { up:0, down:0, total:0 };
      if (m.latest?.status === 1) it.up++; else if (m.latest?.status === 0) it.down++;
      it.total++;
      map.set(m.instance, it);
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

  // Proteger índice si cambió el tamaño del playlist
  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  useEffect(() => {
    if (!enabled) { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; } return; }
    if (!playlist.length) return;

    // Limpieza previa
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; }

    if (route?.name === "home") {
      // En home → programar abrir siguiente sede
      const goNext = () => {
        if (!playlist.length) return;
        if (idxRef.current >= playlist.length) {
          if (!loop) return;
          idxRef.current = 0;
        }
        const name = playlist[idxRef.current++];
        openInstance?.(name);
      };
      timerRef.current = setTimeout(goNext, Math.max(3, intervalSec) * 1000);
    } else if (route?.name === "sede") {
      // En sede → programar volver a home para seguir
      const backHome = () => {
        // Volver al home
        window.location.hash = "";
      };
      timerRef.current = setTimeout(backHome, Math.max(3, viewSec) * 1000);
    }

    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current=null; } };
  }, [enabled, intervalSec, viewSec, playlist.length, route?.name, loop, openInstance]);

  return null;
}
JSX

# 3) Añadir control "Ver X s" en AutoPlayControls (si no existía)
awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && $0 ~ /Solo incidencias/) {
      print ""
      print "      <label style={{display:\"flex\",alignItems:\"center\",gap:6}}>"
      print "        Ver (sede) s"
      print "        <input type=\"number\" min=\"3\" step=\"1\" value={viewSec}"
      print "          onChange={(e)=>setViewSec(Math.max(3, parseInt(e.target.value||\"10\",10)))}"
      print "          style={{width:64, padding:\"4px 6px\"}}/>"
      print "      </label>"
      inserted=1
    }
  }
' src/components/AutoPlayControls.jsx > src/components/AutoPlayControls.jsx.tmp && mv src/components/AutoPlayControls.jsx.tmp src/components/AutoPlayControls.jsx

# 4) Asegurar estados y props en App.jsx
# 4.1 Estados
awk '
  BEGIN{done=0}
  {
    print
    if (!done && $0 ~ /^export default function App$$$$ \{$/) {
      print "  // Playlist (v2)"
      print "  const [autoRun, setAutoRun] = useState(false);"
      print "  const [autoIntervalSec, setAutoIntervalSec] = useState(10);"
      print "  const [autoOrder, setAutoOrder] = useState(\"downFirst\");"
      print "  const [autoOnlyIncidents, setAutoOnlyIncidents] = useState(false);"
      print "  const [autoLoop, setAutoLoop] = useState(true);"
      print "  const [autoViewSec, setAutoViewSec] = useState(10);"  # new
      done=1
    }
  }
' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx

# 4.2 Props en Controls (inyectar viewSec)
sed -i 's/loop={autoLoop} setLoop={setAutoLoop}/loop={autoLoop} setLoop={setAutoLoop}\n          viewSec={autoViewSec} setViewSec={setAutoViewSec}/' src/App.jsx || true

# 4.3 Props en AutoPlay (inyectar viewSec y sólo en un bloque)
if grep -q ' <AutoPlayer' src/App.jsx; then
  sed -i '0,/<AutoPlayer/s/enabled={autoRun}/enabled={autoRun}\n        viewSec={autoViewSec}/' src/App.jsx
fi

echo "OK. Compila con: npm run build"
