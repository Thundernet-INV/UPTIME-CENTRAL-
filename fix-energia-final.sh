#!/bin/bash
# fix-energia-final.sh - OCULTAR CARDS DE RESUMEN EN VISTA ENERGÍA

echo "====================================================="
echo "⚡ IMPLEMENTANDO VISTA ENERGÍA - SIN CARDS DE RESUMEN"
echo "====================================================="
echo ""

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_energia_$(date +%Y%m%d_%H%M%S)"

# ========== COLORES ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# ========== 1. MATAR PROCESOS ==========
info "Matando procesos en puertos 5173, 5174, 5175..."
sudo fuser -k 5173/tcp 5174/tcp 5175/tcp 2>/dev/null
pkill -f "vite" 2>/dev/null
log "Procesos eliminados"

# ========== 2. CREAR BACKUP ==========
info "Creando backup en: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r "${FRONTEND_DIR}/src/components" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "${FRONTEND_DIR}/src/views" "$BACKUP_DIR/" 2>/dev/null || true
log "✅ Backup creado en: $BACKUP_DIR"

# ========== 3. MODIFICAR DASHBOARD.JSX PARA OCULTAR CARDS ==========
info "Modificando Dashboard.jsx para ocultar cards en vista Energía..."

# Backup del Dashboard actual
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "${BACKUP_DIR}/Dashboard.jsx.bak"

# Crear nuevo Dashboard con condicional para ocultar cards
cat > "${FRONTEND_DIR}/src/views/Dashboard.jsx" << 'EOF'
import { useEffect, useMemo, useRef, useState } from "react";

import Hero from "../components/Hero.jsx";
import AlertsBanner from "../components/AlertsBanner.jsx";
import Cards from "../components/Cards.jsx";
import InstanceDetail from "../components/InstanceDetail.jsx";
import EnergiaDashboard from "../components/EnergiaDashboard.jsx";
import SLAAlerts from "../components/SLAAlerts.jsx";
import InstanceCard from "../components/InstanceCard.jsx";
import MultiServiceView from "../components/MultiServiceView.jsx";

import { fetchAll, getBlocklist, saveBlocklist } from "../api.js";
import History from "../historyEngine.js";
import { notify } from "../utils/notify.js";

const SLA_CONFIG = { uptimeTarget: 99.9, maxLatencyMs: 800 };
const ALERT_AUTOCLOSE_MS = 10000;

/** Ruteo por hash: #/sede/<instancia>, #/comparar, #/energia, vacío -> home */
function getRoute() {
  const parts = (window.location.hash || "")
    .slice(1)
    .split("/")
    .filter(Boolean);

  if (parts[0] === "sede" && parts[1]) {
    return { name: "sede", instance: decodeURIComponent(parts[1]) };
  }
  if (parts[0] === "comparar") {
    return { name: "compare" };
  }
  if (parts[0] === "energia") {
    return { name: "energia" };
  }
  return { name: "home" };
}

const keyFor = (i, n = "") => JSON.stringify({ i, n });
const fromKey = (k) => {
  try { return JSON.parse(k); } catch { return { i: "", n: "" }; }
};

export default function Dashboard() {
  // ===== Estado base =====
  const [autoPlay, setAutoPlay] = useState(false);
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);

  const [monitors, setMonitors] = useState([]);
  const [instances, setInstances] = useState([]);
  const [filters, setFilters] = useState({ instance: "", type: "", q: "", status: "all" });
  const [hidden, setHidden] = useState(new Set());
  const [route, setRoute] = useState(getRoute());
  const [alerts, setAlerts] = useState([]);

  // ===== Ruteo por hash =====
  useEffect(() => {
    const onHash = () => setRoute(getRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  // ===== Init: primer fetch + blocklist + snapshot =====
  const didInit = useRef(false);
  useEffect(() => {
    if (didInit.current) return;
    didInit.current = true;
    (async () => {
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances || []);
        setMonitors(monitors || []);
        History.addSnapshot?.(monitors || []);

        try {
          const bl = await getBlocklist();
          setHidden(new Set((bl?.monitors ?? []).map((k) => keyFor(k.instance, k.name))));
        } catch {
          // ignorar errores de blocklist
        }
      } catch (e) { console.error(e); }
    })();
  }, []);

  // ===== Polling simple =====
  useEffect(() => {
    let stop = false;
    (async function loop() {
      if (stop) return;
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances || []);
        setMonitors(monitors || []);
        History.addSnapshot?.(monitors || []);
      } catch (e) { console.error(e); }
      setTimeout(loop, 15000);
    })();
    return () => { stop = true; };
  }, []);

  // ===== Filtros base (sin estado UP/DOWN) =====
  const baseMonitors = useMemo(
    () =>
      monitors.filter((m) => {
        if (filters.instance && m.instance !== filters.instance) return false;
        if (filters.type && m.info?.monitor_type !== filters.type) return false;
        if (filters.q) {
          const hay = ((m.info?.monitor_name ?? "") + " " + (m.info?.monitor_url ?? "")).toLowerCase();
          if (!hay.includes(filters.q.toLowerCase())) return false;
        }
        return true;
      }),
    [monitors, filters.instance, filters.type, filters.q]
  );

  // ===== Lista de tipos de servicio (monitor_type) =====
  const serviceTypes = useMemo(() => {
    const set = new Set();
    for (const m of monitors) {
      const t = m.info?.monitor_type;
      if (t) set.add(t);
    }
    return Array.from(set).sort();
  }, [monitors]);

  // ===== Métricas header =====
  const headerCounts = useMemo(() => {
    const up = baseMonitors.filter((m) => m.latest?.status === 1).length;
    const down = baseMonitors.filter((m) => m.latest?.status === 0).length;
    const total = baseMonitors.length;
    const rts = baseMonitors.map((m) => m.latest?.responseTime).filter((v) => v != null);
    const avgMs = rts.length ? Math.round(rts.reduce((a, b) => a + b, 0) / rts.length) : null;
    return { up, down, total, avgMs };
  }, [baseMonitors]);

  // ===== Estado efectivo UP/DOWN =====
  const effectiveStatus = filters.status;
  function setStatus(s) { setFilters((p) => ({ ...p, status: s })); }

  // ===== Lista final (con estado) =====
  const filteredAll = useMemo(
    () =>
      baseMonitors.filter((m) => {
        if (effectiveStatus === "up" && m.latest?.status !== 1) return false;
        if (effectiveStatus === "down" && m.latest?.status !== 0) return false;
        return true;
      }),
    [baseMonitors, effectiveStatus]
  );

  // ===== Agrupación por instancia (para la grid del Home) =====
  const monitorsByInstance = useMemo(() => {
    const map = new Map();
    for (const m of filteredAll) {
      const list = map.get(m.instance) || [];
      list.push(m);
      map.set(m.instance, list);
    }
    return map;
  }, [filteredAll]);

  // Hidden / Blocklist
  async function persistHidden(next) {
    const arr = [...next].map((k) => {
      const { i, n } = fromKey(k); return { instance: i, name: n };
    });
    try { await saveBlocklist({ monitors: arr }); } catch {}
    setHidden(next);
  }
  function onHide(i, n)      { const s = new Set(hidden); s.add(keyFor(i, n)); persistHidden(s); }
  function onUnhide(i, n)    { const s = new Set(hidden); s.delete(keyFor(i, n)); persistHidden(s); }
  function onHideAll(instance){ const s = new Set(hidden); filteredAll.filter((m)=>m.instance===instance).forEach((m)=>s.add(keyFor(m.instance, m.info?.monitor_name))); persistHidden(s); }
  async function onUnhideAll(instance){
    const bl = await getBlocklist();
    const nextArr = (bl?.monitors ?? []).filter((k) => k.instance !== instance);
    try { await saveBlocklist({ monitors: nextArr }); } catch {}
    setHidden(new Set(nextArr.map((k) => keyFor(k.instance, k.name))));
  }

  // Navegación a una sede
  function openInstance(name) { window.location.hash = "/sede/" + encodeURIComponent(name); }

  // ===== Render =====
  return (
    <main>
      {/* HERO principal con barra de búsqueda */}
      <Hero
        onSearch={(q) =>
          setFilters((p) => ({
            ...p,
            q,
          }))
        }
      />

      <section className="home-services-section">
        <div className="home-services-container">
          <div className="container" data-route={route.name}>
            {/* Fila superior: Nombre + Home + filtros */}
            <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <h1 style={{ margin: 0 }}>Thunder Detector</h1>

                <button
                  className="home-btn"
                  type="button"
                  onClick={() => { window.location.hash = ""; setAutoPlay(false); }}
                  title="Ir al inicio"
                >
                  Home
                </button>

                <button
                  className="home-btn"
                  type="button"
                  onClick={() => { window.location.hash = "/comparar"; setAutoPlay(false); }}
                  title="Comparar servicio por sede"
                >
                  Comparar
                </button>

                <button
                  className="home-btn"
                  type="button"
                  onClick={() => { window.location.hash = "/energia"; setAutoPlay(false); }}
                  title="Vista de energía"
                >
                  ⚡ Energía
                </button>
              </div>

              {/* Controles: filtro por tipo + notificaciones + autoplay */}
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginLeft: "auto", flexWrap: "wrap" }}>
                {/* Filtro por tipo de servicio */}
                <label
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 6,
                    fontSize: "0.85rem",
                    color: "#475569",
                  }}
                >
                  <span>Tipo de servicio:</span>
                  <select
                    value={filters.type}
                    onChange={(e) =>
                      setFilters((p) => ({
                        ...p,
                        type: e.target.value,
                      }))
                    }
                    style={{
                      fontSize: "0.85rem",
                      padding: "4px 8px",
                      borderRadius: 6,
                    }}
                  >
                    <option value="">Todos</option>
                    {serviceTypes.map((t) => (
                      <option key={t} value={t}>
                        {t}
                      </option>
                    ))}
                  </select>
                </label>

                {/* Botón Notificaciones ON/OFF */}
                <button
                  type="button"
                  className={"k-btn k-btn--ghost" + (notificationsEnabled ? " is-active" : "")}
                  onClick={() => setNotificationsEnabled((prev) => !prev)}
                  style={{ fontSize: "0.8rem" }}
                >
                  🔔 Notificaciones: {notificationsEnabled ? "ON" : "OFF"}
                </button>

                {/* Toggle autoplay entre sedes (Home/Instancias) */}
                <label
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 6,
                    fontSize: "0.85rem",
                    color: "#475569",
                  }}
                >
                  <input
                    type="checkbox"
                    checked={autoPlay}
                    onChange={() => setAutoPlay((prev) => !prev)}
                  />
                  <span>
                    {autoPlay ? "Playlist activa" : "Playlist entre sedes"}
                  </span>
                </label>
              </div>
            </div>

            {/* Alertas */}
            <AlertsBanner
              alerts={alerts}
              onClose={(id) => setAlerts((a) => a.filter((x) => x.id !== id))}
              autoCloseMs={ALERT_AUTOCLOSE_MS}
            />

            {/* 🎯 CONDICIONAL: OCULTAR CARDS EN VISTA ENERGÍA */}
            {route.name !== "energia" && (
              <>
                {/* Tarjetas de resumen (UP / DOWN / TOTAL / PROM) */}
                <Cards
                  counts={headerCounts}
                  status={effectiveStatus}
                  onSetStatus={setStatus}
                />

                <SLAAlerts
                  monitors={filteredAll.filter((m) => !hidden.has(keyFor(m.instance, m.info?.monitor_name)))}
                  config={SLA_CONFIG}
                  onOpenInstance={openInstance}
                />
              </>
            )}

            {route.name === "sede" ? (
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
            ) : route.name === "compare" ? (
              <MultiServiceView monitorsAll={monitors} />
            ) : route.name === "energia" ? (
              <EnergiaDashboard monitorsAll={monitors} />
            ) : (
              // HOME: grid de instancias usando InstanceCard
              <section
                aria-label="Instancias monitoreadas"
                className="service-grid instances-grid"
              >
                {instances.map((inst) => {
                  const monitorsForInstance = monitorsByInstance.get(inst.name) || [];
                  return (
                    <InstanceCard
                      key={inst.name}
                      instance={inst}
                      monitors={monitorsForInstance}
                      onClick={openInstance}
                    />
                  );
                })}
              </section>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}
EOF

log "✅ Dashboard.jsx modificado - Cards ocultas en vista Energía"

# ========== 4. CREAR COMPONENTE ENERGIA DASHBOARD ==========
info "Creando componente EnergiaDashboard.jsx (solo instancia Energía)..."

cat > "${FRONTEND_DIR}/src/components/EnergiaDashboard.jsx" << 'EOF'
import React, { useState, useMemo } from 'react';

// ========== CONFIGURACIÓN DE TIPOS DE EQUIPO ==========
const TIPOS_EQUIPO = {
  PLANTA: { 
    nombre: 'PLANTA', 
    color: '#3b82f6', 
    bg: '#dbeafe',
    icon: '🏭',
    desc: 'Plantas eléctricas'
  },
  AVR: { 
    nombre: 'AVR', 
    color: '#f59e0b', 
    bg: '#fef3c7',
    icon: '⚡',
    desc: 'Reguladores automáticos de voltaje'
  },
  CORPOELEC: { 
    nombre: 'CORPOELEC', 
    color: '#8b5cf6', 
    bg: '#ede9fe',
    icon: '🔌',
    desc: 'Conexiones Corpolec'
  },
  INVERSOR: { 
    nombre: 'INVERSOR', 
    color: '#10b981', 
    bg: '#d1fae5',
    icon: '🔄',
    desc: 'Inversores de corriente'
  }
};

// ========== FUNCIONES DE AYUDA ==========
function deducirTipo(nombre = '') {
  const nombreLower = nombre.toLowerCase();
  if (nombreLower.includes('planta')) return 'PLANTA';
  if (nombreLower.includes('avr')) return 'AVR';
  if (nombreLower.includes('corpo')) return 'CORPOELEC';
  if (nombreLower.includes('inversor')) return 'INVERSOR';
  return 'OTRO';
}

function calcularMetricas(monitores) {
  let total = monitores.length;
  let up = 0;
  let down = 0;
  let issues = 0;
  let sumaRT = 0;
  let rtCount = 0;

  monitores.forEach(m => {
    const latest = m.latest || {};
    const status = latest.status;
    const rt = latest.responseTime;

    if (status === 1) {
      up++;
    } else if (status === 0 || rt === -1) {
      down++;
    } else {
      issues++;
    }

    if (typeof rt === 'number' && rt > 0) {
      sumaRT += rt;
      rtCount++;
    }
  });

  const avgMs = rtCount > 0 ? Math.round(sumaRT / rtCount) : null;
  const uptime = total > 0 ? Math.round((up / total) * 100) : 100;

  return { total, up, down, issues, avgMs, uptime };
}

// ========== COMPONENTE DE TARJETA DE EQUIPO ==========
function EquipoCard({ equipo, onClick, isSelected }) {
  const latest = equipo.latest || {};
  const status = latest.status === 1 ? 'up' : 'down';
  const rt = latest.responseTime;
  const tipo = deducirTipo(equipo.info?.monitor_name || '');
  const config = TIPOS_EQUIPO[tipo] || { color: '#6b7280', bg: '#f3f4f6', icon: '❓' };
  
  return (
    <div 
      onClick={() => onClick(equipo)}
      style={{
        padding: '12px',
        background: status === 'up' ? '#f0fdf4' : '#fef2f2',
        borderRadius: '8px',
        border: isSelected ? `3px solid ${config.color}` : `1px solid ${status === 'up' ? '#bbf7d0' : '#fee2e2'}`,
        cursor: 'pointer',
        transition: 'all 0.2s ease',
        transform: isSelected ? 'scale(1.02)' : 'scale(1)',
        boxShadow: isSelected ? '0 4px 12px rgba(0,0,0,0.1)' : 'none'
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = 'scale(1.02)';
        e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.1)';
      }}
      onMouseLeave={(e) => {
        if (!isSelected) {
          e.currentTarget.style.transform = 'scale(1)';
          e.currentTarget.style.boxShadow = 'none';
        }
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
        <span style={{ fontWeight: '600', fontSize: '0.95rem' }}>
          {config.icon} {equipo.info?.monitor_name || 'Sin nombre'}
        </span>
        <span style={{
          width: '12px',
          height: '12px',
          borderRadius: '50%',
          background: status === 'up' ? '#16a34a' : '#dc2626'
        }} />
      </div>
      {rt && (
        <div style={{ fontSize: '0.85rem', color: '#4b5563' }}>
          {rt} ms
        </div>
      )}
    </div>
  );
}

// ========== COMPONENTE DE TARJETA DE TIPO ==========
function TipoCard({ tipo, monitores, metricas, filtroActivo, onEquipoClick, equipoSeleccionado }) {
  const [isExpanded, setIsExpanded] = useState(true);
  const config = TIPOS_EQUIPO[tipo] || { 
    nombre: tipo, 
    color: '#6b7280', 
    bg: '#f3f4f6', 
    icon: '📦',
    desc: 'Otros equipos'
  };
  
  const { total, up, down, issues } = metricas;

  return (
    <div style={{
      background: 'white',
      borderRadius: '12px',
      marginBottom: '16px',
      boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
      overflow: 'hidden',
      border: filtroActivo ? `2px solid ${config.color}` : 'none'
    }}>
      {/* Header de la tarjeta */}
      <div 
        onClick={() => setIsExpanded(!isExpanded)}
        style={{
          background: config.bg,
          padding: '16px 20px',
          cursor: 'pointer',
          borderBottom: isExpanded ? `2px solid ${config.color}` : 'none',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <span style={{ fontSize: '1.8rem' }}>{config.icon}</span>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: '600', color: '#1f2937' }}>
              {config.nombre} <span style={{ fontSize: '0.9rem', color: '#6b7280', fontWeight: 'normal' }}>
                ({total} equipos)
              </span>
            </h3>
            <p style={{ margin: '4px 0 0', fontSize: '0.85rem', color: '#4b5563' }}>
              {config.desc}
            </p>
          </div>
        </div>
        <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
          {/* INDICADORES DE COLOR */}
          <div style={{ display: 'flex', gap: '8px' }}>
            <div style={{
              padding: '4px 12px',
              borderRadius: '20px',
              background: '#16a34a',
              color: 'white',
              fontSize: '0.85rem',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '4px'
            }}>
              ↑ {up}
            </div>
            <div style={{
              padding: '4px 12px',
              borderRadius: '20px',
              background: down > 0 ? '#dc2626' : '#9ca3af',
              color: 'white',
              fontSize: '0.85rem',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '4px'
            }}>
              ↓ {down}
            </div>
            <div style={{
              padding: '4px 12px',
              borderRadius: '20px',
              background: issues > 0 ? '#f59e0b' : '#9ca3af',
              color: 'white',
              fontSize: '0.85rem',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '4px'
            }}>
              ⚠ {issues}
            </div>
          </div>
          <span style={{ fontSize: '1.2rem', color: '#6b7280' }}>
            {isExpanded ? '▼' : '▶'}
          </span>
        </div>
      </div>

      {/* Contenido expandible */}
      {isExpanded && (
        <div style={{ padding: '20px' }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
            gap: '12px'
          }}>
            {monitores.map((monitor, idx) => (
              <EquipoCard
                key={idx}
                equipo={monitor}
                onClick={onEquipoClick}
                isSelected={equipoSeleccionado?.info?.monitor_name === monitor.info?.monitor_name}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ========== COMPONENTE DE DETALLE DE EQUIPO ==========
function DetalleEquipo({ equipo, onClose }) {
  if (!equipo) return null;

  const latest = equipo.latest || {};
  const status = latest.status === 1 ? 'up' : 'down';
  const tipo = deducirTipo(equipo.info?.monitor_name || '');
  const config = TIPOS_EQUIPO[tipo] || { color: '#6b7280', bg: '#f3f4f6', icon: '❓' };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 10000,
      padding: '20px'
    }} onClick={onClose}>
      <div style={{
        background: 'white',
        borderRadius: '16px',
        padding: '32px',
        maxWidth: '600px',
        width: '100%',
        position: 'relative',
        boxShadow: '0 20px 40px rgba(0,0,0,0.2)'
      }} onClick={(e) => e.stopPropagation()}>
        
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '20px',
            right: '20px',
            background: 'transparent',
            border: 'none',
            fontSize: '28px',
            cursor: 'pointer',
            color: '#6b7280'
          }}
        >
          ×
        </button>

        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '24px' }}>
          <span style={{ fontSize: '3rem' }}>{config.icon}</span>
          <div>
            <h2 style={{ margin: 0, fontSize: '1.8rem', color: '#1f2937' }}>
              {equipo.info?.monitor_name || 'Sin nombre'}
            </h2>
            <p style={{ margin: '4px 0 0', fontSize: '1rem', color: '#6b7280' }}>
              {config.desc} · {equipo.instance || 'Energía'}
            </p>
          </div>
        </div>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: '16px',
          marginBottom: '24px'
        }}>
          <div style={{
            background: status === 'up' ? '#f0fdf4' : '#fef2f2',
            padding: '20px',
            borderRadius: '12px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: '8px' }}>ESTADO</div>
            <div style={{
              fontSize: '2rem',
              fontWeight: '700',
              color: status === 'up' ? '#16a34a' : '#dc2626'
            }}>
              {status === 'up' ? 'UP' : 'DOWN'}
            </div>
          </div>

          <div style={{
            background: '#f9fafb',
            padding: '20px',
            borderRadius: '12px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: '8px' }}>LATENCIA</div>
            <div style={{ fontSize: '2rem', fontWeight: '700', color: '#1f2937' }}>
              {latest.responseTime ? `${latest.responseTime} ms` : '—'}
            </div>
          </div>

          <div style={{
            background: '#f9fafb',
            padding: '20px',
            borderRadius: '12px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: '8px' }}>TIPO</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '600', color: config.color }}>
              {config.nombre}
            </div>
          </div>

          <div style={{
            background: '#f9fafb',
            padding: '20px',
            borderRadius: '12px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: '8px' }}>ÚLTIMO CHECK</div>
            <div style={{ fontSize: '1.2rem', fontWeight: '600', color: '#1f2937' }}>
              {new Date().toLocaleTimeString()}
            </div>
          </div>
        </div>

        <div style={{
          padding: '20px',
          background: '#f3f4f6',
          borderRadius: '12px'
        }}>
          <h4 style={{ margin: '0 0 12px 0', fontSize: '1rem', color: '#4b5563' }}>INFORMACIÓN ADICIONAL</h4>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <div><strong>URL:</strong> {equipo.info?.monitor_url || 'N/A'}</div>
            <div><strong>Tipo de monitor:</strong> {equipo.info?.monitor_type || 'N/A'}</div>
            <div><strong>Tags:</strong> {equipo.info?.tags?.join(', ') || 'Ninguno'}</div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ========== COMPONENTE PRINCIPAL ==========
export default function EnergiaDashboard({ monitorsAll = [] }) {
  const [equipoSeleccionado, setEquipoSeleccionado] = useState(null);
  const [statsGlobales, setStatsGlobales] = useState({ total: 0, up: 0, down: 0, issues: 0 });

  // 🎯 FILTRAR SOLO MONITORES DE LA INSTANCIA "ENERGÍA"
  const energiaMonitors = useMemo(() => {
    return monitorsAll.filter(m => 
      m.instance === "Energía" || 
      m.instance === "Energia" ||
      m.instance?.toLowerCase() === "energía" ||
      m.instance?.toLowerCase() === "energia"
    );
  }, [monitorsAll]);

  // Procesar monitores
  const { equiposPorTipo, metricasPorTipo } = useMemo(() => {
    const grupos = {
      PLANTA: [],
      AVR: [],
      CORPOELEC: [],
      INVERSOR: [],
      OTRO: []
    };

    energiaMonitors.forEach(m => {
      const nombre = m.info?.monitor_name || m.name || '';
      const tipo = deducirTipo(nombre);
      if (grupos[tipo]) {
        grupos[tipo].push(m);
      } else {
        grupos.OTRO.push(m);
      }
    });

    const metricas = {};
    let totalUp = 0, totalDown = 0, totalIssues = 0, totalEquipos = 0;

    Object.keys(grupos).forEach(tipo => {
      metricas[tipo] = calcularMetricas(grupos[tipo]);
      totalUp += metricas[tipo].up;
      totalDown += metricas[tipo].down;
      totalIssues += metricas[tipo].issues;
      totalEquipos += metricas[tipo].total;
    });

    setStatsGlobales({ total: totalEquipos, up: totalUp, down: totalDown, issues: totalIssues });

    return { equiposPorTipo: grupos, metricasPorTipo: metricas };
  }, [energiaMonitors]);

  const handleEquipoClick = (equipo) => {
    setEquipoSeleccionado(equipo);
  };

  // Si no hay equipos de energía, mostrar mensaje
  if (energiaMonitors.length === 0) {
    return (
      <div style={{ padding: '48px', textAlign: 'center' }}>
        <div style={{ fontSize: '4rem', marginBottom: '20px' }}>⚡</div>
        <h2 style={{ color: '#4b5563', marginBottom: '12px' }}>No hay equipos de energía</h2>
        <p style={{ color: '#6b7280' }}>
          No se encontraron monitores en la instancia "Energía"
        </p>
      </div>
    );
  }

  return (
    <div style={{ padding: '24px' }}>
      {/* TARJETAS POR TIPO - SIN CARDS DE RESUMEN GLOBALES */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {Object.keys(TIPOS_EQUIPO).map(tipo => {
          const monitores = equiposPorTipo[tipo] || [];
          if (monitores.length === 0) return null;
          
          return (
            <TipoCard
              key={tipo}
              tipo={tipo}
              monitores={monitores}
              metricas={metricasPorTipo[tipo]}
              onEquipoClick={handleEquipoClick}
              equipoSeleccionado={equipoSeleccionado}
            />
          );
        })}

        {/* Mostrar OTROS si hay equipos no clasificados */}
        {equiposPorTipo.OTRO?.length > 0 && (
          <TipoCard
            tipo="OTRO"
            monitores={equiposPorTipo.OTRO}
            metricas={metricasPorTipo.OTRO}
            onEquipoClick={handleEquipoClick}
            equipoSeleccionado={equipoSeleccionado}
          />
        )}
      </div>

      {/* MODAL DE DETALLE DE EQUIPO */}
      <DetalleEquipo
        equipo={equipoSeleccionado}
        onClose={() => setEquipoSeleccionado(null)}
      />
    </div>
  );
}
EOF

log "✅ Componente EnergiaDashboard.jsx creado - SIN estadísticas globales"

# ========== 5. CREAR SCRIPT DE ROLLBACK ==========
info "Creando script de rollback..."

cat > "${FRONTEND_DIR}/rollback-energia.sh" << 'EOF'
#!/bin/bash
# rollback-energia.sh - RESTAURA DESDE EL BACKUP

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR=$(ls -d ${FRONTEND_DIR}/backup_energia_* 2>/dev/null | sort -r | head -1)

if [ -z "$BACKUP_DIR" ]; then
    echo "❌ No se encontró backup"
    exit 1
fi

echo "====================================================="
echo "🔙 RESTAURANDO DESDE: $BACKUP_DIR"
echo "====================================================="

cp -r "$BACKUP_DIR/components" "${FRONTEND_DIR}/src/" 2>/dev/null
cp -r "$BACKUP_DIR/views" "${FRONTEND_DIR}/src/" 2>/dev/null

sudo fuser -k 5173/tcp 5174/tcp 5175/tcp 2>/dev/null
pkill -f "vite" 2>/dev/null

cd "$FRONTEND_DIR"
npm run dev &

echo "✅ Rollback completado"
echo "   Abre http://10.10.31.31:5173"
EOF

chmod +x "${FRONTEND_DIR}/rollback-energia.sh"
log "✅ Script de rollback creado"

# ========== 6. REINICIAR ==========
info "Reiniciando frontend..."
cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite 2>/dev/null
pkill -f "vite" 2>/dev/null
npm run dev &
sleep 3

# ========== 7. MOSTRAR INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅✅ DASHBOARD DE ENERGÍA INSTALADO ✅✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🗑️ OCULTADAS: Las cards de resumen (UP/DOWN/Total/Prom)"
echo "      • Ya NO aparecen en la vista de Energía"
echo "      • Siguen visibles en Home y otras vistas"
echo ""
echo "   2. 🎯 FILTRADO: SOLO equipos de la instancia 'Energía'"
echo "      • Ya NO se mezclan equipos de otras instancias"
echo ""
echo "   3. 📊 TARJETAS POR TIPO con indicadores:"
echo "      • Verde (🟢) para UP"
echo "      • Rojo (🔴) para DOWN (solo si > 0)"
echo "      • Amarillo (🟡) para ISSUES (solo si > 0)"
echo "      • Gris cuando son 0"
echo ""
echo "🚀 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Haz click en '⚡ Energía'"
echo "   3. ✅ Las cards de resumen YA NO aparecen"
echo "   4. ✅ Solo ves las tarjetas por tipo de equipo"
echo "   5. ✅ Haz click en cualquier equipo para ver detalles"
echo ""
echo "🔙 ROLLBACK: ./rollback-energia.sh"
echo ""
echo "====================================================="

read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

log "Script completado"
