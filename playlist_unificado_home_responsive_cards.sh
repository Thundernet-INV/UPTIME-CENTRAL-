#!/bin/sh
set -eu

APPROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$APPROOT/src/App.jsx"
CTRL="$APPROOT/src/components/AutoPlayControls.jsx"
AUTOP="$APPROOT/src/components/AutoPlayer.jsx"
CSS="$APPROOT/src/styles.css"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p "$APPROOT/src/components"
[ -f "$APP" ]   && cp "$APP"   "$APP.bak_$ts"   || true
[ -f "$CTRL" ]  && cp "$CTRL"  "$CTRL.bak_$ts"  || true
[ -f "$AUTOP" ] && cp "$AUTOP" "$AUTOP.bak_$ts" || true
[ -f "$CSS" ]   || touch "$CSS"
cp "$CSS" "$CSS.bak_$ts"

echo "== 1) Reescribiendo AutoPlayControls: 1 sola casilla 'Tiempo (s)' =="
cat > "$CTRL" <<'JSX'
import React from "react";

export default function AutoPlayControls({
  running=false, onToggle=()=>{},
  sec=10, setSec=()=>{},
  order="downFirst", setOrder=()=>{},
  onlyIncidents=false, setOnlyIncidents=()=>{},
  loop=true, setLoop=()=>{}
}) {
  return (
    <div className="autoplay-controls" style={{
      display:"flex", gap:8, alignItems:"center", flexWrap:"wrap",
      border:"1px solid #e5e7eb", padding:"8px 10px", borderRadius:8, background:"#fff"
    }}>
      <button
        type="button"
        className="k-btn"
        style={{borderColor: running ? "#dc2626" : "#16a34a", color: running ? "#dc2626" : "#16a34a"}}
        onClick={onToggle}
        title={running ? "Pausar rotación" : "Iniciar rotación"}
      >
        {running ? "⏸️ Pausar" : "▶️ Reproducir"}
      </button>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Tiempo (s)
        <input
          type="number" min="1" step="1" value={sec}
          onChange={(e)=> {
            const v = parseInt(e.target.value || "10", 10);
            setSec(Number.isFinite(v) ? Math.max(1, v) : 10);
          }}
          style={{width:72, padding:"4px 6px"}}
        />
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        Orden
        <select value={order} onChange={(e)=>setOrder(e.target.value)} style={{padding:"4px 6px"}}>
          <option value="downFirst">DOWN primero</option>
          <option value="alpha">Alfabético</option>
        </select>
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        <input type="checkbox" checked={onlyIncidents} onChange={(e)=>setOnlyIncidents(e.target.checked)}/>
        Solo incidencias
      </label>

      <label style={{display:"flex",alignItems:"center",gap:6}}>
        <input type="checkbox" checked={loop} onChange={(e)=>setLoop(e.target.checked)}/>
        Loop
      </label>

      <span style={{marginLeft:"auto", color:"#6b7280"}}>Playlist de instancias</span>
    </div>
  );
}
JSX

echo "== 2) Reescribiendo AutoPlayer: usa un solo tiempo 'sec' y respeta >5s; sede→sede sin Home =="
cat > "$AUTOP" <<'JSX'
import React, { useEffect, useMemo, useRef } from "react";

/**
 * AutoPlayer v6
 * - Un solo parámetro de tiempo: sec (segundos).
 * - HOME: inicia en ~300ms para no esperar la primera vez.
 * - SEDE: tras sec segundos, salta directamente a la siguiente SEDE (loop), sin volver a HOME.
 * - Respeta cualquier valor de sec (mínimo 1s).
 */
export default function AutoPlayer({
  enabled=false,
  sec=10,
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

  useEffect(() => { if (idxRef.current >= playlist.length) idxRef.current = 0; }, [playlist.length]);

  // Exponer debug (opcional)
  useEffect(() => {
    if (typeof window !== "undefined") {
      window.__apDebug = {
        enabled, route: route?.name, count: playlist.length,
        next: playlist.length ? playlist[idxRef.current % playlist.length] : null,
        sec, onlyIncidents, order, loop
      };
    }
  }, [enabled, route?.name, playlist.length, sec, onlyIncidents, order, loop]);

  useEffect(() => {
    if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; }
    if (!enabled || !playlist.length) return;

    const SEC = Math.max(1, Number(sec) || 10);
    const goByHash = (name) => { window.location.hash = "/sede/" + encodeURIComponent(name); };

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
      // Primer salto muy rápido (300ms) para arrancar la rotación
      timerRef.current = setTimeout(() => gotoNextFrom(null), 300);
    } else if (route?.name === "sede") {
      // Permanecer en la sede 'SEC' segundos y saltar a la próxima sede
      timerRef.current = setTimeout(() => gotoNextFrom(route.instance), SEC * 1000);
    }

    return () => { if (timerRef.current) { clearTimeout(timerRef.current); timerRef.current = null; } };
  }, [enabled, sec, route?.name, route?.instance, playlist.length, loop, openInstance]);

  return null;
}
JSX

echo "== 3) Parches en App.jsx: nuevo estado 'autoSec', actualizar props, botón Home en header =="
# 3.1 Eliminar líneas con autoIntervalSec/autoViewSec si existen
sed -i '/autoIntervalSec/d' "$APP" || true
sed -i '/autoViewSec/d'      "$APP" || true

# 3.2 Asegurar estado autoSec tras la línea de autoRun
grep -q 'const $$autoSec, setAutoSec$$' "$APP" || \
  sed -i '0,/const $$autoRun, setAutoRun$$/s//&\nconst [autoSec, setAutoSec] = useState(10);/' "$APP"

# 3.3 Reemplazar el bloque <AutoPlayControls .../> por versión con 'sec'
awk '
  BEGIN{inBlock=0}
  {
    if ($0 ~ /<AutoPlayControls[[:space:]]*$/ || $0 ~ /<AutoPlayControls[[:space:]]+/) {
      inBlock=1
      print "        <AutoPlayControls"
      print "          running={autoRun}"
      print "          onToggle={()=>setAutoRun(v=>!v)}"
      print "          sec={autoSec} setSec={setAutoSec}"
      print "          order={autoOrder} setOrder={setAutoOrder}"
      print "          onlyIncidents={autoOnlyIncidents} setOnlyIncidents={setAutoOnlyIncidents}"
      print "          loop={autoLoop} setLoop={setAutoLoop}"
      print "        />"
      next
    }
    if (inBlock) {
      if ($0 ~ /\/>/) { inBlock=0 } # consumir hasta cierre anterior
      next
    }
    print
  }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.4 Reemplazar el bloque <AutoPlayer .../> por versión con 'sec'
awk '
  BEGIN{inBlock=0}
  {
    if ($0 ~ /<AutoPlayer[[:space:]]*$/ || $0 ~ /<AutoPlayer[[:space:]]+/) {
      inBlock=1
      print "        {/* AUTOPLAY ENGINE */}"
      print "        <AutoPlayer"
      print "          enabled={autoRun}"
      print "          sec={autoSec}"
      print "          order={autoOrder}"
      print "          onlyIncidents={autoOnlyIncidents}"
      print "          loop={autoLoop}"
      print "          filteredAll={filteredAll}"
      print "          route={route}"
      print "          openInstance={openInstance}"
      print "        />"
      next
    }
    if (inBlock) {
      if ($0 ~ /\/>/) { inBlock=0 }
      next
    }
    print
  }' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.5 Botón Home al lado del título (si no existe)
grep -q 'className="home-btn"' "$APP" || \
  sed -i 's~<h1>Uptime Central</h1><div style={{display:"flex",alignItems:"center",gap:12,flexWrap:"wrap"}}>\n  <h1 style={{margin:0}}>Uptime Central</h1>\n  <button className="home-btn" type="button" onClick={()=>{window.location.hash="";}} title="Ir al inicio">Home</button>\n</div>' "$APP"

echo "== 4) CSS responsive + tarjetas sin desbordes + botón Home =="
cat >> "$CSS" <<'CSS'

/* ====== Copilot UI patch: Responsive + Cards + Home button ====== */

/* Contenedor global (si existe .container) */
.container { max-width: 1600px; margin: 0 auto; padding: 12px; }

/* Título + botón Home */
.home-btn {
  border: 1px solid #e5e7eb; border-radius: 8px; padding: 6px 10px;
  background: #fff; color: #111827; cursor: pointer;
}
.home-btn:hover { background:#f3f4f6; }

/* Grid responsivo */
.cards-grid, .services-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 14px;
}

/* Tarjeta base */
.card, .monitor-card, .service-card {
  display: flex; flex-direction: column; gap: 10px;
  background: #fff; border:1px solid #e5e7eb; border-radius:12px;
  padding: 12px; min-width: 0; box-sizing: border-box;
}

/* Header de tarjeta */
.card > *:first-child, .monitor-card > *:first-child, .service-card > *:first-child,
.card-head, .monitor-card_head, .service-card_head {
  position: relative; display:flex; align-items:center; gap:10px; min-width:0;
}

/* Logo */
.card img, .monitor-card img, .service-card img,
.card-logo, .monitor-card_logo, .service-card_logo {
  flex:0 0 auto; width:22px; height:22px; border-radius:6px; object-fit:contain;
}

/* Bloque de textos (reserva sitio al badge) */
.card > *:first-child > :nth-child(2),
.monitor-card > *:first-child > :nth-child(2),
.service-card > *:first-child > :nth-child(2),
.card-head_texts, .monitor-cardtexts, .service-card_texts {
  display:flex; flex-direction:column; min-width:0; overflow:hidden;
  padding-right: 84px;
}

/* Título: 2 líneas + quiebre de palabras largas */
.card > *:first-child > :nth-child(2) > :first-child,
.monitor-card > *:first-child > :nth-child(2) > :first-child,
.service-card > *:first-child > :nth-child(2) > :first-child,
.card-title, .monitor-card_title, .service-card_title {
  color:#111827; font-weight:600; min-width:0; overflow:hidden;
  display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical;
  text-overflow:ellipsis; white-space:normal; line-height:1.2; font-size:15px;
  overflow-wrap:anywhere; word-break:break-word;
  max-height: calc(1.2em * 2);
}

/* Subtítulo: 1 línea con elipsis */
.card > *:first-child > :nth-child(2) > :nth-child(2),
.monitor-card > *:first-child > :nth-child(2) > :nth-child(2),
.service-card > *:first-child > :nth-child(2) > :nth-child(2),
.card-subtitle, .monitor-card_subtitle, .service-card_subtitle {
  color:#6b7280; font-size:12.5px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0;
}

/* Badge en absoluto (no empuja el texto) */
.card > *:first-child .badge, .monitor-card > *:first-child .badge, .service-card > *:first-child .badge,
.status-badge, .monitor-card_badge, .service-card_badge {
  position:absolute; top:8px; right:10px;
  max-width:72px; padding:2px 8px; border-radius:9999px;
  font-size:11px; font-weight:700; line-height:1.6; text-align:center;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
}
.badge--up  { background:#e8f8ef !important; color:#0e9f6e !important; }
.badge--down{ background:#fde8e8 !important; color:#d93025 !important; }

/* Pie de tarjeta y sparkline */
.card-foot, .monitor-card_foot, .service-card_foot { display:flex; align-items:center; gap:10px; min-width:0; }
.sparkline, .monitor-card_sparkline, .service-card_sparkline { min-width:0; width:100%; height:44px; }

/* Autoplay controls caja */
.autoplay-controls .k-btn { border-color:#cbd5e1; color:#334155; background:#fff; }
.autoplay-controls input, .autoplay-controls select {
  border:1px solid #e5e7eb; border-radius:6px; background:#fff; color:#111827;
}

/* Breakpoints para pantallas grandes/pequeñas */
@media (min-width: 1800px) {
  .container { max-width: 1920px; }
  .cards-grid, .services-grid { grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
}
@media (max-width: 480px) {
  .cards-grid, .services-grid { grid-template-columns: 1fr; }
  .card > *:first-child .badge, .status-badge, .monitor-card_badge, .service-card_badge { top:6px; right:8px; max-width:64px; font-size:10.5px; }
  .card > *:first-child > :nth-child(2), .card-head_texts, .monitor-cardtexts, .service-card_texts { padding-right:72px; }
}

/* ====== /Copilot UI patch ====== */
CSS

echo "== 5) Compilando =="
cd "$APPROOT"
npm run build

echo "== 6) Desplegando =="
rsync -av --delete "$APPROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Todo listo: 1 tiempo de playlist, botón Home, UI responsive y tarjetas sin desbordes."
