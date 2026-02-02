#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"

echo "== Backup =="
cp "$APP" "$APP.bak_avg5_$(date +%Y%m%d_%H%M%S)"

echo "== 1) Asegurar constante de ventana (DELTA_WINDOW=5) junto a los umbrales =="
# Quita duplicados previos y crea una sola
sed -i '/^\s*const\s\+DELTA_WINDOW\s*=\s*/d' "$APP"
# Inserta después de DELTA_COOLDOWN_MS si existe; si no, después de DELTA_ALERT_MS.
if grep -q 'const DELTA_COOLDOWN_MS' "$APP"; then
  awk '
    BEGIN{done=0}
    {
      print
      if(!done && /const DELTA_COOLDOWN_MS/){
        print "const DELTA_WINDOW = 5;            // nº de valores para el promedio (por servicio)";
        done=1
      }
    }
  ' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
elif grep -q 'const DELTA_ALERT_MS' "$APP"; then
  awk '
    BEGIN{done=0}
    {
      print
      if(!done && /const DELTA_ALERT_MS/){
        print "const DELTA_WINDOW = 5;            // nº de valores para el promedio (por servicio)";
        done=1
      }
    }
  ' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
fi

echo "== 2) Asegurar buffer por servicio: lastRtHistory (Map) =="
# Inserta el ref tras lastDeltaAt (una sola vez)
sed -i '/^\s*const\s\+lastRtHistory\s*=\s*useRef/d' "$APP"
awk '
  BEGIN{done=0}
  {
    print
    if(!done && /const\s+lastDeltaAt\s*=\s*useRef$$new Map\($$\);/){
      print "  const lastRtHistory = useRef(new Map()); // servicio -> array de últimos RT (ms)";
      done=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 3) Eliminar bloque previo de variación (si existe) =="
# Borra cualquier bloque antiguo con nuestros marcadores
sed -i '/\/\/ --- Variación de latencia/,/\/\/ --- fin variación ---/d' "$APP"
sed -i '/\/\/ --- Variación vs promedio/,/\/\/ --- fin variación ---/d' "$APP"

echo "== 4) Insertar nueva lógica: comparación vs promedio de los últimos N (N=5) =="
awk '
  BEGIN{inserted=0}
  {
    print
    if(!inserted && /lastStatus\.current\s*=\s*next;/){
      print "        // --- Variación vs promedio últimos N (por servicio) ---";
      print "        try {";
      print "          const N = DELTA_WINDOW;";
      print "          for (const m of monitors) {";
      print "            const key = keyFor(m.instance, m.info?.monitor_name);";
      print "            const rt = (typeof m.latest?.responseTime === \"number\") ? m.latest.responseTime : null;";
      print "            if (rt == null) continue;";
      print "            // historial previo (sin incluir el actual)";
      print "            const hist = lastRtHistory.current.get(key) || [];";
      print "            const baseArr = hist.slice(-N);";
      print "            if (baseArr.length === N) {";
      print "              const avg = Math.round(baseArr.reduce((a,b)=>a+b,0) / N);";
      print "              const delta = rt - avg;";
      print "              if (Math.abs(delta) >= DELTA_ALERT_MS) {";
      print "                const now = Date.now();";
      print "                const last = lastDeltaAt.current.get(key) || 0;";
      print "                if (now - last >= DELTA_COOLDOWN_MS) {";
      print "                  const msg = `Variación ${delta>0?'+':''}${Math.round(delta)} ms vs prom ${avg} ms en ${m.info?.monitor_name || ''} (${m.instance})`;";
      print "                  const id  = `delta:${key}:${now}`;";
      print "                  setAlerts(a => [...a, { id, instance:m.instance, name:m.info?.monitor_name, ts:now, msg }]);";
      print "                  try { notify(\"Alerta de variación\", msg); } catch {}";
      print "                  lastDeltaAt.current.set(key, now);";
      print "                }";
      print "              }";
      print "            }";
      print "            // actualizar historial con el valor actual";
      print "            hist.push(rt);";
      print "            if (hist.length > N) hist.shift();";
      print "            lastRtHistory.current.set(key, hist);";
      print "            lastRT.current.set(key, rt);";
      print "          }";
      print "        } catch {}";
      print "        // --- fin variación ---";
      inserted=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 5) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete dist/ /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Activado: alertas por |rt - promedio(últimos 5)| ≥ DELTA_ALERT_MS (cooldown por servicio)."
