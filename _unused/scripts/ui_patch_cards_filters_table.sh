#!/bin/sh
# Uptime Central – Patch para:
# 1. Activar checkbox “Solo DOWN” correctamente.
# 2. Hacer toda la tarjeta clicable para abrir la sede.
# 3. Convertir InstanceDetail a una TABLA con iconos UP/DOWN.
# 4. Mantener sparkline, histórico, alertas y header dinámico.

set -eu
TS=$(date +%Y%m%d%H%M%S)

###############################################################################
# Validación
###############################################################################
if [ ! -f package.json ]; then
  echo "[ERROR] Este script debe ejecutarse en la carpeta del frontend (donde está package.json)"
  exit 1
fi

mkdir -p src/components

###############################################################################
# 1) Aplicar ServiceCard.jsx con toda la tarjeta clicable (opción A)
###############################################################################
echo "== Patch ServiceCard.jsx: card clicable + iconos OK/Incidencias =="
cp src/components/ServiceCard.jsx src/components/ServiceCard.jsx.bak.$TS 2>/dev/null || true

cat > src/components/ServiceCard.jsx <<'JSX'
import React from "react";
import Sparkline from "./Sparkline.jsx";

export default function ServiceCard({ sede, data, onHideAll, onUnhideAll, onOpen, spark }) {
  const { up = 0, down = 0, total = 0, avg = null } = data ?? {};
  const hasIncidents = down > 0;

  function clickCard() {
    onOpen?.(sede);
  }

  function stop(e) {
    e.stopPropagation();
  }

  return (
    <div className="k-card k-card--site clickable" onClick={clickCard}>
      <div className="k-card__head">
        <h3 className="k-card__title">{sede}</h3>
        <span className={`k-badge ${hasIncidents ? "k-badge--danger" : "k-badge--ok"}`}>
          {hasIncidents ? "Incidencias" : "OK"}
        </span>
      </div>

      {spark ? (
        <div style={{ marginBottom: 8 }}>
          <Sparkline
            points={spark}
            color={hasIncidents ? "#ef4444" : "#16a34a"}
          />
        </div>
      ) : null}

      <div className="k-stats">
        <div><span className="k-label">UP:</span> <span className="k-val">{up}</span></div>
        <div><span className="k-label">DOWN:</span> <span className="k-val">{down}</span></div>
        <div><span className="k-label">Total:</span> <span className="k-val">{total}</span></div>
        <div><span className="k-label">Prom:</span> <span className="k-val">{avg != null ? `${avg} ms` : "—"}</span></div>
      </div>

      <div className="k-actions" onClick={stop}>
        <button className="k-btn k-btn--danger" onClick={()=>onHideAll?.(sede)}>Ocultar todos</button>
        <button className="k-btn k-btn--ghost" onClick={()=>onUnhideAll?.(sede)}>Mostrar todos</button>
      </div>
    </div>
  );
}
JSX

###############################################################################
# 2) InstanceDetail → convertir a tabla con UP/DOWN y latencias
###############################################################################
echo "== Patch InstanceDetail.jsx: ahora tabla con iconos 🟢/🔴 =="
cp src/components/InstanceDetail.jsx src/components/InstanceDetail.jsx.bak.$TS 2>/dev/null || true

cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide, onUnhide, onHideAll, onUnhideAll
}) {
  const group = useMemo(
    () => monitorsAll.filter(m => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  const series = useMemo(
    () => History.getAllForInstance(instanceName),
    [instanceName, monitorsAll.length]
  );

  return (
    <div>
      <h2>{instanceName}</h2>
      <HistoryChart series={series} />

      <div style={{ marginTop: 12 }}>
        <button className="k-btn k-btn--primary" onClick={() => window.history.back()}>
          Volver
        </button>
        <button className="k-btn k-btn--danger" onClick={() => onHideAll?.(instanceName)} style={{ marginLeft: 8 }}>
          Ocultar sede
        </button>
        <button className="k-btn k-btn--ghost" onClick={() => onUnhideAll?.(instanceName)} style={{ marginLeft: 8 }}>
          Mostrar sede
        </button>
      </div>

      <h3 style={{ marginTop: 20 }}>Servicios</h3>
      <table className="k-table">
        <thead>
          <tr>
            <th>Servicio</th>
            <th>Estado</th>
            <th>Latencia</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          {group.map((m, i) => {
            const st = m.latest?.status === 1 ? "UP" : "DOWN";
            const icon = st === "UP" ? "🟢" : "🔴";
            const lat = m.latest?.responseTime ?? "—";
            return (
              <tr key={i}>
                <td>{m.info?.monitor_name}</td>
                <td style={{ fontWeight: "bold", color: st === "UP" ? "#16a34a" : "#dc2626" }}>
                  {icon} {st}
                </td>
                <td>{lat} ms</td>
                <td>
                  <button className="k-btn k-btn--ghost" onClick={() => onHide?.(m.instance, m.info?.monitor_name)}>
                    Ocultar
                  </button>
                  <button
                    className="k-btn k-btn--ghost"
                    style={{ marginLeft: 6 }}
                    onClick={() => onUnhide?.(m.instance, m.info?.monitor_name)}
                  >
                    Mostrar
                  </button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
JSX

###############################################################################
# 3) Conectar checkbox “Solo DOWN” al filtro real (status)
###############################################################################
echo "== Patch Filters.jsx: activar checkbox Solo DOWN =="
cp src/components/Filters.jsx src/components/Filters.jsx.bak.$TS 2>/dev/null || true

cat > src/components/Filters.jsx <<'JSX'
import React from "react";

export default function Filters({ monitors, value, onChange }) {
  function set(k, v) {
    onChange({ ...value, [k]: v });
  }

  function toggleDown(e) {
    const checked = e.target.checked;
    set("status", checked ? "down" : "all");
  }

  return (
    <div className="filters">
      <select
        value={value.instance}
        onChange={(e) => set("instance", e.target.value)}
      >
        <option value="">Todas las sedes</option>
        {[...new Set(monitors.map(m => m.instance))].sort().map((name) => (
          <option key={name} value={name}>{name}</option>
        ))}
      </select>

      <select
        value={value.type}
        onChange={(e) => set("type", e.target.value)}
      >
        <option value="">Todos los tipos</option>
        {[...new Set(monitors.map(m => m.info?.monitor_type))].sort().map((t) => (
          <option key={t} value={t}>{t}</option>
        ))}
      </select>

      <input
        type="text"
        placeholder="Buscar..."
        value={value.q}
        onChange={(e) => set("q", e.target.value)}
      />

      <label style={{ marginLeft: 12 }}>
        <input
          type="checkbox"
          checked={value.status === "down"}
          onChange={toggleDown}
        />
        {" "}Solo DOWN
      </label>
    </div>
  );
}
JSX

###############################################################################
# 4) Añadir estilos para tabla + clickable cards
###############################################################################
echo "== Patch styles.css =="
cp src/styles.css src/styles.css.bak.$TS 2>/dev/null || true

cat >> src/styles.css <<'CSS'

/* Tabla de InstanceDetail */
.k-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 12px;
}
.k-table th {
  text-align: left;
  padding: 8px;
  background: #f3f4f6;
  border-bottom: 2px solid #e5e7eb;
  font-size: 14px;
}
.k-table td {
  padding: 8px;
  border-bottom: 1px solid #e5e7eb;
  font-size: 14px;
}

/* Card clickable */
.k-card--site.clickable {
  cursor: pointer;
}
.k-card--site.clickable:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,.08);
}

/* Para evitar que botones dentro del card disparen apertura */
.k-actions button {
  z-index: 2;
}

CSS

###############################################################################
echo "== PATCH COMPLETO =="
echo "Ejecuta ahora:"
echo "   npm run dev"
echo "Tu UI está actualizada: tarjetas clicables, tabla bonita, Solo DOWN funcional."
