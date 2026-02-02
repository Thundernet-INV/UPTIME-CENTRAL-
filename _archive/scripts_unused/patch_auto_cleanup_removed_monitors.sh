#!/bin/sh
# Parche de AUTO-LIMPIEZA:
# - Elimina en frontend (UI + storage) monitores que ya no vienen en /api/summary
# - Sin tocar backend. Idempotente y seguro.
set -eu

APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
cd "$APP_DIR"

echo "== Backup y creación de carpetas =="
mkdir -p src/components src/lib
[ -f src/historyEngine.js ] && cp src/historyEngine.js src/historyEngine.js.bak.$(date +%Y%m%d%H%M%S) || true
[ -f src/App.jsx ] && cp src/App.jsx src/App.jsx.bak.$(date +%Y%m%d%H%M%S) || true

echo "== 1) Actualizando historyEngine.js con utilidades de purge =="
cat > src/historyEngine.js <<'JS'
// Simple history engine (localStorage) – snapshots de monitores + utilidades de limpieza
const KEY = "kuma_history_snapshots_v1";
const MAX = 500;
const SPARK_POINTS = 120;

function load(){ try { return JSON.parse(localStorage.getItem(KEY) || "[]"); } catch { return []; } }
function save(a){ try { localStorage.setItem(KEY, JSON.stringify(a)); } catch {} }
function now(){ return Date.now(); }

// === Núcleo estadístico ===
function avgLatencyForInstance(ms, instance) {
  const arr = ms.filter(m => m.instance === instance)
                .map(m => m.latest?.responseTime)
                .filter(v => typeof v === "number" && isFinite(v));
  if (!arr.length) return null;
  return Math.round(arr.reduce((a,b)=>a+b,0)/arr.length);
}
function downCountForInstance(ms, instance) {
  return ms.filter(m => m.instance === instance && m.latest?.status === 0).length;
}
function findMonitor(ms, instance, name) {
  const n = (name||'').toLowerCase().trim();
  return ms.find(m => m.instance===instance && (m.info?.monitor_name||'').toLowerCase().trim()===n);
}

const History = {
  addSnapshot(monitors) {
    const s = load(); s.push({ t: now(), monitors });
    while (s.length > MAX) s.shift();
    save(s);
  },

  // === Series para UI ===
  getAvgSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s){ xs.push(snap.t); ys.push(avgLatencyForInstance(snap.monitors, instance)); }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  getDownsSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s){ xs.push(snap.t); ys.push(downCountForInstance(snap.monitors, instance)); }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  getSeriesForMonitor(instance, monitorName, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s) {
      const m = findMonitor(snap.monitors, instance, monitorName);
      xs.push(snap.t);
      ys.push(typeof m?.latest?.responseTime === "number" ? m.latest.responseTime : null);
    }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  getAllForInstance(instance, maxPoints = MAX) {
    const lat = this.getAvgSeriesByInstance(instance, maxPoints);
    const dwn = this.getDownsSeriesByInstance(instance, maxPoints);
    return { lat, dwn };
  },

  // === AUTO-LIMPIEZA: purgar monitores ausentes ===
  /**
   * Purga snapshots históricos eliminando monitores cuyo (instance,name) ya no existe en "liveSet"
   * @param {Set<string>} liveSet - claves JSON.stringify({i,n}) de monitores vivos
   */
  purgeMissing(liveSet) {
    const s = load();
    const cleaned = s.map(snap => {
      const ms = (snap.monitors || []).filter(m => {
        const key = JSON.stringify({ i: m.instance, n: m.info?.monitor_name });
        return liveSet.has(key);
      });
      return { t: snap.t, monitors: ms };
    });
    save(cleaned);
  }
};

export default History;
JS

echo "== 2) Parcheando App.jsx para auto-limpieza en cada polling =="
# Reescribimos solo el bloque de polling para:
# - construir liveSet desde /api/summary
# - purgar históricos con History.purgeMissing(liveSet)
# - limpiar hiddenSet y blocklist local si contienen monitores inexistentes

awk '
  BEGIN{inPolling=0}
  {
    printLine=1;

    # Detectar inicio de efecto de polling (loop)
    if ($0 ~ /async function loop$$$$/) { inPolling=1 }

    if (inPolling && $0 ~ /setInstances$$instances$$; setMonitors$$monitors$$;/) {
      print $0;
      print "        // --- AUTO-LIMPIEZA: construir conjunto vivo (instance,name) ---";
      print "        const liveSet = new Set((monitors||[]).map(m => JSON.stringify({ i: m.instance, n: m.info?.monitor_name })) );";
      print "";
      print "        // 1) Purgar histórico para monitores ausentes";
      print "        try { History.purgeMissing(liveSet); } catch(e) { console.warn(\"purgeMissing() fallo\", e); }";
      print "";
      print "        // 2) Limpiar hiddenSet local (si contiene monitores ya inexistentes)";
      print "        try {";
      print "          setHidden(prev => {";
      print "            const next = new Set();";
      print "            for (const k of prev) { if (liveSet.has(k)) next.add(k); }";
      print "            // Persistir blocklist/hidden en backend/localStorage";
      print "            (async () => {";
      print "              const arr = [...next].map(k => { try { const o = JSON.parse(k); return { instance:o.i, name:o.n }; } catch { return null; } }).filter(Boolean);";
      print "              try { await saveBlocklist({ monitors: arr }); } catch { localStorage.setItem(\"blocklist\", JSON.stringify({monitors: arr})); }";
      print "            })();";
      print "            return next;";
      print "          });";
      print "        } catch(e) { console.warn(\"cleanup hiddenSet fallo\", e); }";
      print "";
      print "        // Nota: la lista visible usa filteredAll, que ya depende de monitors leidos del backend.";
      printLine=0;
    }

    printLine && print;
  }
' src/App.jsx > src/App.jsx.tmp && mv src/App.jsx.tmp src/App.jsx

echo "== 3) Hecho. Puedes compilar y desplegar como siempre =="
echo "   npm run build"
echo "   sudo rsync -av --delete dist/ /var/www/uptime8081/dist/"
echo "   sudo nginx -t && sudo systemctl reload nginx"
