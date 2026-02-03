#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
APP="$ROOT/src/App.jsx"
API="$ROOT/src/api.js"
HIST="$ROOT/src/historyEngine.js"
HDB="$ROOT/src/historyDB.js"
CSS="$ROOT/src/styles.css"

ts=$(date +%Y%m%d_%H%M%S)
mkdir -p "$ROOT/src/components"
[ -f "$APP" ]  && cp "$APP"  "$APP.bak_$ts"  || true
[ -f "$API" ]  && cp "$API"  "$API.bak_$ts"  || true
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true
[ -f "$CSS" ]  || touch "$CSS"
cp "$CSS" "$CSS.bak_$ts"

echo "== 1) API sin caché: /api/summary?t=TS y headers no-store =="
if [ -f "$API" ]; then
  # Parche generoso: crea fetchAll si no existe; si existe, lo reescribe en forma segura
  cat > "$API" <<'JS'
export async function fetchAll() {
  const url = `/api/summary?t=${Date.now()}`;
  const res = await fetch(url, {
    cache: 'no-store',
    headers: {
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'Pragma': 'no-cache'
    }
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// (Opcional) blocklist endpoints – también sin caché
export async function getBlocklist() {
  const res = await fetch(`/api/blocklist?t=${Date.now()}`, { cache:'no-store', headers: {'Cache-Control':'no-store'} });
  if (!res.ok) return null;
  return res.json().catch(()=>null);
}
export async function saveBlocklist(payload) {
  const res = await fetch(`/api/blocklist`, {
    method:'POST',
    headers:{'Content-Type':'application/json','Cache-Control':'no-store'},
    body: JSON.stringify(payload)
  });
  return res.json().catch(()=>null);
}
JS
else
  echo "[WARN] src/api.js no existe – omito"
fi

echo "== 2) IndexedDB: almacenamiento 7 días (historyDB.js) =="
cat > "$HDB" <<'JS'
// historyDB.js: snapshots en IndexedDB con retención de 7 días
const DB_NAME = 'kuma_history_v2';
const STORE = 'snapshots';
const DB_VER = 1;

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VER);
    req.onupgradeneeded = (e) => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        const os = db.createObjectStore(STORE, { keyPath: 'id', autoIncrement: true });
        os.createIndex('by_ts', 'ts');
        os.createIndex('by_key', 'key'); // instance+name
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function addSnapshots(monitors, nowTs = Date.now()) {
  if (!Array.isArray(monitors) || !monitors.length) return;
  const db = await openDB();
  const tx = db.transaction(STORE, 'readwrite');
  const st = tx.objectStore(STORE);
  for (const m of monitors) {
    const rec = {
      ts: nowTs,
      instance: m.instance,
      name: m.info?.monitor_name || '',
      status: (m.latest?.status ?? null),
      responseTime: (m.latest?.responseTime ?? null),
      key: `${m.instance}::${m.info?.monitor_name || ''}`
    };
    st.add(rec);
  }
  await new Promise((res, rej) => { tx.oncomplete=res; tx.onerror=()=>rej(tx.error); });
  db.close();
}

async function pruneOlderThanDays(days=7) {
  const cutoff = Date.now() - days*24*3600*1000;
  const db = await openDB();
  const tx = db.transaction(STORE, 'readwrite');
  const st = tx.objectStore(STORE);
  const idx = st.index('by_ts');
  const req = idx.openCursor();
  await new Promise((resolve, reject) => {
    req.onsuccess = () => {
      const cur = req.result;
      if (!cur) return resolve();
      if (cur.value.ts < cutoff) {
        st.delete(cur.primaryKey);
        cur.continue();
      } else {
        resolve();
      }
    };
    req.onerror = () => reject(req.error);
  });
  await new Promise((res, rej) => { tx.oncomplete=res; tx.onerror=()=>rej(tx.error); });
  db.close();
}

// Lectura simple (últimos N ms) – utilizable para sparkline si quieres
async function getSeriesFor(key, sinceMs) {
  const since = Date.now() - sinceMs;
  const out = [];
  const db = await openDB();
  const tx = db.transaction(STORE, 'readonly');
  const st = tx.objectStore(STORE);
  const idx = st.index('by_key');
  const range = IDBKeyRange.only(key);
  const req = idx.openCursor(range);
  await new Promise((resolve, reject) => {
    req.onsuccess = () => {
      const cur = req.result;
      if (!cur) return resolve();
      if (cur.value.ts >= since) out.push(cur.value);
      cur.continue();
    };
    req.onerror = () => reject(req.error);
  });
  db.close();
  return out;
}

export default {
  addSnapshots,
  pruneOlderThanDays,
  getSeriesFor,
};
JS

echo "== 3) historyEngine usa IndexedDB (retención 7 días) =="
cat > "$HIST" <<'JS'
import DB from './historyDB';

// API compatible con tu código existente
const History = {
  addSnapshot(monitors) {
    // persiste y poda (7 días)
    DB.addSnapshots(monitors).catch(()=>{});
    DB.pruneOlderThanDays(7).catch(()=>{});
  },
  // utilitario por si luego quieres graficar 24h/7d
  getSeries(instance, name, days=7) {
    const key = `${instance}::${name||''}`;
    return DB.getSeriesFor(key, days*24*3600*1000);
  }
};

export default History;
JS

echo "== 4) App.jsx: limpieza de caché por versión de build al cargar =="
# Insertamos un pequeño efecto para “cache bust” (localStorage legacy + poda IDB)
if ! grep -q 'BUILD_VERSION' "$APP"; then
  # pegamos un bloque justo después de imports (línea tras AlertsBanner import)
  awk '
    BEGIN{done=0}
    {
      print
      if (!done && /import AlertsBanner/) {
        print "";
        print "const BUILD_VERSION = \"2026-01-28-1\"; // cambia cuando hagas despliegue";
        done=1
      }
    }
  ' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"
fi

# Efecto de limpieza si cambió BUILD_VERSION
grep -q 'cache clean by build version' "$APP" || awk '
  BEGIN{inserted=0}
  {
    print
    if (!inserted && /export default function App$$$$/) {
      print "  // cache clean by build version";
      print "  useEffect(() => {";
      print "    try {";
      print "      const k = \"ui_build_version\";";
      print "      const last = localStorage.getItem(k);";
      print "      if (last !== BUILD_VERSION) {";
      print "        // quita restos legacy (si los hubiera)";
      print "        localStorage.removeItem(\"kuma_history_snapshots_v1\");";
      print "        localStorage.setItem(k, BUILD_VERSION);";
      print "      }";
      print "    } catch {}";
      print "  }, []);";
      inserted=1
    }
  }
' "$APP" > "$APP.tmp" && mv "$APP.tmp" "$APP"

echo "== 5) Build & Deploy =="
cd "$ROOT"
npm run build
sudo rsync -av --delete dist/ /var/www/uptime8081/dist/
sudo nginx -t && sudo systemctl reload nginx

echo "✓ Listo: fetch fresco, snapshots 7d en IndexedDB, auto-clean de caché."
