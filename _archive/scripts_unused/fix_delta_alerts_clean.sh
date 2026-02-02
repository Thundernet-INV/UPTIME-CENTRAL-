#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$APP" ] && cp "$APP" "$APP.bak_$ts" || true

echo "== 1) Quitar posibles duplicados y restos previos =="

# 1.1 Eliminar TODAS las líneas previas de umbrales y reinsertar una sola vez
sed -i '/^\s*const\s\+DELTA_ALERT_MS\b/d' "$APP"
sed -i '/^\s*const\s\+DELTA_COOLDOWN_MS\b/d' "$APP"
# Insertar tras ALERT_AUTOCLOSE_MS
awk '
  BEGIN{done=0}
  {
    print
    if (!done && /const ALERT_AUTOCLOSE_MS\b/) {
      print "const DELTA_ALERT_MS = 100;           // umbral de variación (ms) por SERVICIO";
      print "const DELTA_COOLDOWN_MS = 60 * 1000;  // enfriamiento (ms) por SERVICIO";
      done=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 1.2 Asegurar import notify (sin duplicarlo)
sed -i '/from "\.\/utils\/notify\.js";/d' "$APP"
sed -i '1i import { notify } from "./utils/notify.js";' "$APP"

# 1.3 Asegurar refs (sin duplicar)
sed -i '/^\s*const\s\+lastRT\s*=\s*useRef(new Map())/d' "$APP"
sed -i '/^\s*const\s\+lastDeltaAt\s*=\s*useRef(new Map())/d' "$APP"
awk '
  BEGIN{done=0}
  {
    print
    if (!done && /const\s+lastStatus\s*=\s*useRef$$new Map\($$\);/) {
      print "  const lastRT = useRef(new Map());        // servicio -> último responseTime (ms)";
      print "  const lastDeltaAt = useRef(new Map());   // servicio -> último ts de alerta";
      done=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

# 1.4 Eliminar cualquier bloque viejo entre marcadores
awk '
  BEGIN{skip=0}
  {
    if ($0 ~ /\/\/ --- Delta de latencia/){ skip=1; next }
    if (skip && $0 ~ /\/\/ --- fin delta ---/){ skip=0; next }
    if (!skip) print
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 2) Insertar el bloque de detección POR SERVICIO con comillas bien escapadas =="

awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && /lastStatus\.current\s*=\s*next;/) {
      print "        // --- Delta de latencia (±100 ms) POR SERVICIO ---";
      print "        try {";
      print "          for (const m of monitors) {";
      print "            const key = keyFor(m.instance, m.info?.monitor_name);";
      print "            const rt = (typeof m.latest?.responseTime === \\"number\\") ? m.latest.responseTime : null;";
      print "            if (rt == null) continue;";
      print "            const prev = lastRT.current.get(key);";
      print "            if (typeof prev === \\"number\\") {";
      print "              const delta = rt - prev;";
      print "              if (Math.abs(delta) >= DELTA_ALERT_MS) {";
      print "                const now = Date.now();";
      print "                const last = lastDeltaAt.current.get(key) || 0;";
      print "                if (now - last >= DELTA_COOLDOWN_MS) {";
      print "                  const msg = `Variación ${delta>0?'+':''}${Math.round(delta)} ms en ${m.info?.monitor_name || ''} (${m.instance})`;";
      print "                  const id  = `delta:${key}:${now}`;";
      print "                  setAlerts(a => [...a, { id, instance:m.instance, name:m.info?.monitor_name, ts:now, msg }]);";
      print "                  try { notify('Alerta de variación', msg); } catch {}";
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

echo "== 3) Compilar y desplegar =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Reparado: sin duplicados, bloque por SERVICIO activo y notify escapado correctamente."
