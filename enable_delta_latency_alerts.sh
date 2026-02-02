#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
ALB="$ROOT/src/components/AlertsBanner.jsx"
UTIL="$ROOT/src/utils/notify.js"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p "$ROOT/src/utils"
[ -f "$APP" ] && cp "$APP" "$APP.bak_$ts" || true
[ -f "$ALB" ] && cp "$ALB" "$ALB.bak_$ts" || true

echo "== 1) Utilidad de notificaciones (browser + beep fallback) =="
cat > "$UTIL" <<'JS'
export function notify(title, body) {
  try {
    if (typeof window === 'undefined') return;
    if ('Notification' in window) {
      if (Notification.permission === 'granted') {
        new Notification(title, { body });
      } else if (Notification.permission !== 'denied') {
        Notification.requestPermission().then(p => {
          if (p === 'granted') new Notification(title, { body });
          else beep();
        }).catch(beep);
      } else {
        beep();
      }
    } else {
      beep();
    }
  } catch {
    try { beep(); } catch {}
  }
}

function beep() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = 'sine';
    o.frequency.value = 880;
    o.connect(g); g.connect(ctx.destination);
    g.gain.setValueAtTime(0.0001, ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.2, ctx.currentTime + 0.01);
    o.start();
    setTimeout(() => { o.stop(); ctx.close(); }, 250);
  } catch {}
}
JS

echo "== 2) AlertsBanner tolerante a 'msg' (si ya lo tienes, lo reemplazamos por uno compatible) =="
cat > "$ALB" <<'JSX'
import React, { useEffect } from "react";

export default function AlertsBanner({ alerts=[], onClose=()=>{}, autoCloseMs=10000 }) {
  useEffect(() => {
    const timers = alerts.map(a => setTimeout(() => onClose(a.id), autoCloseMs));
    return () => timers.forEach(t => clearTimeout(t));
  }, [alerts, autoCloseMs, onClose]);

  if (!alerts.length) return null;

  return (
    <div style={{
      position:"sticky", top:8, zIndex:20, display:"flex", flexWrap:"wrap", gap:8,
      background:"transparent", padding:0, marginBottom:8
    }}>
      {alerts.slice(-6).map((a,i) => (
        <div key={a.id || i} style={{
          background:"#111827", color:"#fff", padding:"6px 10px", borderRadius:8,
          boxShadow:"0 2px 6px rgba(0,0,0,.15)", display:"flex", alignItems:"center", gap:8
        }}>
          <strong>Alerta</strong>
          <span>
            {/* Si viene mensaje específico, úsalo; de lo contrario, genérico */}
            {a.msg
              ? a.msg
              : `Evento en ${a.name || 'servicio'} (${a.instance || ''})`}
          </span>
          <button
            type="button"
            onClick={()=>onClose(a.id)}
            style={{ marginLeft:8, border:"1px solid #374151", background:"transparent", color:"#fff",
                     borderRadius:6, padding:"2px 6px", cursor:"pointer" }}
          >
            Cerrar
          </button>
        </div>
      ))}
    </div>
  );
}
JSX

echo "== 3) Inyectando lógica de variación en App.jsx (±100ms + cooldown) =="

# 3.1 Import util notify
grep -q 'from "./utils/notify.js"' "$APP" || sed -i '1i import { notify } from "./utils/notify.js";' "$APP"

# 3.2 Constantes de umbral y cooldown debajo de ALERT_AUTOCLOSE_MS
awk '
  BEGIN{done=0}
  {
    print
    if (!done && /const ALERT_AUTOCLOSE_MS/) {
      print "const DELTA_ALERT_MS = 100;           // umbral de variación en ms";
      print "const DELTA_COOLDOWN_MS = 60 * 1000;  // no alertar más de 1/min por monitor (ajustable)";
      done=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.3 Refs para último responseTime y último aviso
awk '
  BEGIN{done=0}
  {
    print
    if (!done && /const lastStatus = useRef$$new Map\($$\);/) {
      print "  const lastRT = useRef(new Map());        // key -> last responseTime (ms)";
      print "  const lastDeltaAt = useRef(new Map());   // key -> last alert ts";
      done=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.4 Efecto de siembra inicial de lastRT (no rompe nada)
grep -q '/* seed lastRT */' "$APP" || awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && /useEffect$$\($$ => \{\s*const m = new Map$$$$;/) {
      print "  /* seed lastRT */";
      print "  useEffect(() => {";
      print "    const r = new Map();";
      print "    for (const x of monitors) {";
      print "      const k = keyFor(x.instance, x.info?.monitor_name);";
      print "      const rt = (typeof x.latest?.responseTime === \"number\") ? x.latest.responseTime : null;";
      print "      if (rt != null) r.set(k, rt);";
      print "    }";
      print "    lastRT.current = r;";
      print "  }, []);";
      inserted=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 3.5 Detección de variación dentro del loop de polling: insertamos justo después de 'lastStatus.current = next;'
awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && /lastStatus\.current = next;/) {
      print "        // --- Delta de latencia (±100 ms) ---";
      print "        try {";
      print "          for (const m of monitors) {";
      print "            const key = keyFor(m.instance, m.info?.monitor_name);";
      print "            const rt = (typeof m.latest?.responseTime === \"number\") ? m.latest.responseTime : null;";
      print "            if (rt == null) continue;";
      print "            const prev = lastRT.current.get(key);";
      print "            if (typeof prev === \"number\") {";
      print "              const delta = rt - prev;";
      print "              if (Math.abs(delta) >= DELTA_ALERT_MS) {";
      print "                const now = Date.now();";
      print "                const last = lastDeltaAt.current.get(key) || 0;";
      print "                if (now - last >= DELTA_COOLDOWN_MS) {";
      print "                  const msg = `Variación ${delta>0?'+':''}${Math.round(delta)} ms en ${m.info?.monitor_name || ''} (${m.instance})`;";
      print "                  const id  = `delta:${key}:${now}`;";
      print "                  setAlerts(a => [...a, { id, instance:m.instance, name:m.info?.monitor_name, ts:now, msg }]);";
      print "                  notify('Alerta de variación', msg);";
      print "                  lastDeltaAt.current.set(key, now);";
      print "                }";
      print "              }";
      print "            }";
      print "            lastRT.current.set(key, rt);";
      print "          }";
      print "        } catch {}";
      print "        // --- fin delta ---";
      inserted=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 4) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Listo: alertas por variación (>100ms) en pantalla + notificación (con cooldown)."
