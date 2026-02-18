import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";

const TIPOS_EQUIPO = {
  PLANTA: { label: "PLANTAS", color: "#3b82f6", bg: "#dbeafe" },
  AVR: { label: "AVR", color: "#f59e0b", bg: "#fef3c7" },
  CORPOELEC: { label: "CORPOELEC", color: "#8b5cf6", bg: "#ede9fe" },
  INVERSOR: { label: "INVERSORES", color: "#10b981", bg: "#d1fae5" }
};

const KEYWORDS_TIPO = [
  { kw: "planta", tipo: "PLANTA" },
  { kw: "avr", tipo: "AVR" },
  { kw: "corpoelec", tipo: "CORPOELEC" },
  { kw: "corpo", tipo: "CORPOELEC" },
  { kw: "inversor", tipo: "INVERSOR" },
];

function deducirTipo(nombre = "", tipoExplicito) {
  if (tipoExplicito && TIPOS_EQUIPO[tipoExplicito]) return tipoExplicito;
  const low = String(nombre).toLowerCase();
  for (const { kw, tipo } of KEYWORDS_TIPO) {
    if (low.includes(kw)) return tipo;
  }
  return "OTRO";
}

function calcularMetricas(monitores) {
  let total = monitores.length;
  let up = 0;
  let down = 0;
  let issues = 0;
  let sumaRT = 0;
  let rtCount = 0;

  for (const m of monitores) {
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
  }

  const avgMs = rtCount > 0 ? Math.round(sumaRT / rtCount) : null;
  const uptime = total > 0 ? Math.round((up / total) * 100) : 100;

  return { total, up, down, issues, avgMs, uptime };
}

function TarjetaTipo({ tipo, monitores, datos }) {
  const { total, up, down, issues, avgMs, uptime } = datos;
  const estilo = TIPOS_EQUIPO[tipo] || { label: tipo, color: "#6b7280", bg: "#f3f4f6" };
  
  let estado = "ok";
  let estadoTexto = "Operativo";
  let estadoColor = "#16a34a";
  
  if (down > 0) {
    estado = "down";
    estadoTexto = "Incidencias críticas";
    estadoColor = "#dc2626";
  } else if (issues > 0) {
    estado = "issues";
    estadoTexto = "En observación";
    estadoColor = "#f59e0b";
  }

  return (
    <div className="k-card" style={{
      borderLeft: `6px solid ${estilo.color}`,
      marginBottom: '20px',
      overflow: 'hidden'
    }}>
      {/* Header */}
      <div style={{
        background: estilo.bg,
        padding: '16px 20px',
        borderBottom: '1px solid #e5e7eb'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: '600', color: '#1f2937' }}>
            {estilo.label}
          </h3>
          <span style={{
            padding: '4px 12px',
            borderRadius: '999px',
            background: estadoColor,
            color: 'white',
            fontSize: '0.8rem',
            fontWeight: '600'
          }}>
            {total} equipos
          </span>
        </div>
      </div>

      {/* Métricas principales */}
      <div style={{ padding: '20px' }}>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
          gap: '16px',
          marginBottom: '20px'
        }}>
          <div style={{
            background: '#f9fafb',
            padding: '12px',
            borderRadius: '8px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase' }}>UP</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '600', color: '#16a34a' }}>{up}</div>
          </div>
          
          <div style={{
            background: '#f9fafb',
            padding: '12px',
            borderRadius: '8px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase' }}>DOWN</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '600', color: '#dc2626' }}>{down}</div>
          </div>
          
          <div style={{
            background: '#f9fafb',
            padding: '12px',
            borderRadius: '8px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase' }}>LATENCIA</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '600', color: '#1f2937' }}>
              {avgMs ? `${avgMs}ms` : '—'}
            </div>
          </div>
          
          <div style={{
            background: '#f9fafb',
            padding: '12px',
            borderRadius: '8px',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase' }}>UPTIME</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '600', color: estadoColor }}>
              {uptime}%
            </div>
          </div>
        </div>

        {/* Barra de estado */}
        <div style={{
          display: 'flex',
          gap: '4px',
          height: '8px',
          borderRadius: '4px',
          overflow: 'hidden',
          marginBottom: '20px'
        }}>
          <div style={{
            flex: up,
            background: '#16a34a',
            height: '100%'
          }} title={`UP: ${up}`} />
          <div style={{
            flex: down,
            background: '#dc2626',
            height: '100%'
          }} title={`DOWN: ${down}`} />
          <div style={{
            flex: issues,
            background: '#f59e0b',
            height: '100%'
          }} title={`Issues: ${issues}`} />
        </div>

        {/* Lista de equipos */}
        <div>
          <h4 style={{ margin: '0 0 12px 0', fontSize: '0.9rem', color: '#4b5563' }}>
            Equipos ({total})
          </h4>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
            gap: '12px'
          }}>
            {monitores.slice(0, 6).map((monitor, idx) => {
              const latest = monitor.latest || {};
              const status = latest.status === 1 ? 'up' : 'down';
              const rt = latest.responseTime;
              
              return (
                <div key={idx} style={{
                  padding: '12px',
                  background: status === 'up' ? '#f0fdf4' : '#fef2f2',
                  borderRadius: '6px',
                  border: `1px solid ${status === 'up' ? '#bbf7d0' : '#fee2e2'}`
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: '600', fontSize: '0.9rem' }}>
                      {monitor.info?.monitor_name || monitor.name}
                    </span>
                    <span style={{
                      width: '10px',
                      height: '10px',
                      borderRadius: '50%',
                      background: status === 'up' ? '#16a34a' : '#dc2626'
                    }} />
                  </div>
                  {rt && (
                    <div style={{ fontSize: '0.8rem', color: '#4b5563', marginTop: '4px' }}>
                      {rt} ms
                    </div>
                  )}
                </div>
              );
            })}
          </div>
          {monitores.length > 6 && (
            <div style={{ marginTop: '12px', textAlign: 'center', fontSize: '0.8rem', color: '#6b7280' }}>
              + {monitores.length - 6} equipos más
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function EnergiaDetail({ instanceName = "Energía", monitorsAll = [] }) {
  const [seriesMap, setSeriesMap] = useState({});

  // Filtrar solo monitores de la instancia Energía
  const energiaMonitors = useMemo(() => {
    return monitorsAll.filter(m => 
      m.instance === "Energía" || 
      m.instance === "Energia" ||
      (m.info?.monitor_name || "").toLowerCase().includes("planta") ||
      (m.info?.monitor_name || "").toLowerCase().includes("avr") ||
      (m.info?.monitor_name || "").toLowerCase().includes("corpo") ||
      (m.info?.monitor_name || "").toLowerCase().includes("inversor")
    );
  }, [monitorsAll]);

  // Agrupar por tipo
  const equiposPorTipo = useMemo(() => {
    const grupos = {
      PLANTA: [],
      AVR: [],
      CORPOELEC: [],
      INVERSOR: [],
      OTRO: []
    };

    energiaMonitors.forEach(m => {
      const nombre = m.info?.monitor_name || m.name || "";
      const tipoExplicito = m.info?.tipo_equipo;
      const tipo = deducirTipo(nombre, tipoExplicito);
      
      if (grupos[tipo]) {
        grupos[tipo].push(m);
      } else {
        grupos.OTRO.push(m);
      }
    });

    return grupos;
  }, [energiaMonitors]);

  // Calcular métricas por tipo
  const metricasPorTipo = useMemo(() => {
    const result = {};
    Object.keys(equiposPorTipo).forEach(tipo => {
      result[tipo] = calcularMetricas(equiposPorTipo[tipo]);
    });
    return result;
  }, [equiposPorTipo]);

  // Métricas totales
  const metricasTotales = useMemo(() => {
    return calcularMetricas(energiaMonitors);
  }, [energiaMonitors]);

  return (
    <div style={{ padding: '24px' }}>
      {/* Header */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: '24px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <button
            className="k-btn k-btn--primary"
            onClick={() => window.history.back()}
            style={{ padding: '8px 16px' }}
          >
            ← Volver
          </button>
          <h1 style={{ margin: 0, fontSize: '1.8rem' }}>⚡ Energía</h1>
        </div>
        
        {/* Resumen total */}
        <div style={{
          padding: '8px 16px',
          background: '#f3f4f6',
          borderRadius: '8px',
          fontSize: '0.9rem'
        }}>
          <span style={{ fontWeight: '600' }}>Total:</span> {metricasTotales.total} equipos · 
          <span style={{ color: '#16a34a', marginLeft: '8px' }}>↑ {metricasTotales.up}</span>
          <span style={{ color: '#dc2626', marginLeft: '8px' }}>↓ {metricasTotales.down}</span>
          <span style={{ color: '#f59e0b', marginLeft: '8px' }}>⚠ {metricasTotales.issues}</span>
        </div>
      </div>

      {/* Grid de tipos de equipo */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        {Object.keys(TIPOS_EQUIPO).map(tipo => {
          const monitores = equiposPorTipo[tipo] || [];
          if (monitores.length === 0) return null;
          
          return (
            <TarjetaTipo
              key={tipo}
              tipo={tipo}
              monitores={monitores}
              datos={metricasPorTipo[tipo]}
            />
          );
        })}
        
        {/* Mostrar OTRO si hay equipos no clasificados */}
        {equiposPorTipo.OTRO.length > 0 && (
          <TarjetaTipo
            tipo="OTRO"
            monitores={equiposPorTipo.OTRO}
            datos={metricasPorTipo.OTRO}
          />
        )}
      </div>

      {energiaMonitors.length === 0 && (
        <div className="k-card" style={{ padding: '40px', textAlign: 'center' }}>
          <p style={{ color: '#6b7280', fontSize: '1.1rem' }}>
            No hay equipos de energía configurados
          </p>
        </div>
      )}
    </div>
  );
}
