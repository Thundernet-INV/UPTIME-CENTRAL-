import React, { useState, useEffect } from 'react';
import PlantaDetail from "./PlantaDetail.jsx";
import { usePlantaData } from '../hooks/usePlantaData.js';

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

const MODELO_DEFAULT = '46-GI-30FW';
const CONSUMO_DEFAULT = 7.0;

export default function AdminPlantas() {
  const [plantasDetectadas, setPlantasDetectadas] = useState([]);
  const [mensaje, setMensaje] = useState({ texto: '', tipo: '' });
  const [plantaSeleccionada, setPlantaSeleccionada] = useState(null);
  
  // Usar el hook unificado
  const { 
    plantas, 
    estados, 
    consumos, 
    loading, 
    timestamp,
    simularEvento,
    resetearPlanta: resetearPlantaAPI,
    recargar
  } = usePlantaData();

  // Detectar plantas no configuradas
  useEffect(() => {
    const detectarPlantas = async () => {
      try {
        const res = await fetch('http://10.10.31.31:8080/api/summary');
        const data = await res.json();
        
        const monitoresEnergia = data.monitors.filter(m => 
          m.instance === 'Energia' && 
          m.info.monitor_name.startsWith('PLANTA')
        );
        
        const configMap = new Map(plantas.map(p => [p.nombre_monitor, true]));
        const detectadas = monitoresEnergia
          .filter(m => !configMap.has(m.info.monitor_name))
          .map(m => ({ nombre_monitor: m.info.monitor_name }));
        
        setPlantasDetectadas(detectadas);
      } catch (error) {
        console.error('Error detectando plantas:', error);
      }
    };

    if (plantas.length > 0) {
      detectarPlantas();
    }
  }, [plantas]);

  const handleSimularEvento = async (nombreMonitor, estado) => {
    const result = await simularEvento(nombreMonitor, estado);
    if (result.success) {
      mostrarMensaje(`✅ ${nombreMonitor} ${estado === 'UP' ? 'ENCENDIDA' : 'APAGADA'}`, 'success');
    } else {
      mostrarMensaje('❌ ' + result.error, 'error');
    }
  };

  const mostrarMensaje = (texto, tipo) => {
    setMensaje({ texto, tipo });
    setTimeout(() => setMensaje({ texto: '', tipo: '' }), 3000);
  };

  const handleAgregarPlanta = async (nombre_monitor) => {
    try {
      let sede = nombre_monitor
        .replace('PLANTA ELECTRICA ', '')
        .replace('PLANTA ', '')
        .trim();
      
      sede = sede.charAt(0).toUpperCase() + sede.slice(1).toLowerCase();
      
      const nuevaPlantaData = {
        nombre_monitor,
        sede,
        modelo: MODELO_DEFAULT,
        consumo_lh: CONSUMO_DEFAULT
      };
      
      const res = await fetch('http://10.10.31.31:8080/api/combustible/plantas', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(nuevaPlantaData)
      });
      
      const data = await res.json();
      if (data.success) {
        mostrarMensaje(`✅ Planta "${nombre_monitor}" agregada`, 'success');
        recargar(); // Recargar datos después de agregar
      } else {
        mostrarMensaje('❌ ' + data.error, 'error');
      }
    } catch (error) {
      mostrarMensaje('❌ Error al conectar con el servidor', 'error');
    }
  };

  const getEstadoPlanta = (nombreMonitor) => {
    const estado = estados[nombreMonitor];
    if (!estado) return { estado: 'DESCONOCIDO', color: '#6b7280', bg: '#e5e7eb' };
    
    if (estado.status === 'UP') {
      return { 
        estado: '🟢 ENCENDIDA', 
        color: '#16a34a', 
        bg: '#d1fae5',
        responseTime: estado.responseTime,
        lastCheck: estado.lastCheck
      };
    } else {
      return { 
        estado: '🔴 APAGADA', 
        color: '#dc2626', 
        bg: '#fee2e2',
        responseTime: estado.responseTime,
        lastCheck: estado.lastCheck
      };
    }
  };

  const plantasCombinadas = () => {
    const configMap = new Map(plantas.map(p => [p.nombre_monitor, p]));
    const result = [];
    
    plantas.forEach(p => result.push({ ...p, configurada: true }));
    
    plantasDetectadas.forEach(d => {
      if (!configMap.has(d.nombre_monitor)) {
        result.push({
          nombre_monitor: d.nombre_monitor,
          sede: '—',
          modelo: '—',
          consumo_lh: 0,
          configurada: false,
          detectada: true
        });
      }
    });
    
    return result.sort((a, b) => a.nombre_monitor.localeCompare(b.nombre_monitor));
  };

  const plantasUp = Object.values(estados).filter(e => e.status === 'UP').length;
  const listaCombinada = plantasCombinadas();
  
  // Calcular total de combustible
  const totalCombustible = Object.values(consumos).reduce((sum, p) => sum + (p.historico || 0), 0);

  if (loading) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <div className="spinner" style={{
          border: '4px solid #f3f3f3',
          borderTop: '4px solid #3b82f6',
          borderRadius: '50%',
          width: 40,
          height: 40,
          margin: '0 auto 20px',
          animation: 'spin 1s linear infinite'
        }} />
        <p>Detectando plantas...</p>
        <style>{`
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        `}</style>
      </div>
    );
  }

  return (
    <div style={{ padding: '24px' }}>
      <style>{`
        .admin-plantas table {
          width: 100%;
          border-collapse: collapse;
          background: white;
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 4px 6px rgba(0,0,0,0.05);
        }
        .dark-mode .admin-plantas table {
          background: #1a1e24;
        }
        .admin-plantas th {
          text-align: left;
          padding: 16px;
          background: #f3f4f6;
          border-bottom: 2px solid #e5e7eb;
          font-weight: 600;
        }
        .dark-mode .admin-plantas th {
          background: #2d3238;
          color: #e5e7eb;
          border-bottom-color: #374151;
        }
        .admin-plantas td {
          padding: 16px;
          border-bottom: 1px solid #e5e7eb;
        }
        .dark-mode .admin-plantas td {
          border-bottom-color: #374151;
          color: #e5e7eb;
        }
        .admin-plantas tr:hover {
          background: #f9fafb;
        }
        .dark-mode .admin-plantas tr:hover {
          background: #2d3238;
        }
        .badge {
          display: inline-block;
          padding: 4px 12px;
          border-radius: 999px;
          font-size: 0.8rem;
          font-weight: 600;
        }
        .btn-agregar {
          padding: 4px 12px;
          background: #3b82f6;
          color: white;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 0.8rem;
        }
        .btn-simular {
          padding: 4px 8px;
          border: none;
          border-radius: 4px;
          cursor: pointer;
          font-size: 0.7rem;
          font-weight: 600;
        }
        .consumo-actual {
          font-size: 1rem;
          font-weight: 600;
          color: #16a34a;
        }
        .mensaje {
          position: fixed;
          top: 20px;
          right: 20px;
          padding: 12px 24px;
          border-radius: 8px;
          z-index: 1000;
          box-shadow: 0 4px 6px rgba(0,0,0,0.1);
          animation: slideIn 0.3s ease;
        }
        .mensaje.success {
          background: #d1fae5;
          color: #065f46;
          border: 1px solid #a7f3d0;
        }
        .mensaje.error {
          background: #fee2e2;
          color: #991b1b;
          border: 1px solid #fecaca;
        }
        @keyframes slideIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        .estadistica {
          background: #f3f4f6;
          padding: 8px 16px;
          border-radius: 999px;
          font-size: 0.9rem;
        }
        .dark-mode .estadistica {
          background: #2d3238;
          color: #e5e7eb;
        }
        .total-consumo {
          background: #16a34a;
          color: white;
          padding: 8px 20px;
          border-radius: 999px;
          font-weight: 600;
        }
      `}</style>

      {mensaje.texto && (
        <div className={`mensaje ${mensaje.tipo}`}>
          {mensaje.texto}
        </div>
      )}

      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        marginBottom: 24,
        flexWrap: 'wrap',
        gap: 16
      }}>
        <h1 style={{ margin: 0 }}>⚡ Administración de Plantas Eléctricas</h1>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <span className="estadistica">
            📊 Configuradas: {plantas.length}
          </span>
          <span className="estadistica">
            🔍 Detectadas: {plantasDetectadas.length}
          </span>
          <span className="estadistica" style={{ 
            background: '#d1fae5', 
            color: '#065f46' 
          }}>
            🟢 Encendidas: {plantasUp}
          </span>
          <span className="total-consumo">
            ⛽ Total: {totalCombustible.toFixed(2)} L
          </span>
          
          {/* BOTÓN DE REPORTES */}
          <button
            onClick={() => window.location.hash = '#/reportes'}
            style={{
              padding: '8px 16px',
              background: '#16a34a',
              color: 'white',
              border: 'none',
              borderRadius: 6,
              cursor: 'pointer',
              fontSize: '0.9rem',
              display: 'flex',
              alignItems: 'center',
              gap: '6px'
            }}
          >
            📈 Ver Reportes
          </button>
          
          <button
            onClick={recargar}
            style={{
              padding: '8px 16px',
              background: '#3b82f6',
              color: 'white',
              border: 'none',
              borderRadius: 6,
              cursor: 'pointer',
              fontSize: '0.9rem'
            }}
          >
            🔄 Actualizar
          </button>
        </div>
      </div>

      <div className="admin-plantas">
        <table>
          <thead>
            <tr>
              <th>Monitor</th>
              <th>Sede</th>
              <th>Modelo</th>
              <th>Consumo L/h</th>
              <th>Estado</th>
              <th>Consumo Actual</th>
              <th>Histórico</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {listaCombinada.map(planta => {
              const estadoInfo = getEstadoPlanta(planta.nombre_monitor);
              const isConfigurada = planta.configurada;
              const consumoData = consumos[planta.nombre_monitor] || { sesionActual: 0, historico: 0 };
              const isUp = estadoInfo.estado.includes('🟢');
              
              return (
                <tr key={`${planta.nombre_monitor}-${timestamp}`}>
                  <td>
                    <strong>{planta.nombre_monitor}</strong>
                    {!isConfigurada && (
                      <span style={{
                        background: '#fef3c7',
                        color: '#92400e',
                        padding: '2px 8px',
                        borderRadius: 12,
                        fontSize: '0.7rem',
                        marginLeft: 8
                      }}>
                        Nueva
                      </span>
                    )}
                  </td>
                  <td>{planta.sede}</td>
                  <td>{planta.modelo}</td>
                  <td>{planta.consumo_lh} L/h</td>
                  <td>
                    <span className="badge" style={{
                      background: estadoInfo.bg,
                      color: estadoInfo.color
                    }}>
                      {estadoInfo.estado}
                    </span>
                  </td>
                  <td>
                    {isConfigurada ? (
                      <span className="consumo-actual" style={{ color: isUp ? "#16a34a" : "#6b7280" }}>
                        {consumoData.sesionActual.toFixed(3)} L
                      </span>
                    ) : (
                      <span style={{ color: '#6b7280' }}>—</span>
                    )}
                  </td>
                  <td>
                    {isConfigurada ? (
                      <span>
                        {consumoData.historico.toFixed(2)} L
                      </span>
                    ) : (
                      <span style={{ color: '#6b7280' }}>—</span>
                    )}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                      <button
                        className="btn-agregar"
                        onClick={() => setPlantaSeleccionada(planta)}
                        style={{ background: '#3b82f6' }}
                      >
                        Detalle
                      </button>
                      {isConfigurada && (
                        <>
                          <button
                            className="btn-simular"
                            onClick={() => handleSimularEvento(planta.nombre_monitor, 'UP')}
                            style={{ 
                              background: '#16a34a', 
                              color: 'white',
                              padding: '4px 8px'
                            }}
                            title="Simular encendido"
                          >
                            🔌 UP
                          </button>
                          <button
                            className="btn-simular"
                            onClick={() => handleSimularEvento(planta.nombre_monitor, 'DOWN')}
                            style={{ 
                              background: '#dc2626', 
                              color: 'white',
                              padding: '4px 8px'
                            }}
                            title="Simular apagado"
                          >
                            🔴 DOWN
                          </button>
                        </>
                      )}
                      {!isConfigurada && (
                        <button
                          className="btn-agregar"
                          onClick={() => handleAgregarPlanta(planta.nombre_monitor)}
                        >
                          Agregar
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {plantaSeleccionada && (
        <PlantaDetail
          planta={plantaSeleccionada}
          onClose={() => setPlantaSeleccionada(null)}
          onActualizar={recargar}
        />
      )}
    </div>
  );
}
