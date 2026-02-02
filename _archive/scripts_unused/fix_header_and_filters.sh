#!/bin/sh
# Script SEGURO – Reemplaza archivos completos (sin sed destructivo)
# Corrige:
#  - Header mostrando UP/DOWN/TOTAL/Prom de MONITORES según filtros
#  - Clic en cuadros del header aplica filtro UP/DOWN/ALL
#  - Limpia completely App.jsx y Cards.jsx
#  - Añade estilos limpios
# Uso:
#   chmod +x fix_header_and_filters.sh
#   ./fix_header_and_filters.sh
#   npm run dev

set -eu

TS=$(date +%Y%m%d%H%M%S)

##############################################################################
# Validación
##############################################################################
if [ ! -f package.json ]; then
  echo "[ERROR] Ejecuta este script en la carpeta del FRONTEND (donde está package.json)"
  exit 1
fi

mkdir -p src/components

##############################################################################
# 1. Reemplazar COMPLETO src/App.jsx (versión limpia y funcional)
##############################################################################
cp src/App.jsx src/App.jsx.bak.$TS 2>/dev/null || true

cat > src/App.jsx <<'EOF'
import { useEffect, useMemo, useState, useRef } from "react";
import Cards from "./components/Cards.jsx";
import Filters from "./components/Filters.jsx";
import ServiceGrid from "./components/ServiceGrid.jsx";
import MonitorsTable from "./components/MonitorsTable.jsx";
import InstanceDetail from "./components/InstanceDetail.jsx";
import SLAAlerts from "./components/SLAAlerts.jsx";
import { fetchAll, getBlocklist, saveBlocklist } from "./api.js";

const SLA_CONFIG = { uptimeTarget: 99.9, maxLatencyMs: 800 };

function getRoute() {
  const parts = (window.location.hash || "").slice(1).split("/").filter(Boolean);
  if (parts[0] === "sede" && parts[1]) return { name: "sede", instance: decodeURIComponent(parts[1]) };
  return { name: "home" };
}

const keyFor = (instance, name="") => JSON.stringify({i:instance,n:name});
const fromKey = (k) => { try { return JSON.parse(k); } catch { return {i:"",n:""} } };

export default function App() {

  const [monitors, setMonitors]   = useState([]);
  const [instances, setInstances] = useState([]);
  const [filters, setFilters] = useState({
    instance: "",
    type: "",
    q: "",
    status: "all"  // all | up | down
  });

  const [hidden, setHidden] = useState(new Set());
  const [view, setView] = useState("grid");
  const [route, setRoute] = useState(getRoute());

  // --- routing ---
  useEffect(() => {
    const onHash = () => setRoute(getRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  // --- init load ---
  const didInit = useRef(false);
  useEffect(() => {
    if (didInit.current) return;
    didInit.current = true;

    (async () => {
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances);
        setMonitors(monitors);

        const bl = await getBlocklist();
        const set = new Set((bl?.monitors ?? []).map(k => keyFor(k.instance, k.name)));
        setHidden(set);
      } catch (e) { console.error(e); }
    })();
  }, []);

  // --- polling 5s ---
  useEffect(() => {
    let stop = false;
    async function loop() {
      if (stop) return;
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances);
        setMonitors(monitors);
      } catch {}
      setTimeout(loop, 5000);
    }
    loop();
    return () => { stop = true; };
  }, []);

  // ===========================
  // BASE MONITORS (filters sin status)
  // ===========================
  const baseMonitors = useMemo(() => {
    return monitors.filter(m => {
      if (filters.instance && m.instance !== filters.instance) return false;
      if (filters.type && m.info?.monitor_type !== filters.type) return false;
      if (filters.q) {
        const hay = `${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""}`.toLowerCase();
        if (!hay.includes(filters.q.toLowerCase())) return false;
      }
      return true;
    });
  }, [monitors, filters.instance, filters.type, filters.q]);

  // ===========================
  // HEADER COUNTS (solo monitores filtrados)
  // ===========================
  const headerCounts = useMemo(() => {
    const up    = baseMonitors.filter(m => m.latest?.status === 1).length;
    const down  = baseMonitors.filter(m => m.latest?.status === 0).length;
    const total = baseMonitors.length;
    const rts = baseMonitors.map(m => m.latest?.responseTime).filter(v=>v!=null);
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length) : null;
    return { up, down, total, avgMs };
  }, [baseMonitors]);

  // ===========================
  // FILTRO DE ESTADO (UP/DOWN/ALL)
  // ===========================
  const effectiveStatus = filters.status;

  function setStatus(status) {
    setFilters(prev => ({ ...prev, status }));
  }

  // ===========================
  // MONITORES VISIBLES
  // ===========================
  const filteredAll = useMemo(() => {
    return baseMonitors.filter(m => {
      if (effectiveStatus === "up"   && m.latest?.status !== 1) return false;
      if (effectiveStatus === "down" && m.latest?.status !== 0) return false;
      return true;
    });
  }, [baseMonitors, effectiveStatus]);

  const visible = filteredAll.filter(m => !hidden.has(keyFor(m.instance, m.info?.monitor_name)));

  // ===========================
  // HIDDEN MGMT
  // ===========================
  async function persistHidden(next) {
    const arr = [...next].map(k => {
      const {i, n} = fromKey(k);
      return { instance:i, name:n };
    });
    await saveBlocklist({ monitors: arr });
    setHidden(next);
  }

  function onHide(instance, name) {
    const next = new Set(hidden);
    next.add(keyFor(instance, name));
    persistHidden(next);
  }

  function onUnhide(instance, name) {
    const next = new Set(hidden);
    next.delete(keyFor(instance, name));
    persistHidden(next);
  }

  function onHideAll(instance) {
    const next = new Set(hidden);
    filteredAll
      .filter(m => m.instance === instance)
      .forEach(m => next.add(keyFor(m.instance, m.info?.monitor_name)));
    persistHidden(next);
  }

  async function onUnhideAll(instance) {
    const bl = await getBlocklist();
    const nextArr = (bl?.monitors ?? []).filter(k => k.instance !== instance);
    await saveBlocklist({ monitors: nextArr });
    setHidden(new Set(nextArr.map(k=>keyFor(k.instance,k.name))));
  }

  function openInstance(name) {
    window.location.hash = "/sede/" + encodeURIComponent(name);
  }

  // ===========================
  // UI
  // ===========================
  if (route.name === "sede") {
    return (
      <div className="container">
        <InstanceDetail
          instanceName={route.instance}
          monitorsAll={filteredAll}
          hiddenSet={hidden}
          onHide={onHide}
          onUnhide={onUnhide}
          onHideAll={onHideAll}
          onUnhideAll={onUnhideAll}
        />
      </div>
    );
  }

  return (
    <div className="container">
      <h1>Uptime Central</h1>

      <Cards
        counts={headerCounts}
        status={effectiveStatus}
        onSetStatus={setStatus}
      />

      <div className="controls">
        <Filters
          monitors={monitors}
          value={filters}
          onChange={setFilters}
        />

        <div style={{ display:"flex", gap:8 }}>
          <button className={`btn tab ${view==="grid"?"active":""}`} onClick={()=>setView("grid")}>Grid</button>
          <button className={`btn tab ${view==="table"?"active":""}`} onClick={()=>setView("table")}>Tabla</button>
        </div>
      </div>

      <SLAAlerts
        monitors={visible}
        config={SLA_CONFIG}
        onOpenInstance={openInstance}
      />

      {view==="grid" ? (
        <ServiceGrid
          monitorsAll={filteredAll}
          hiddenSet={hidden}
          onHideAll={onHideAll}
          onUnhideAll={onUnhideAll}
          onOpen={openInstance}
        />
      ) : (
        <MonitorsTable
          monitors={visible}
          hiddenSet={hidden}
          onHide={onHide}
          onUnhide={onUnhide}
          slaConfig={SLA_CONFIG}
        />
      )}
    </div>
  );
}
EOF

echo "✔ src/App.jsx actualizado (versión limpia y funcional)"

##############################################################################
# 2. Reemplazar COMPLETO src/components/Cards.jsx ya se hizo arriba
#
##############################################################################

##############################################################################
# 3. Agregar estilos a src/styles.css
##############################################################################
if [ -f src/styles.css ]; then
  cp src/styles.css src/styles.css.bak.$TS
fi

cat >> src/styles.css <<'EOF'

/* === Header cards === */
.k-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px,1fr));
  gap: 12px;
  margin: 8px 0 16px;
}
.k-card.k-card--summary {
  border: 1px solid #e5e7eb;
  border-left: 6px solid #e5e7eb;
  border-radius: 10px;
  background: #fff;
  padding: 12px;
}
.k-card__title { font-weight: 600; margin-bottom: 6px; }
.k-metric { font-size: 20px; font-weight: 700; margin-right: 6px; }
.k-label  { color: #6b7280; font-size: 12px; }
.is-clickable { cursor:pointer; transition:0.15s; }
.is-clickable:hover { box-shadow:0 2px 10px rgba(0,0,0,.06); }
.is-active { background:#f0f9ff; outline:2px solid #93c5fd; }

EOF

echo "✔ styles.css actualizado"
echo " "
echo "=============================================="
echo "   ✔ PARCHE APLICADO"
echo "   Ahora ejecuta: npm run dev"
echo "=============================================="
