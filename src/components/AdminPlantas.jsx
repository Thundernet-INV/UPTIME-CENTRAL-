// src/components/AdminPlantas.jsx - VERSIÓN OPTIMIZADA
import React, { useState, useMemo, useCallback, memo } from 'react';
import { usePlantaData } from '../hooks/usePlantaData.js';

// Componente de fila memoizado para evitar re-renders
const FilaPlanta = memo(({ planta, estado, consumo, onAbrirModal }) => {
  const isUp = estado?.text?.includes('🟢');
  
  return (
    <tr style={{ borderBottom: '1px solid #e5e7eb' }}>
      <td style={{ padding: '12px' }}><strong>{planta.nombre_monitor}</strong></td>
      <td style={{ padding: '12px' }}>{planta.sede}</td>
      <td style={{ padding: '12px' }}>{planta.modelo}</td>
      <td style={{ padding: '12px' }}>{planta.consumo_lh}</td>
      <td style={{ padding: '12px' }}>
        <span style={{ 
          background: estado?.bg || '#e5e7eb', 
          color: estado?.color || '#6b7280', 
          padding: '4px 12px', 
          borderRadius: 20,
          fontSize: '0.85rem'
        }}>
          {estado?.text || 'DESCONOCIDO'}
        </span>
      </td>
      <td style={{ 
        padding: '12px', 
        fontWeight: 600, 
        color: isUp ? '#16a34a' : '#6b7280' 
      }}>
        {consumo?.sesionActual?.toFixed(3) || '0'}L
      </td>
      <td style={{ padding: '12px', fontWeight: 600 }}>
        {consumo?.historico?.toFixed(2) || '0'}L
      </td>
      <td style={{ padding: '12px' }}>
        <button
          onClick={() => onAbrirModal(planta)}
          style={{ 
            padding: '6px 12px', 
            background: '#3b82f6', 
            color: 'white', 
            border: 'none', 
            borderRadius: 20, 
            cursor: 'pointer',
            fontSize: '0.85rem'
          }}
        >
          Detalle
        </button>
      </td>
    </tr>
  );
});

// Componente de tarjeta de sede memoizado
const TarjetaSede = memo(({ sede, data, onClick }) => (
  <div 
    style={{
      background: '#f3f4f6',
      padding: '12px',
      borderRadius: 12,
      border: '1px solid #e5e7eb',
      cursor: 'pointer',
      transition: 'all 0.2s'
    }}
    onClick={onClick}
    onMouseEnter={(e) => e.currentTarget.style.background = '#e5e7eb'}
    onMouseLeave={(e) => e.currentTarget.style.background = '#f3f4f6'}
  >
    <div style={{ fontWeight: 700, marginBottom: 4 }}>{sede}</div>
    <div style={{ fontSize: '0.85rem', color: '#4b5563' }}>
      {data.total} plantas · {data.consumo}L
    </div>
  </div>
));

const MODELOS_CON_CONSUMO = {
  '46-GI-30MDI': 6.5,
  '46-GI-33MDFW': 7.75,
  '46-GI-70DE': 15.6,
  '46-GI-70BM': 15.8,
  '46-GI-30FW': 7.0,
  '46-GI-25MDFW-X': 7.0,
  '46-GI-15MDQ': 4.4,
  '46-GI-25MDFW': 7.0,
  '46-GI-50FW': 11.0,
  '46-GI-75C-X': 13.1,
  '46-GI-75C': 13.1,
  'CU28LDE': 13.1,
  'JHON DEERE 65KVA': 15.0,
  'JYX24SA2': 5.0,
  'GI-30I-S': 7.75,
  'GI-55I-M': 11.0,
  '46-GI-40ZI': 9.0,
  '46-GI-240-Z': 50.0
};

export default function AdminPlantas() {
  const [plantaSeleccionada, setPlantaSeleccionada] = useState(null);
  const [editando, setEditando] = useState(false);
  const [datosEditados, setDatosEditados] = useState(null);
  const [filtroSede, setFiltroSede] = useState('todas');
  const [busqueda, setBusqueda] = useState('');
  const [mensaje, setMensaje] = useState(null);
  
  const { 
    plantas, 
    estados, 
    consumos, 
    sedes,
    actualizarPlanta,
    recargar
  } = usePlantaData();

  // Filtrar plantas (memoizado)
  const plantasFiltradas = useMemo(() => {
    let lista = [...plantas];
    
    if (filtroSede !== 'todas') {
      lista = lista.filter(p => p.sede === filtroSede);
    }
    
    if (busqueda) {
      const q = busqueda.toLowerCase();
      lista = lista.filter(p => 
        p.nombre_monitor.toLowerCase().includes(q)
      );
    }
    
    return lista.sort((a, b) => a.nombre_monitor.localeCompare(b.nombre_monitor));
  }, [plantas, filtroSede, busqueda]);

  // Resumen por sede (memoizado)
  const resumenPorSede = useMemo(() => {
    const resumen = {};
    plantas.forEach(p => {
      const sede = p.sede;
      if (!resumen[sede]) {
        resumen[sede] = { total: 0, consumo: 0 };
      }
      resumen[sede].total++;
      resumen[sede].consumo += consumos[p.nombre_monitor]?.historico || 0;
    });
    Object.keys(resumen).forEach(s => {
      resumen[s].consumo = resumen[s].consumo.toFixed(2);
    });
    return resumen;
  }, [plantas, consumos]);

  const totalEncendidas = useMemo(() => 
    Object.values(estados).filter(e => e?.status === 'UP').length, [estados]
  );

  const totalCombustible = useMemo(() => 
    plantasFiltradas.reduce((sum, p) => sum + (consumos[p.nombre_monitor]?.historico || 0), 0).toFixed(2), 
    [plantasFiltradas, consumos]
  );

  const getEstadoPlanta = useCallback((nombreMonitor) => {
    const estado = estados[nombreMonitor];
    if (!estado) return { text: 'DESCONOCIDO', color: '#6b7280', bg: '#e5e7eb' };
    return estado.status === 'UP' 
      ? { text: '🟢 ENCENDIDA', color: '#16a34a', bg: '#d1fae5' }
      : { text: '🔴 APAGADA', color: '#dc2626', bg: '#fee2e2' };
  }, [estados]);

  const handleAbrirModal = useCallback((planta) => {
    setPlantaSeleccionada(planta);
    setDatosEditados({ ...planta });
    setEditando(false);
  }, []);

  const handleCerrarModal = useCallback(() => {
    setPlantaSeleccionada(null);
    setEditando(false);
  }, []);

  const handleGuardarCambios = async () => {
    if (!datosEditados) return;
    
    const result = await actualizarPlanta(plantaSeleccionada.nombre_monitor, datosEditados);
    if (result.success) {
      setMensaje({ texto: '✅ Guardado', tipo: 'success' });
      handleCerrarModal();
      setTimeout(() => setMensaje(null), 2000);
    } else {
      setMensaje({ texto: '❌ Error', tipo: 'error' });
      setTimeout(() => setMensaje(null), 2000);
    }
  };

  return (
    <div style={{ padding: '20px', maxWidth: '1400px', margin: '0 auto' }}>
      {/* Mensaje flotante */}
      {mensaje && (
        <div style={{
          position: 'fixed',
          top: 20,
          right: 20,
          padding: '10px 20px',
          background: mensaje.tipo === 'success' ? '#d1fae5' : '#fee2e2',
          color: mensaje.tipo === 'success' ? '#065f46' : '#991b1b',
          borderRadius: 8,
          zIndex: 10000,
          boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
        }}>
          {mensaje.texto}
        </div>
      )}

      {/* Header */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        marginBottom: 20
      }}>
        <h1 style={{ margin: 0, fontSize: '1.5rem' }}>⚡ Plantas Eléctricas</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <span style={{ background: '#f3f4f6', padding: '6px 12px', borderRadius: 20, fontSize: '0.9rem' }}>
            📊 {plantas.length}
          </span>
          <span style={{ background: '#d1fae5', padding: '6px 12px', borderRadius: 20, color: '#065f46', fontSize: '0.9rem' }}>
            🟢 {totalEncendidas}
          </span>
          <span style={{ background: '#16a34a', padding: '6px 12px', borderRadius: 20, color: 'white', fontSize: '0.9rem' }}>
            ⛽ {totalCombustible}L
          </span>
          <button 
            onClick={() => window.location.hash = '#/reportes'}
            style={{ 
              padding: '6px 12px', 
              background: '#16a34a', 
              color: 'white', 
              border: 'none', 
              borderRadius: 20, 
              cursor: 'pointer',
              fontSize: '0.9rem'
            }}
          >
            📈 Reportes
          </button>
          <button 
            onClick={recargar}
            style={{ 
              padding: '6px 12px', 
              background: '#3b82f6', 
              color: 'white', 
              border: 'none', 
              borderRadius: 20, 
              cursor: 'pointer',
              fontSize: '0.9rem'
            }}
          >
            🔄
          </button>
        </div>
      </div>

      {/* Filtros */}
      <div style={{ 
        display: 'flex', 
        gap: 12, 
        marginBottom: 20, 
        padding: '12px', 
        background: '#f9fafb', 
        borderRadius: 12
      }}>
        <select 
          value={filtroSede}
          onChange={(e) => setFiltroSede(e.target.value)}
          style={{ 
            padding: '6px 12px', 
            borderRadius: 20, 
            border: '1px solid #e5e7eb',
            minWidth: '150px',
            fontSize: '0.9rem'
          }}
        >
          <option value="todas">🌍 Todas</option>
          {sedes.map(s => (
            <option key={s} value={s}>🏢 {s}</option>
          ))}
        </select>
        
        <input
          type="text"
          placeholder="Buscar..."
          value={busqueda}
          onChange={(e) => setBusqueda(e.target.value)}
          style={{ 
            flex: 1, 
            padding: '6px 12px', 
            borderRadius: 20, 
            border: '1px solid #e5e7eb',
            fontSize: '0.9rem'
          }}
        />
      </div>

      {/* Resumen por sede */}
      {filtroSede === 'todas' && (
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))',
          gap: 8,
          marginBottom: 20
        }}>
          {Object.entries(resumenPorSede).map(([sede, data]) => (
            <TarjetaSede 
              key={sede} 
              sede={sede} 
              data={data} 
              onClick={() => setFiltroSede(sede)}
            />
          ))}
        </div>
      )}

      {/* Tabla */}
      <div style={{ 
        overflowX: 'auto', 
        background: 'white', 
        borderRadius: 12, 
        boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
      }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.9rem' }}>
          <thead style={{ background: '#f3f4f6' }}>
            <tr>
              <th style={{ padding: '12px', textAlign: 'left' }}>Monitor</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Sede</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Modelo</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>L/h</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Estado</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Actual</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Hist.</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Acción</th>
            </tr>
          </thead>
          <tbody>
            {plantasFiltradas.map(p => (
              <FilaPlanta
                key={p.nombre_monitor}
                planta={p}
                estado={getEstadoPlanta(p.nombre_monitor)}
                consumo={consumos[p.nombre_monitor]}
                onAbrirModal={handleAbrirModal}
              />
            ))}
          </tbody>
        </table>
      </div>

      {/* Modal simplificado */}
      {plantaSeleccionada && (
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
          zIndex: 99999,
          padding: '20px'
        }}>
          <div style={{
            background: 'white',
            borderRadius: 12,
            width: '90%',
            maxWidth: 500,
            padding: 20
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 15 }}>
              <h3 style={{ margin: 0 }}>
                {editando ? '✏️ Editar' : plantaSeleccionada.nombre_monitor}
              </h3>
              <button onClick={handleCerrarModal} style={{ background: 'none', border: 'none', fontSize: 20, cursor: 'pointer' }}>×</button>
            </div>

            {!editando ? (
              <>
                <div style={{ marginBottom: 15 }}>
                  <p><strong>Sede:</strong> {plantaSeleccionada.sede}</p>
                  <p><strong>Modelo:</strong> {plantaSeleccionada.modelo}</p>
                  <p><strong>Consumo:</strong> {plantaSeleccionada.consumo_lh} L/h</p>
                  <p><strong>Estado:</strong> {getEstadoPlanta(plantaSeleccionada.nombre_monitor).text}</p>
                </div>
                <button
                  onClick={() => setEditando(true)}
                  style={{ padding: '8px 16px', background: '#3b82f6', color: 'white', border: 'none', borderRadius: 6, width: '100%', cursor: 'pointer' }}
                >
                  ✏️ Editar
                </button>
              </>
            ) : (
              <>
                <div style={{ marginBottom: 15 }}>
                  <input
                    type="text"
                    placeholder="Nombre"
                    value={datosEditados?.nombre_monitor || ''}
                    onChange={(e) => setDatosEditados({...datosEditados, nombre_monitor: e.target.value})}
                    style={{ width: '100%', padding: 8, marginBottom: 8, border: '1px solid #e5e7eb', borderRadius: 4 }}
                  />
                  <input
                    type="text"
                    placeholder="Sede"
                    value={datosEditados?.sede || ''}
                    onChange={(e) => setDatosEditados({...datosEditados, sede: e.target.value})}
                    style={{ width: '100%', padding: 8, marginBottom: 8, border: '1px solid #e5e7eb', borderRadius: 4 }}
                  />
                  <select
                    value={datosEditados?.modelo || ''}
                    onChange={(e) => setDatosEditados({...datosEditados, modelo: e.target.value})}
                    style={{ width: '100%', padding: 8, marginBottom: 8, border: '1px solid #e5e7eb', borderRadius: 4 }}
                  >
                    <option value="">Modelo</option>
                    {Object.keys(MODELOS_CON_CONSUMO).map(m => (
                      <option key={m} value={m}>{m}</option>
                    ))}
                  </select>
                  <input
                    type="number"
                    step="0.1"
                    placeholder="Consumo L/h"
                    value={datosEditados?.consumo_lh || ''}
                    onChange={(e) => setDatosEditados({...datosEditados, consumo_lh: parseFloat(e.target.value)})}
                    style={{ width: '100%', padding: 8, border: '1px solid #e5e7eb', borderRadius: 4 }}
                  />
                </div>
                <button
                  onClick={handleGuardarCambios}
                  style={{ padding: '8px 16px', background: '#16a34a', color: 'white', border: 'none', borderRadius: 6, width: '100%', cursor: 'pointer' }}
                >
                  💾 Guardar
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
