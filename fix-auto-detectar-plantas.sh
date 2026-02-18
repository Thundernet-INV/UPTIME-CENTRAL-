#!/bin/bash
# fix-auto-detectar-plantas.sh
# HACE QUE EL PANEL DETECTE AUTOMÁTICAMENTE LAS PLANTAS

echo "====================================================="
echo "🔧 HACIENDO QUE EL PANEL DETECTE PLANTAS AUTOMÁTICAMENTE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. ACTUALIZAR EL COMPONENTE ==========
echo ""
echo "[2] Actualizando AdminPlantas.jsx con auto-detección..."

cat > "$ADMIN_FILE" << 'EOF'
import React, { useState, useEffect } from 'react';

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

// Modelo por defecto para plantas nuevas
const MODELO_DEFAULT = '46-GI-30FW';
const CONSUMO_DEFAULT = 7.0;

export default function AdminPlantas() {
  const [plantas, setPlantas] = useState([]);
  const [plantasDetectadas, setPlantasDetectadas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [mensaje, setMensaje] = useState({ texto: '', tipo: '' });
  const [estadosReales, setEstadosReales] = useState({});
  const [modoEdicion, setModoEdicion] = useState(null);
  
  const [nuevaPlanta, setNuevaPlanta] = useState({
    nombre_monitor: '',
    sede: '',
    modelo: MODELO_DEFAULT,
    consumo_lh: CONSUMO_DEFAULT
  });

  // Cargar datos al inicio
  useEffect(() => {
    cargarTodo();
    // Actualizar cada 5 segundos
    const interval = setInterval(actualizarEstados, 5000);
    return () => clearInterval(interval);
  }, []);

  const cargarTodo = async () => {
    setLoading(true);
    try {
      await Promise.all([
        cargarPlantasConfiguradas(),
        cargarEstadosReales()
      ]);
    } catch (error) {
      console.error('Error cargando datos:', error);
    } finally {
      setLoading(false);
    }
  };

  const cargarPlantasConfiguradas = async () => {
    try {
      const res = await fetch('http://10.10.31.31:8080/api/combustible/plantas');
      const data = await res.json();
      if (data.success) {
        setPlantas(data.data);
      }
    } catch (error) {
      console.error('Error cargando plantas:', error);
    }
  };

  const cargarEstadosReales = async () => {
    try {
      // Obtener el summary completo
      const res = await fetch('http://10.10.31.31:8080/api/summary');
      const data = await res.json();
      
      // Filtrar monitores de la instancia Energia que empiezan con "PLANTA"
      const monitoresEnergia = data.monitors.filter(m => 
        m.instance === 'Energia' && 
        m.info.monitor_name.startsWith('PLANTA')
      );
      
      // Crear mapa de estados
      const estados = {};
      const detectadas = [];
      
      monitoresEnergia.forEach(m => {
        const nombre = m.info.monitor_name;
        estados[nombre] = {
          status: m.latest?.status === 1 ? 'UP' : 'DOWN',
          responseTime: m.latest?.responseTime || 0,
          lastCheck: m.latest?.timestamp || Date.now()
        };
        
        // Agregar a lista de detectadas
        detectadas.push({
          nombre_monitor: nombre,
          detectado: true
        });
      });
      
      setEstadosReales(estados);
      setPlantasDetectadas(detectadas);
      
    } catch (error) {
      console.error('Error cargando estados:', error);
    }
  };

  const actualizarEstados = () => {
    cargarEstadosReales();
  };

  const mostrarMensaje = (texto, tipo) => {
    setMensaje({ texto, tipo });
    setTimeout(() => setMensaje({ texto: '', tipo: '' }), 3000);
  };

  const handleAgregarPlanta = async (nombre_monitor) => {
    try {
      // Extraer sede del nombre (ej: "PLANTA ELECTRICA CABUDARE" -> "Cabudare")
      let sede = nombre_monitor
        .replace('PLANTA ELECTRICA ', '')
        .replace('PLANTA ', '')
        .trim();
      
      // Capitalizar primera letra
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
        cargarPlantasConfiguradas();
      } else {
        mostrarMensaje('❌ ' + data.error, 'error');
      }
    } catch (error) {
      mostrarMensaje('❌ Error al conectar con el servidor', 'error');
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    try {
      const res = await fetch('http://10.10.31.31:8080/api/combustible/plantas', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(nuevaPlanta)
      });
      
      const data = await res.json();
      if (data.success) {
        mostrarMensaje('✅ Planta agregada correctamente', 'success');
        setShowForm(false);
        setNuevaPlanta({ 
          nombre_monitor: '', 
          sede: '', 
          modelo: MODELO_DEFAULT, 
          consumo_lh: CONSUMO_DEFAULT 
        });
        cargarPlantasConfiguradas();
      } else {
        mostrarMensaje('❌ ' + data.error, 'error');
      }
    } catch (error) {
      mostrarMensaje('❌ Error al conectar con el servidor', 'error');
    }
  };

  const handleEditar = async (id, datosActualizados) => {
    try {
      // TODO: Implementar endpoint de edición
      mostrarMensaje('Función de edición próximamente', 'info');
    } catch (error) {
      mostrarMensaje('❌ Error al editar', 'error');
    }
  };

  const handleModeloChange = (modelo) => {
    setNuevaPlanta({
      ...nuevaPlanta,
      modelo,
      consumo_lh: MODELOS_CON_CONSUMO[modelo] || CONSUMO_DEFAULT
    });
  };

  const getEstadoPlanta = (nombreMonitor) => {
    const estado = estadosReales[nombreMonitor];
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

  // Combinar plantas configuradas con detectadas
  const plantasCombinadas = () => {
    const configMap = new Map(plantas.map(p => [p.nombre_monitor, p]));
    const result = [];
    
    // Primero las configuradas
    plantas.forEach(p => result.push({ ...p, configurada: true }));
    
    // Luego las detectadas no configuradas
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

  const plantasUp = Object.values(estadosReales).filter(e => e.status === 'UP').length;
  const listaCombinada = plantasCombinadas();

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
        .badge-configurada {
          background: #dbeafe;
          color: #1e40af;
        }
        .badge-no-configurada {
          background: #fef3c7;
          color: #92400e;
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
        .btn-agregar:hover {
          background: #2563eb;
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
      `}</style>

      {/* Mensaje flotante */}
      {mensaje.texto && (
        <div className={`mensaje ${mensaje.tipo}`}>
          {mensaje.texto}
        </div>
      )}

      {/* Header */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        marginBottom: 24,
        flexWrap: 'wrap',
        gap: 16
      }}>
        <h1 style={{ margin: 0 }}>⚡ Administración de Plantas Eléctricas</h1>
        <div style={{ display: 'flex', gap: 12 }}>
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
        </div>
      </div>

      {/* Tabla de plantas */}
      <div className="admin-plantas">
        <table>
          <thead>
            <tr>
              <th>Monitor</th>
              <th>Sede</th>
              <th>Modelo</th>
              <th>Consumo L/h</th>
              <th>Estado</th>
              <th>Latencia</th>
              <th>Último Check</th>
              <th>Acción</th>
            </tr>
          </thead>
          <tbody>
            {listaCombinada.map(planta => {
              const estadoInfo = getEstadoPlanta(planta.nombre_monitor);
              const isConfigurada = planta.configurada;
              
              return (
                <tr key={planta.nombre_monitor} style={{
                  opacity: isConfigurada ? 1 : 0.8,
                  background: !isConfigurada ? '#fff3e0' : undefined
                }}>
                  <td>
                    <strong>{planta.nombre_monitor}</strong>
                    {!isConfigurada && (
                      <span className="badge badge-no-configurada" style={{ marginLeft: 8 }}>
                        Nueva
                      </span>
                    )}
                  </td>
                  <td>
                    {isConfigurada ? planta.sede : (
                      <input
                        type="text"
                        placeholder="Sede"
                        style={{ width: '100%', padding: 4 }}
                        onChange={(e) => {
                          // Aquí podrías guardar temporalmente
                        }}
                      />
                    )}
                  </td>
                  <td>
                    {isConfigurada ? planta.modelo : (
                      <select
                        style={{ width: '100%', padding: 4 }}
                        onChange={(e) => {
                          // Aquí podrías guardar temporalmente
                        }}
                      >
                        <option value="">Seleccionar</option>
                        {Object.keys(MODELOS_CON_CONSUMO).map(m => (
                          <option key={m} value={m}>{m}</option>
                        ))}
                      </select>
                    )}
                  </td>
                  <td>
                    {isConfigurada ? `${planta.consumo_lh} L/h` : (
                      <input
                        type="number"
                        step="0.1"
                        placeholder="Consumo"
                        style={{ width: '100%', padding: 4 }}
                        defaultValue={CONSUMO_DEFAULT}
                      />
                    )}
                  </td>
                  <td>
                    <span className="badge" style={{
                      background: estadoInfo.bg,
                      color: estadoInfo.color
                    }}>
                      {estadoInfo.estado}
                    </span>
                  </td>
                  <td>
                    {estadoInfo.responseTime ? (
                      <span style={{ 
                        color: estadoInfo.responseTime < 10 ? '#16a34a' : '#d97706',
                        fontWeight: 600 
                      }}>
                        {estadoInfo.responseTime.toFixed(2)} ms
                      </span>
                    ) : (
                      <span style={{ color: '#6b7280' }}>—</span>
                    )}
                  </td>
                  <td>
                    {estadoInfo.lastCheck ? (
                      new Date(estadoInfo.lastCheck).toLocaleTimeString()
                    ) : (
                      '—'
                    )}
                  </td>
                  <td>
                    {!isConfigurada ? (
                      <button
                        className="btn-agregar"
                        onClick={() => handleAgregarPlanta(planta.nombre_monitor)}
                      >
                        Agregar
                      </button>
                    ) : (
                      <button
                        className="btn-agregar"
                        style={{ background: '#6b7280' }}
                        onClick={() => setModoEdicion(planta.id)}
                      >
                        Editar
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Botón flotante para agregar manual */}
      <button
        style={{
          position: 'fixed',
          bottom: 30,
          right: 30,
          width: 60,
          height: 60,
          borderRadius: 30,
          background: '#3b82f6',
          color: 'white',
          border: 'none',
          fontSize: 24,
          cursor: 'pointer',
          boxShadow: '0 4px 12px rgba(59,130,246,0.3)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 999
        }}
        onClick={() => setShowForm(!showForm)}
      >
        {showForm ? '✕' : '+'}
      </button>
    </div>
  );
}
EOF

echo "✅ AdminPlantas.jsx actualizado con auto-detección"

# ========== 3. REINICIAR FRONTEND ==========
echo ""
echo "[3] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ AUTO-DETECCIÓN DE PLANTAS ACTIVADA ✅✅"
echo "====================================================="
echo ""
echo "📊 Ahora el panel:"
echo "   • Muestra TODAS las plantas que empiezan con 'PLANTA'"
echo "   • Las no configuradas aparecen en naranja con botón 'Agregar'"
echo "   • PLANTA ELECTRICA CABUDARE debería aparecer como 🟢 ENCENDIDA"
echo "   • Las configuradas mantienen sus datos"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
