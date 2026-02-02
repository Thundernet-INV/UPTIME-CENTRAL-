#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Uptime Kuma UI Enhancements Installer
# - Gráficas de uptime y tiempos de respuesta por monitor
# - Alertas por SLA (uptime y latencia)
# - Logos por servicio (WhatsApp, Facebook, Apple, Netflix, etc.)
# - Refactor de api.js (SSE con reconexión), App.jsx (summary + SSE idempotente)
# - Nuevos componentes y estilos mínimos
# ------------------------------------------------------------

ROOT_DIR=$(pwd)
SRC_DIR="${ROOT_DIR}/src"
COMP_DIR="${SRC_DIR}/components"
CHARTS_DIR="${COMP_DIR}/charts"
LIB_DIR="${SRC_DIR}/lib"
PUBLIC_LOGOS_DIR="${ROOT_DIR}/public/logos"
TS=$(date +%Y%m%d%H%M%S)

backup() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak.${TS}"
    echo "[backup] $f -> $f.bak.${TS}"
  fi
}

ensure_tree() {
  mkdir -p "$CHARTS_DIR" "$LIB_DIR" "$PUBLIC_LOGOS_DIR" "$COMP_DIR"
}

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "[ERROR] No se encontró $f. Ejecuta este script en la raíz del proyecto (donde está src/)." >&2
    exit 1
  fi
}

main() {
  echo "== Uptime Kuma UI Enhancements Installer =="
  require_file "${SRC_DIR}/App.jsx"
  require_file "${SRC_DIR}/main.jsx"
  require_file "${SRC_DIR}/api.js"
  ensure_tree

  # ---- Backups ----
  backup "${SRC_DIR}/api.js"
  backup "${COMP_DIR}/MonitorsTable.jsx"
  backup "${COMP_DIR}/ServiceGrid.jsx"
  backup "${SRC_DIR}/App.jsx"
  backup "${ROOT_DIR}/vite.config.js"
  backup "${ROOT_DIR}/styles.css"
  backup "${SRC_DIR}/styles.css" || true

  # ---- api.js (reemplazo total con SSE + reconexión) ----
  cat > "${SRC_DIR}/api.js" <<'JS'
const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";

async function fetchJSON(path, init = {}) {
  const res = await fetch(API + path, {
    headers: { "Accept": "application/json", ...(init.headers || {}) },
    ...init,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  }
  return res.json();
}

export async function fetchSummary() {
  return fetchJSON("api/summary");
}

export async function fetchMonitors() {
  return fetchJSON("api/monitors");
}

/**
 * Abre un SSE con auto-reconexión (retryMs base).
 * onMessage(payload) se llama cuando llega el evento "tick".
 * Devuelve una función close() para cerrar definitivamente.
 */
export function openStream(onMessage, { retryMs = 2000, maxRetryMs = 15000 } = {}) {
  let es;
  let stopped = false;
  let currRetry = retryMs;

  const start = () => {
    es = new EventSource(API + "api/stream");
    es.addEventListener("tick", (e) => {
      try {
        const payload = JSON.parse(e.data);
        onMessage?.(payload);
        currRetry = retryMs; // éxito ⇒ resetea backoff
      } catch {
        // ignora payload inválido
      }
    });
    es.onerror = () => {
      es?.close?.();
      if (!stopped) {
        const wait = currRetry;
        currRetry = Math.min(currRetry * 2, maxRetryMs);
        setTimeout(start, wait);
      }
    };
  };

  start();
  return () => {
    stopped = true;
    es?.close?.();
  };
}

export async function getBlocklist() {
  return fetchJSON("api/blocklist");
}

export async function saveBlocklist(b) {
  return fetchJSON("api/blocklist", {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(b),
  });
}
JS

  # ---- lib/sla.js ----
  cat > "${LIB_DIR}/sla.js" <<'JS'
// src/lib/sla.js
export function uptimePct(points = []) {
  if (!points.length) return 100;
  const up = points.filter(p => p?.status === 1).length;
  return +(100 * up / points.length).toFixed(2);
}

export function breaches(points = [], config = {}) {
  const { uptimeTarget = 99.9, maxLatencyMs = 800 } = config;
  const upPct = uptimePct(points);

  const rts = points.map(p => p?.responseTime).filter(v => Number.isFinite(v)).sort((a, b) => a - b);
  const pick = (p) => {
    if (!rts.length) return undefined;
    const idx = Math.min(rts.length - 1, Math.floor((p / 100) * rts.length));
    return rts[idx];
  };
  const p95 = pick(95);
  const p99 = pick(99);

  const issues = [];
  if (upPct < uptimeTarget) issues.push(`Uptime ${upPct}% < objetivo ${uptimeTarget}%`);
  if (p95 != null && p95 > maxLatencyMs) issues.push(`P95 ${p95} ms > ${maxLatencyMs} ms`);
  if (p99 != null && p99 > maxLatencyMs * 1.2) issues.push(`P99 ${p99} ms > ${Math.round(maxLatencyMs * 1.2)} ms`);

  return { ok: issues.length === 0, issues, details: { uptime: upPct, p95, p99 } };
}
JS

  # ---- charts/ResponseTimeMini.jsx ----
  cat > "${CHARTS_DIR}/ResponseTimeMini.jsx" <<'JS'
import React from "react";

export default function ResponseTimeMini({ points = [], width = 140, height = 36, pad = 4 }) {
  const data = points.map(p => p?.responseTime).filter(v => Number.isFinite(v));
  if (!data.length) return <span>—</span>;
  const max = Math.max(1, ...data);
  const step = (width - 2 * pad) / Math.max(1, data.length - 1);
  const line = data.map((v, i) => {
    const x = pad + i * step;
    const y = height - pad - (v / max) * (height - 2 * pad);
    return `${x},${y}`;
  }).join(" ");

  return (
    <svg width={width} height={height} className="spark">
      <polyline fill="none" stroke="#4f46e5" strokeWidth="2" points={line} />
      <line x1={pad} x2={width - pad} y1={height - pad} y2={height - pad} stroke="#ddd" />
    </svg>
  );
}
JS

  # ---- charts/UptimeBarMini.jsx ----
  cat > "${CHARTS_DIR}/UptimeBarMini.jsx" <<'JS'
import React from "react";

export default function UptimeBarMini({ points = [], width = 140, height = 12 }) {
  if (!points.length) return <span>—</span>;
  const w = Math.max(1, Math.floor(width / points.length));
  return (
    <svg width={width} height={height} className="bars">
      {points.map((p, i) => {
        const up = p?.status === 1;
        return (
          <rect
            key={i} x={i * w} y={0} width={w - 1} height={height}
            fill={up ? "#16a34a" : "#dc2626"} opacity={up ? 0.8 : 0.9}
          />
        );
      })}
    </svg>
  );
}
JS

  # ---- components/Logo.jsx ----
  cat > "${COMP_DIR}/Logo.jsx" <<'JS'
import React from "react";

const MAP = [
  { key: "whatsapp", src: "/logos/whatsapp.svg" },
  { key: "facebook", src: "/logos/facebook.svg" },
  { key: "meta", src: "/logos/facebook.svg" },
  { key: "apple", src: "/logos/apple.svg" },
  { key: "icloud", src: "/logos/apple.svg" },
  { key: "netflix", src: "/logos/netflix.svg" },
];

function pickLogo({ name = "", url = "", host = "" }) {
  const hay = `${name} ${url} ${host}`.toLowerCase();
  const hit = MAP.find(m => hay.includes(m.key));
  return hit?.src || "/logos/default.svg";
}

export default function Logo({ monitor }) {
  const src = pickLogo({
    name: monitor?.info?.monitor_name || "",
    url: monitor?.info?.monitor_url || "",
    host: monitor?.info?.monitor_hostname || "",
  });
  return <img src={src} alt="logo servicio" className="logo" width={20} height={20} />;
}
JS

  # ---- components/SLAAlerts.jsx ----
  cat > "${COMP_DIR}/SLAAlerts.jsx" <<'JS'
import React from "react";
import { breaches } from "../lib/sla";

export default function SLAAlerts({ monitors = [], config, onOpenInstance }) {
  const rows = monitors
    .map(m => ({ m, ...breaches(m.points ?? [], config) }))
    .filter(x => !x.ok);

  if (!rows.length) return null;

  return (
    <div className="alert-panel">
      <strong>Alertas SLA</strong>
      <ul>
        {rows.slice(0, 8).map(({ m, issues }, i) => (
          <li key={i}>
            <span className="chip down">SLA</span>
            <b>{m.info?.monitor_name}</b> en <em>{m.instance}</em>: {issues.join(" · ")} {" "}
            <button className="link" onClick={() => onOpenInstance?.(m.instance)}>abrir sede</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
JS

  # ---- components/ServiceCard.jsx ----
  cat > "${COMP_DIR}/ServiceCard.jsx" <<'JS'
import React from "react";

export default function ServiceCard({ sede, data, onHideAll, onUnhideAll, onOpen }) {
  const { up, down, total, avg, trend = [] } = data ?? {};
  const width = 120, height = 36, pad = 4;
  const max = Math.max(1, ...trend);
  const points = trend.map((v, i) => {
    const x = pad + (i * (width - 2 * pad)) / Math.max(1, trend.length - 1);
    const y = height - pad - (v / max) * (height - 2 * pad);
    return `${x},${y}`;
  });

  return (
    <div className="card">
      <div className="card-head">
        <h3 className="card-title">{sede}</h3>
        <div className="card-actions">
          <button className="btn" onClick={onOpen}>Abrir</button>
          <button className="btn" onClick={onHideAll}>Ocultar sede</button>
          <button className="btn" onClick={onUnhideAll}>Mostrar sede</button>
        </div>
      </div>

      <div className="stats">
        <div><span className="k">UP</span><span className="v">{up}</span></div>
        <div><span className="k">DOWN</span><span className="v">{down}</span></div>
        <div><span className="k">TOTAL</span><span className="v">{total}</span></div>
        <div><span className="k">AVG</span><span className="v">{avg != null ? `${avg} ms` : "—"}</span></div>
      </div>

      <svg width={width} height={height} className="sparkline" aria-label="tendencia latencia">
        {trend.length > 1 && (
          <>
            <polyline fill="none" stroke="#4f46e5" strokeWidth="2" points={points.join(" ")} />
            <line x1={pad} x2={width - pad} y1={height - pad} y2={height - pad} stroke="#ddd" />
          </>
        )}
      </svg>
    </div>
  );
}
JS

  # ---- components/ServiceGrid.jsx (reemplazo) ----
  cat > "${COMP_DIR}/ServiceGrid.jsx" <<'JS'
import React from "react";
import ServiceCard from "./ServiceCard.jsx";

export default function ServiceGrid({ monitorsAll = [], hiddenSet, onHideAll, onUnhideAll, onOpen }) {
  const by = (monitorsAll ?? []).reduce((a, m) => {
    (a[m.instance] = a[m.instance] ?? []).push(m);
    return a;
  }, {});

  const make = (inst, arr) => {
    const visible = arr.filter((m) => !hiddenSet.has(`${m.instance}::${m.info?.monitor_name}`));

    const up = visible.filter((m) => m.latest?.status === 1).length;
    const down = visible.filter((m) => m.latest?.status === 0).length;
    const total = visible.length;

    const rts = visible.map((m) => m.latest?.responseTime).filter((v) => v != null);
    const avg = rts.length ? Math.round(rts.reduce((a, b) => a + b, 0) / rts.length) : null;

    const len = Math.min(...visible.map((m) => (m.points ?? []).length).filter(Boolean));
    const trend = Number.isFinite(len)
      ? Array.from({ length: Math.min(len, 50) }, (_, i) => {
          const vals = visible
            .map((m) => m.points[m.points.length - len + i]?.responseTime)
            .filter((v) => v != null);
          return vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : 0;
        })
      : [];

    return { sede: inst, data: { up, down, total, avg, trend, monitors: arr } };
  };

  const cards = Object.entries(by).map(([inst, arr]) => make(inst, arr));

  if (!cards.length) return <p>No hay datos para la cuadrícula (ver filtros o sedes).</p>;

  return (
    <div className="grid">
      {cards.map((c) => (
        <ServiceCard
          key={c.sede}
          sede={c.sede}
          data={c.data}
          onHideAll={() => onHideAll?.(c.sede)}
          onUnhideAll={() => onUnhideAll?.(c.sede)}
          onOpen={() => onOpen?.(c.sede)}
        />
      ))}
    </div>
  );
}
JS

  # ---- components/MonitorsTable.jsx (reemplazo) ----
  cat > "${COMP_DIR}/MonitorsTable.jsx" <<'JS'
import React from "react";
import Logo from "./Logo.jsx";
import ResponseTimeMini from "./charts/ResponseTimeMini.jsx";
import UptimeBarMini from "./charts/UptimeBarMini.jsx";
import { uptimePct, breaches } from "../lib/sla";

export default function MonitorsTable({ monitors = [], hiddenSet, onHide, onUnhide, slaConfig }) {
  return (
    <table className="table">
      <thead>
        <tr>
          <th>Logo</th>
          <th>Estado</th>
          <th>Monitor</th>
          <th>Instancia</th>
          <th>Tipo</th>
          <th>Objetivo</th>
          <th>Tendencia</th>
          <th>Uptime</th>
          <th>SLA</th>
          <th>Latencia</th>
          <th>Acción</th>
        </tr>
      </thead>
      <tbody>
        {monitors.map((m) => {
          const key = `${m.instance}::${m.info?.monitor_name}`;
          const hidden = hiddenSet.has(key);
          const up = m.latest?.status === 1;
          const objetivo = m.info?.monitor_url || m.info?.monitor_hostname || "—";
          const latency = m.latest?.responseTime != null ? `${m.latest.responseTime} ms` : "—";
          const points = m.points ?? [];
          const uptime = uptimePct(points);
          const sla = breaches(points, slaConfig);

          return (
            <tr key={key} className={hidden ? "row-muted" : undefined}>
              <td><Logo monitor={m} /></td>
              <td><span className={`chip ${up ? "up" : "down"}`}>{up ? "UP" : "DOWN"}</span></td>
              <td><strong>{m.info?.monitor_name}</strong></td>
              <td>{m.instance}</td>
              <td>{m.info?.monitor_type}</td>
              <td>{objetivo}</td>
              <td><ResponseTimeMini points={points} /></td>
              <td title={`${uptime}%`}><UptimeBarMini points={points} /></td>
              <td>
                {sla.ok ? (
                  <span className="chip up">OK</span>
                ) : (
                  <span className="chip warn" title={sla.issues.join(" | ")}>BRECHA</span>
                )}
              </td>
              <td>{latency}</td>
              <td>
                {!hidden ? (
                  <button className="btn" onClick={() => onHide(m.instance, m.info?.monitor_name)}>Ocultar</button>
                ) : (
                  <button className="btn" onClick={() => onUnhide(m.instance, m.info?.monitor_name)}>Mostrar</button>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}
JS

  # ---- App.jsx (reemplazo completo con refactor + SLA Alerts) ----
  cat > "${SRC_DIR}/App.jsx" <<'JS'
import { useEffect, useMemo, useRef, useState } from "react";
import Cards from "./components/Cards.jsx";
import Filters from "./components/Filters.jsx";
import ServiceGrid from "./components/ServiceGrid.jsx";
import MonitorsTable from "./components/MonitorsTable.jsx";
import InstanceDetail from "./components/InstanceDetail.jsx";
import SLAAlerts from "./components/SLAAlerts.jsx";
import { fetchSummary, fetchMonitors, openStream, getBlocklist, saveBlocklist } from "./api.js";

const SLA_CONFIG = {
  uptimeTarget: 99.9,
  maxLatencyMs: 800,
};

function getRoute() {
  const parts = (window.location.hash || "").slice(1).split("/").filter(Boolean);
  if (parts[0] === "sede" && parts[1]) return { name: "sede", instance: decodeURIComponent(parts[1]) };
  return { name: "home" };
}

function computeSummary(ms = []) {
  const up = ms.filter((m) => m.latest?.status === 1).length;
  const down = ms.filter((m) => m.latest?.status === 0).length;
  const rts = ms.map((m) => m.latest?.responseTime).filter((v) => v != null);
  const avgResponseTimeMs = rts.length ? Math.round(rts.reduce((a, b) => a + b, 0) / rts.length) : null;
  return { up, down, total: ms.length, avgResponseTimeMs };
}

const keyFor = (instance, name = "") => JSON.stringify({ i: instance, n: name });
const fromKey = (k) => { try { return JSON.parse(k) } catch { return { i: "", n: "" } } };

export default function App() {
  const [summary, setSummary] = useState({ up: 0, down: 0, total: 0, avgResponseTimeMs: null });
  const [monitors, setMonitors] = useState([]);
  const [filters, setFilters] = useState({ instance: "", type: "", q: "", onlyDown: false });
  const [hidden, setHidden] = useState(new Set());
  const [view, setView] = useState("grid");
  const [route, setRoute] = useState(getRoute());

  useEffect(() => {
    const onHash = () => setRoute(getRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  const didInit = useRef(false);
  useEffect(() => {
    if (didInit.current) return;
    didInit.current = true;

    (async () => {
      try {
        const s = await fetchSummary();
        setSummary(s ?? {});
        const ms = await fetchMonitors();
        setMonitors(ms ?? []);
        const bl = await getBlocklist();
        const set = new Set((bl?.monitors ?? []).map((k) => keyFor(k.instance, k.name)));
        setHidden(set);
        if (!s || typeof s.total === "undefined") {
          setSummary(computeSummary(ms ?? []));
        }
      } catch {
        // TODO: feedback
      }
    })();

    const close = openStream((p) => {
      const ms = p?.monitors ?? [];
      setMonitors(ms);
      setSummary(computeSummary(ms));
    });

    return () => close?.();
  }, []);

  const filteredAll = useMemo(() => (monitors ?? []).filter((m) => {
    if (filters.instance && m.instance !== filters.instance) return false;
    if (filters.type && m.info?.monitor_type !== filters.type) return false;
    if (filters.onlyDown && m.latest?.status !== 0) return false;
    if (filters.q) {
      const hay = `${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""} ${m.info?.monitor_hostname ?? ""}`.toLowerCase();
      if (!hay.includes(filters.q.toLowerCase())) return false;
    }
    return true;
  }), [monitors, filters]);

  const visible = filteredAll.filter((m) => !hidden.has(keyFor(m.instance, m.info?.monitor_name)));

  async function persistHidden(next) {
    const arr = [...next].map((k) => { const { i, n } = fromKey(k); return { instance: i, name: n }; });
    await saveBlocklist({ monitors: arr });
    setHidden(next);
  }
  function onHide(instance, name) { const next = new Set(hidden); next.add(keyFor(instance, name)); persistHidden(next); }
  function onUnhide(instance, name) { const next = new Set(hidden); next.delete(keyFor(instance, name)); persistHidden(next); }
  function onHideAll(instance) {
    const next = new Set(hidden);
    filteredAll.filter((m) => m.instance === instance).forEach((m) => next.add(keyFor(m.instance, m.info?.monitor_name)));
    persistHidden(next);
  }
  async function onUnhideAll(instance) {
    const bl = await getBlocklist();
    const nextArr = (bl?.monitors ?? []).filter((k) => k.instance !== instance);
    await saveBlocklist({ monitors: nextArr });
    setHidden(new Set(nextArr.map((k) => keyFor(k.instance, k.name))));
  }
  function openInstance(name) { window.location.hash = "/sede/" + encodeURIComponent(name); }
  function tabBtn(v, t) { return <button className={`btn tab ${view === v ? "active" : ""}`} onClick={() => setView(v)}>{t}</button>; }

  if (route.name === "sede") {
    return (
      <div className="container">
        <InstanceDetail
          instanceName={route.instance}
          monitorsAll={filteredAll}
          hiddenSet={hidden}
          onHide={onHide} onUnhide={onUnhide}
          onHideAll={onHideAll} onUnhideAll={onUnhideAll}
        />
      </div>
    );
  }

  return (
    <div className="container">
      <h1>Uptime Central</h1>
      <Cards summary={summary} />
      <div className="controls">
        <Filters monitors={monitors} value={filters} onChange={setFilters} />
        <div style={{ display: "flex", gap: 8 }}>
          {tabBtn("grid", "Grid")}
          {tabBtn("table", "Tabla")}
        </div>
      </div>

      <SLAAlerts monitors={visible} config={SLA_CONFIG} onOpenInstance={openInstance} />

      {view === "grid"
        ? <ServiceGrid monitorsAll={filteredAll} hiddenSet={hidden} onHideAll={onHideAll} onUnhideAll={onUnhideAll} onOpen={openInstance} />
        : <MonitorsTable monitors={visible} hiddenSet={hidden} onHide={onHide} onUnhide={onUnhide} slaConfig={SLA_CONFIG} />}
    </div>
  );
}
JS

  # ---- styles.css (append estilos mínimos) ----
  STYLES_TARGET="${SRC_DIR}/styles.css"
  if [[ -f "${ROOT_DIR}/styles.css" && ! -f "${SRC_DIR}/styles.css" ]]; then
    # Si el proyecto tenía styles.css en raíz, muévelo a src/ para centralizar
    mv "${ROOT_DIR}/styles.css" "${SRC_DIR}/styles.css"
  fi
  touch "$STYLES_TARGET"
  cat >> "$STYLES_TARGET" <<'CSS'
/* === Uptime Kuma UI Enhancements (SLA, tablas y mini-charts) === */
.table { width: 100%; border-collapse: collapse; }
.table th, .table td { padding: 8px 10px; border-bottom: 1px solid #eee; font-size: 14px; }
.row-muted { opacity: 0.5; }
.chip { padding: 2px 8px; border-radius: 999px; font-size: 12px; color: #fff; }
.chip.up { background: #16a34a; }
.chip.down { background: #dc2626; }
.chip.warn { background: #d97706; }
.btn { font-size: 12px; padding: 6px 10px; background: #f3f4f6; border: 1px solid #e5e7eb; border-radius: 6px; cursor: pointer; }
.btn:hover { background: #e5e7eb; }
.logo { display: block; border-radius: 4px; }
.spark, .bars { display: block; }
.alert-panel { margin: 8px 0 12px; padding: 8px 10px; background: #fff7ed; border: 1px solid #fed7aa; border-radius: 8px; }
.alert-panel ul { margin: 6px 0 0; padding-left: 18px; }
.link { background: none; border: none; color: #2563eb; cursor: pointer; text-decoration: underline; padding: 0 4px; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.card { border: 1px solid #e5e7eb; border-radius: 10px; padding: 10px; background: #fff; }
.card-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.card-title { margin: 0; font-size: 16px; }
.card-actions { display: flex; gap: 6px; }
.stats { display: grid; grid-template-columns: repeat(4, minmax(0,1fr)); gap: 8px; margin: 8px 0; }
.stats .k { display: block; font-size: 11px; color: #6b7280; }
.stats .v { font-weight: 600; }
.sparkline { display: block; margin-top: 4px; }
/* === fin estilos === */
CSS

  # ---- Public logos (placeholders) ----
  cat > "${PUBLIC_LOGOS_DIR}/default.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="24" r="20" fill="#9ca3af"/></svg>
SVG
  cat > "${PUBLIC_LOGOS_DIR}/whatsapp.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="24" r="20" fill="#22c55e"/></svg>
SVG
  cat > "${PUBLIC_LOGOS_DIR}/facebook.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="8" y="8" width="32" height="32" fill="#2563eb"/></svg>
SVG
  cat > "${PUBLIC_LOGOS_DIR}/apple.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="10" y="10" width="28" height="28" rx="6" fill="#111827"/></svg>
SVG
  cat > "${PUBLIC_LOGOS_DIR}/netflix.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><rect x="8" y="8" width="32" height="32" fill="#dc2626"/></svg>
SVG

  # ---- Mensaje final ----
  cat <<'EOF'

✅ Cambios aplicados.

Siguientes pasos:
  1) (Opcional) Configura una base para tu backend en dev: export VITE_API_BASE (o usa proxy Vite).
     Ej.: echo 'VITE_API_BASE=http://localhost:8080/' > .env
  2) Ejecuta: npm run dev
  3) Verifica:
     - Tabla con columnas nuevas (Logo, Tendencia, Uptime, SLA)
     - Panel de Alertas SLA
     - Cuadrícula con tarjetas y sparkline
     - SSE reconecta si reinicias el backend

Si tu backend está en otro puerto y no usa CORS, añade un proxy en vite.config.js (server.proxy).
EOF
}

main "$@"
