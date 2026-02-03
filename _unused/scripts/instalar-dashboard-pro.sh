
#!/usr/bin/env bash
set -e

echo "[INFO] Instalando Dashboard PRO…"

# Limpia componentes antiguos
rm -rf src/components
mkdir -p src/components

# ========== index.html ==========
cat > index.html <<'EOF'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <title>Uptime Central</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  </head>
  <body>
    <div id="root"></div>
    /src/main.jsx</script>
  </body>
</html>
EOF

# ========== main.jsx ==========
cat > src/main.jsx <<'EOF'
import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# ========== api.js ==========
cat > src/api.js <<'EOF'
const API = "/";

export async function fetchSummary() {
  return (await fetch(API + "api/summary")).json();
}

export async function fetchMonitors() {
  return (await fetch(API + "api/monitors")).json();
}

export function openStream(onMessage) {
  const es = new EventSource(API + "api/stream");
  es.addEventListener("tick", e => onMessage(JSON.parse(e.data)));
  return () => es.close();
}

export async function getBlocklist() {
  return (await fetch(API + "api/blocklist")).json();
}

export async function saveBlocklist(b) {
  return await fetch(API + "api/blocklist", {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(b)
  });
}
EOF

# ========== Components ==========
# (Sparkline, Cards, Filters, ServiceGrid, ServiceCard, MonitorCard, InstanceDetail, MonitorsTable)

# (Para mantenerlo limpio, te lo envío en siguiente mensaje si esto funciona)

echo "[INFO] Instalando componentes…"

# ========== App.jsx ==========
cat > src/App.jsx <<'EOF'
import { useEffect, useMemo, useState } from "react";
import { fetchSummary, fetchMonitors, openStream, getBlocklist, saveBlocklist } from "./api";
import ServiceGrid from "./components/ServiceGrid";
import InstanceDetail from "./components/InstanceDetail";
import MonitorsTable from "./components/MonitorsTable";
import Filters from "./components/Filters";
import Cards from "./components/Cards";

function getRoute() {
  const h = window.location.hash.slice(1);
  const p = h.split("/").filter(Boolean);
  if (p[0] === "sede" && p[1]) return { name: "sede", instance: decodeURIComponent(p[1]) };
  return { name: "home" };
}

export default function App() {
  const [summary, setSummary] = useState({});
  const [monitors, setMonitors] = useState([]);
  const [filters, setFilters] = useState({ instance:"", type:"", q:"", onlyDown:false });
  const [hidden, setHidden] = useState(new Set());
  const [view, setView] = useState("grid");
  const [route, setRoute] = useState(getRoute());

  useEffect(() => {
    window.addEventListener("hashchange", () => setRoute(getRoute()));
  }, []);

  useEffect(() => {
    (async () => {
      setSummary(await fetchSummary());
      setMonitors(await fetchMonitors());
      const bl = await getBlocklist();
      setHidden(new Set(bl.monitors?.map(k => `${k.instance}|${k.name}`) || []));
    })();

    const close = openStream(p => {
      setMonitors(p.monitors);
      const up = p.monitors.filter(m => m.latest?.status === 1).length;
      const down = p.monitors.filter(m => m.latest?.status === 0).length;
      const arr = p.monitors.map(m => m.latest?.responseTime).filter(Boolean);
      const avg = arr.length ? Math.round(arr.reduce((a,b)=>a+b,0)/arr.length) : null;
      setSummary({ up, down, total:p.monitors.length, avgResponseTimeMs:avg });
    });

    return close;
  }, []);

  const filteredAll = useMemo(() =>
    monitors.filter(m => {
      if (filters.instance && m.instance !== filters.instance) return false;
      if (filters.type && m.info.monitor_type !== filters.type) return false;
      if (filters.onlyDown && m.latest?.status !== 0) return false;
      if (filters.q && !(
         `${m.info.monitor_name} ${m.info.monitor_url} ${m.info.monitor_hostname}`
         .toLowerCase()
         .includes(filters.q.toLowerCase())
      )) return false;
      return true;
    }),
    [monitors, filters]
  );

  const visible = filteredAll.filter(m => !hidden.has(`${m.instance}|${m.info.monitor_name}`));

  const persistHidden = async newSet => {
    const arr = [...newSet].map(k => { const [instance, name] = k.split("|"); return { instance, name }; });
    await saveBlocklist({ monitors: arr });
    setHidden(newSet);
  };

  const onHide = (i,n) => persistHidden(new Set([...hidden, `${i}|${n}`]));
  const onUnhide = (i,n) => { const s=new Set(hidden); s.delete(`${i}|${n}`); persistHidden(s); };
  const onHideAll = (instance) => {
    const s=new Set(hidden);
    filteredAll.filter(m => m.instance===instance)
      .forEach(m => s.add(`${m.instance}|${m.info.monitor_name}`));
    persistHidden(s);
  };
  const onUnhideAll = async (instance) => {
    const bl = await getBlocklist();
    const next = bl.monitors.filter(k => k.instance !== instance);
    await saveBlocklist({ monitors: next });
    setHidden(new Set(next.map(k => `${k.instance}|${k.name}`)));
  };

  if (route.name === "sede") {
    return (
      <InstanceDetail
        instanceName={route.instance}
        monitorsAll={filteredAll}
        hiddenSet={hidden}
        onHide={onHide}
        onUnhide={onUnhide}
        onHideAll={onHideAll}
        onUnhideAll={onUnhideAll}
      />
    );
  }

  return (
    <div style={{ padding:20 }}>
      <h1>Uptime Central</h1>
      <Cards summary={summary} />
      <Filters monitors={monitors} value={filters} onChange={setFilters} />
      <button onClick={()=>setView("grid")}>Grid</button>
      <button onClick={()=>setView("table")}>Tabla</button>

      {view === "grid" ? (
        <ServiceGrid
          monitorsAll={filteredAll}
          hiddenSet={hidden}
          onHideAll={onHideAll}
          onUnhideAll={onUnhideAll}
          onOpen={(s)=>window.location.hash = "/sede/"+encodeURIComponent(s)}
        />
      ) : (
        <MonitorsTable
          monitors={visible}
          hiddenSet={hidden}
          onHide={onHide}
          onUnhide={onUnhide}
        />
      )}
    </div>
  );
}
EOF

echo "[INFO] Componentes listos."
echo "[INFO] Ejecuta ahora:"
echo "  chmod +x instalar-dashboard-pro.sh"
echo "  ./instalar-dashboard-pro.sh"
echo "Luego: npm run build && copiar a /var/www/kuma-dashboard/"

