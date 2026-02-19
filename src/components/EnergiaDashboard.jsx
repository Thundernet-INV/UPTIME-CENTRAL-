import React, { useState, useMemo, useEffect } from 'react';

// ========== CONFIGURACIÓN DE TIPOS DE EQUIPO ==========
const TIPOS_EQUIPO = {
  PLANTA: { 
    nombre: 'PLANTA', 
    color: '#3b82f6', 
    bg: '#dbeafe',
    icon: '',
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
    icon: '',
    desc: 'Conexiones Corpolec'
  },
  INVERSOR: { 
    nombre: 'INVERSOR', 
    color: '#10b981', 
    bg: '#d1fae5',
    icon: '',
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
function EquipoCard({ equipo, onClick, isSelected, consumoData }) {
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
      {/* CONSUMO DE COMBUSTIBLE - SOLO PARA PLANTAS */}
      {tipo === 'PLANTA' && consumoData && (
        <div style={{
          marginTop: '8px',
          padding: '4px 8px',
          background: status === 'up' ? '#d1fae5' : '#f3f4f6',
          borderRadius: '4px',
          fontSize: '0.75rem',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center'
        }}>
          <span>⛽ Consumo</span>
          <span style={{ fontWeight: 600, color: status === 'up' ? '#065f46' : '#4b5563' }}>
            {status === 'up' 
              ? `${consumoData.consumo_actual_sesion?.toFixed(2) || '0.00'}L` 
              : `${consumoData.consumo_total_historico?.toFixed(1) || '0.0'}L`}
          </span>
        </div>
      )}
    </div>
  );
}

// ========== COMPONENTE DE TARJETA DE TIPO ==========
function TipoCard({ tipo, monitores, metricas, filtroActivo, onEquipoClick, equipoSeleccionado, consumosMap }) {
  const [isExpanded, setIsExpanded] = useState(true);
  const config = TIPOS_EQUIPO[tipo] || { 
    nombre: tipo, 
    color: '#6b7280', 
    bg: '#f3f4f6', 
    icon: '',
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
                consumoData={consumosMap[monitor.info?.monitor_name]}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ========== COMPONENTE DE DETALLE DE EQUIPO ==========
function DetalleEquipo({ equipo, onClose, consumoData }) {
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

        {/* SECCIÓN DE CONSUMO - SOLO PARA PLANTAS */}
        {tipo === 'PLANTA' && consumoData && (
          <div style={{
            background: '#d1fae5',
            padding: '20px',
            borderRadius: '12px',
            marginBottom: '16px'
          }}>
            <h4 style={{ margin: '0 0 12px 0', fontSize: '1rem', color: '#065f46' }}>
              ⛽ CONSUMO DE COMBUSTIBLE
            </h4>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              <div style={{ background: 'white', padding: '16px', borderRadius: '8px', textAlign: 'center' }}>
                <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: '4px' }}>
                  Consumo Actual (Sesión)
                </div>
                <div style={{ fontSize: '2rem', fontWeight: 700, color: '#065f46' }}>
                  {consumoData.consumo_actual_sesion?.toFixed(2) || '0.00'} L
                </div>
                {status === 'up' && (
                  <div style={{ fontSize: '0.7rem', color: '#065f46', marginTop: '4px' }}>
                    Acumulado desde que encendió
                  </div>
                )}
              </div>
              <div style={{ background: 'white', padding: '16px', borderRadius: '8px', textAlign: 'center' }}>
                <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: '4px' }}>
                  Consumo Histórico Total
                </div>
                <div style={{ fontSize: '2rem', fontWeight: 700, color: '#1f2937' }}>
                  {consumoData.consumo_total_historico?.toFixed(1) || '0.0'} L
                </div>
              </div>
            </div>
          </div>
        )}

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
  const [consumos, setConsumos] = useState({});
  const [cargando, setCargando] = useState(false);

  // Función para cargar consumos desde la API
  const cargarConsumos = async () => {
    if (cargando) return;
    
    setCargando(true);
    try {
      // Obtener todas las plantas de la instancia Energía
      const plantas = monitorsAll.filter(m => 
        m.instance === "Energía" || 
        m.instance === "Energia" ||
        m.instance?.toLowerCase() === "energía" ||
        m.instance?.toLowerCase() === "energia"
      );

      const nuevosConsumos = {};
      
      // Cargar consumo de cada planta (máximo 5 por ciclo para no saturar)
      const batchSize = 5;
      for (let i = 0; i < plantas.length; i += batchSize) {
        const batch = plantas.slice(i, i + batchSize);
        await Promise.all(batch.map(async (planta) => {
          const nombre = planta.info?.monitor_name;
          if (nombre?.startsWith('PLANTA')) {
            try {
              const res = await fetch(`http://10.10.31.31:8080/api/combustible/consumo/${encodeURIComponent(nombre)}`);
              if (res.ok) {
                const data = await res.json();
                if (data.success) {
                  nuevosConsumos[nombre] = data.data;
                }
              }
            } catch (e) {
              console.error(`Error cargando consumo de ${nombre}:`, e);
            }
          }
        }));
        // Pequeña pausa entre lotes
        if (i + batchSize < plantas.length) {
          await new Promise(resolve => setTimeout(resolve, 500));
        }
      }
      
      setConsumos(nuevosConsumos);
    } catch (error) {
      console.error('Error cargando consumos:', error);
    } finally {
      setCargando(false);
    }
  };

  // Cargar consumos cada 10 segundos
  useEffect(() => {
    cargarConsumos();
    const interval = setInterval(cargarConsumos, 10000);
    return () => clearInterval(interval);
  }, [monitorsAll]);

  // Filtrar SOLO monitores de la instancia "ENERGÍA"
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

    Object.keys(grupos).forEach(tipo => {
      metricas[tipo] = calcularMetricas(grupos[tipo]);
    });

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
      {/* BOTÓN FLOTANTE - ADMIN PLANTAS (VERSIÓN PEQUEÑA) */}
      <button
        onClick={() => {
          window.location.hash = '#/admin-plantas';
          window.location.reload(); // Forzar recarga para asegurar navegación
        }}
        style={{
          position: 'fixed',
          bottom: '20px',
          right: '20px',
          zIndex: 99999,
          width: '50px',
          height: '50px',
          background: '#3b82f6',
          color: 'white',
          border: 'none',
          borderRadius: '50%',
          cursor: 'pointer',
          fontSize: '24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 4px 10px rgba(59, 130, 246, 0.5)',
          transition: 'all 0.2s ease'
        }}
        onMouseEnter={(e) => {
          e.currentTarget.style.transform = 'scale(1.1)';
          e.currentTarget.style.background = '#2563eb';
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.transform = 'scale(1)';
          e.currentTarget.style.background = '#3b82f6';
        }}
        title="Ir a Administración de Plantas"
      >
        🔧
      </button>

      {/* Indicador de carga */}
      {cargando && (
        <div style={{ textAlign: 'center', padding: '8px', color: '#6b7280' }}>
          Actualizando consumos...
        </div>
      )}

      {/* TARJETAS POR TIPO */}
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
              consumosMap={consumos}
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
            consumosMap={consumos}
          />
        )}
      </div>

      {/* MODAL DE DETALLE DE EQUIPO */}
      <DetalleEquipo
        equipo={equipoSeleccionado}
        onClose={() => setEquipoSeleccionado(null)}
        consumoData={equipoSeleccionado ? consumos[equipoSeleccionado.info?.monitor_name] : null}
      />
    </div>
  );
}
