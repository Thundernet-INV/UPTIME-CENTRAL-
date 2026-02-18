import React, { useState, useMemo, useEffect } from 'react';

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
function TipoCard({ tipo, monitores, metricas, onFiltroClick, filtroActivo, onEquipoClick, equipoSeleccionado }) {
  const [isExpanded, setIsExpanded] = useState(true);
  const config = TIPOS_EQUIPO[tipo] || { 
    nombre: tipo, 
    color: '#6b7280', 
    bg: '#f3f4f6', 
    icon: '📦',
    desc: 'Otros equipos'
  };
  
  const { total, up, down, issues, avgMs } = metricas;

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
          {/* INDICADORES DE COLOR - NO SON BOTONES */}
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
          {/* Grid de equipos */}
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
              {config.desc} · {equipo.instance || 'Sin sede'}
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
  const [filtros, setFiltros] = useState({}); // { tipo: 'up' | 'down' | 'issues' }
  const [equipoSeleccionado, setEquipoSeleccionado] = useState(null);
  const [statsGlobales, setStatsGlobales] = useState({ total: 0, up: 0, down: 0, issues: 0 });

  // Procesar monitores
  const { equiposPorTipo, metricasPorTipo } = useMemo(() => {
    const grupos = {
      PLANTA: [],
      AVR: [],
      CORPOELEC: [],
      INVERSOR: [],
      OTRO: []
    };

    monitorsAll.forEach(m => {
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
  }, [monitorsAll]);

  // Aplicar filtros a los monitores
  const monitoresFiltrados = useMemo(() => {
    const resultado = {};
    
    Object.keys(equiposPorTipo).forEach(tipo => {
      const filtroActual = filtros[tipo];
      if (!filtroActual) {
        resultado[tipo] = equiposPorTipo[tipo];
      } else {
        resultado[tipo] = equiposPorTipo[tipo].filter(m => {
          const latest = m.latest || {};
          const status = latest.status;
          const rt = latest.responseTime;
          
          if (filtroActual === 'up') return status === 1;
          if (filtroActual === 'down') return status === 0 || rt === -1;
          if (filtroActual === 'issues') return status !== 1 && status !== 0 && rt !== -1;
          return true;
        });
      }
    });
    
    return resultado;
  }, [equiposPorTipo, filtros]);

  const handleFiltroClick = (tipo, estado) => {
    setFiltros(prev => {
      if (prev[tipo] === estado) {
        const newFiltros = { ...prev };
        delete newFiltros[tipo];
        return newFiltros;
      }
      return { ...prev, [tipo]: estado };
    });
  };

  const handleEquipoClick = (equipo) => {
    setEquipoSeleccionado(equipo);
  };

  return (
    <div style={{ padding: '24px' }}>
      {/* Título simple - SIN GRADIENTE MORADO */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ margin: 0, fontSize: '2rem', fontWeight: '700', color: '#1f2937' }}>
          ⚡ Dashboard de Energía
        </h1>
        <p style={{ margin: '8px 0 0', fontSize: '1rem', color: '#6b7280' }}>
          Monitoreo en tiempo real de plantas, AVRs, Corpolec e inversores
        </p>
      </div>

      {/* ESTADÍSTICAS GLOBALES EN TARJETAS SIMPLES */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gap: '16px',
        marginBottom: '24px'
      }}>
        <div style={{
          background: '#f9fafb',
          padding: '20px',
          borderRadius: '12px',
          textAlign: 'center',
          border: '1px solid #e5e7eb'
        }}>
          <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: '8px' }}>TOTAL EQUIPOS</div>
          <div style={{ fontSize: '2.2rem', fontWeight: '700', color: '#1f2937' }}>{statsGlobales.total}</div>
        </div>
        <div style={{
          background: '#f0fdf4',
          padding: '20px',
          borderRadius: '12px',
          textAlign: 'center',
          border: '1px solid #bbf7d0'
        }}>
          <div style={{ fontSize: '0.9rem', color: '#166534', marginBottom: '8px' }}>UP</div>
          <div style={{ fontSize: '2.2rem', fontWeight: '700', color: '#16a34a' }}>{statsGlobales.up}</div>
        </div>
        <div style={{
          background: '#fef2f2',
          padding: '20px',
          borderRadius: '12px',
          textAlign: 'center',
          border: '1px solid #fee2e2'
        }}>
          <div style={{ fontSize: '0.9rem', color: '#991b1b', marginBottom: '8px' }}>DOWN</div>
          <div style={{ fontSize: '2.2rem', fontWeight: '700', color: '#dc2626' }}>{statsGlobales.down}</div>
        </div>
        <div style={{
          background: '#fef3c7',
          padding: '20px',
          borderRadius: '12px',
          textAlign: 'center',
          border: '1px solid #fde68a'
        }}>
          <div style={{ fontSize: '0.9rem', color: '#92400e', marginBottom: '8px' }}>ISSUES</div>
          <div style={{ fontSize: '2.2rem', fontWeight: '700', color: '#f59e0b' }}>{statsGlobales.issues}</div>
        </div>
      </div>

      {/* TARJETAS POR TIPO */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {Object.keys(TIPOS_EQUIPO).map(tipo => {
          const monitores = monitoresFiltrados[tipo] || [];
          if (monitores.length === 0) return null;
          
          return (
            <TipoCard
              key={tipo}
              tipo={tipo}
              monitores={monitores}
              metricas={metricasPorTipo[tipo]}
              onFiltroClick={handleFiltroClick}
              filtroActivo={filtros[tipo]}
              onEquipoClick={handleEquipoClick}
              equipoSeleccionado={equipoSeleccionado}
            />
          );
        })}

        {/* Mostrar OTROS si hay equipos no clasificados */}
        {monitoresFiltrados.OTRO?.length > 0 && (
          <TipoCard
            tipo="OTRO"
            monitores={monitoresFiltrados.OTRO}
            metricas={metricasPorTipo.OTRO}
            onFiltroClick={handleFiltroClick}
            filtroActivo={filtros.OTRO}
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
