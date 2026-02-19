#!/bin/bash
# fix-adminplantas-completo.sh
# REEMPLAZA EL ARCHIVO ADMINPLANTAS.JSX CON VERSIÓN CORREGIDA

echo "====================================================="
echo "🔧 REEMPLAZANDO ADMINPLANTAS.JSX CON VERSIÓN CORREGIDA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.final.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. CREAR ARCHIVO NUEVO CON SINTAXIS CORRECTA ==========
echo ""
echo "[2] Creando nuevo AdminPlantas.jsx con sintaxis correcta..."

cat > "$ADMIN_FILE" << 'EOF'
import React, { useState, useEffect } from 'react';
import PlantaDetail from "./PlantaDetail.jsx";

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
  const [plantas, setPlantas] = useState([]);
  const [plantasDetectadas, setPlantasDetectadas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [mensaje, setMensaje] = useState({ texto: '', tipo: '' });
  const [estadosReales, setEstadosReales] = useState({});
  const [plantaSeleccionada, setPlantaSeleccionada] = useState(null);
  
  const [consumoAcumulado, setConsumoAcumulado] = useState(() => {
    const saved = localStorage.getItem('consumo_plantas');
    return saved ? JSON.parse(saved) : {};
  });

  useEffect(() => {
    cargarTodo();
    const interval = setInterval(actualizarEstados, 2000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    localStorage.setItem('consumo_plantas', JSON.stringify(consumoAcumulado));
  }, [consumoAcumulado]);

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
      console.log("📊 Cargando estados de plantas...");
      const res = await fetch('http://10.10.31.31:8080/api/summary');
      const data = await res.json();
      
      const monitoresEnergia = data.monitors.filter(m => 
        m.instance === 'Energia' && 
        m.info.monitor_name.startsWith('PLANTA')
      );
      
      const estados = {};
      const detectadas = [];
      
      monitoresEnergia.forEach(m => {
        const nombre = m.info.monitor_name;
        estados[nombre] = {
          status: m.latest?.status === 1 ? 'UP' : 'DOWN',
          responseTime: m.latest?.responseTime || 0,
          lastCheck: m.latest?.timestamp || Date.now()
        };
        detectadas.push({ nombre_monitor: nombre });
      });
      
      actualizarConsumo(estados);
      setEstadosReales(estados);
      setPlantasDetectadas(detectadas);
      console.log(`📊 Estados cargados: ${Object.keys(estados).length} plantas`);
      
    } catch (error) {
      console.error('Error cargando estados:', error);
    }
  };

  const actualizarEstados = () => {
    cargarEstadosReales();
  };

  const actualizarConsumo = (nuevosEstados) => {
    setConsumoAcumulado(prev => {
      const nuevoConsumo = { ...prev };
      const ahora = Date.now();
      
      Object.entries(nuevosEstados).forEach(([nombre, estado]) => {
        const plantaConfig = plantas.find(p => p.nombre_monitor === nombre);
        if (!plantaConfig) return;
        
        const consumoPorHora = plantaConfig.consumo_lh || 7.0;
        const estadoAnterior = prev[nombre]?.estado;
        const historicoAnterior = prev[nombre]?.historico || 0;
        
        if (estadoAnterior !== "UP" && estado.status === "UP") {
          console.log(`🔌 ${nombre} ENCENDIÓ`);
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: ahora,
            sesionActual: 0,
            historico: historicoAnterior,
            inicioSesion: ahora
          };
        }
        else if (estadoAnterior === "UP" && estado.status === "DOWN") {
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);
          const duracionHoras = duracionMs / (1000 * 60 * 60);
          const consumoSesion = duracionHoras * consumoPorHora;
          
          console.log(`🔴 ${nombre} APAGÓ - Consumió ${consumoSesion.toFixed(4)}L`);
          
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: ahora,
            sesionActual: 0,
            historico: historicoAnterior + consumoSesion,
            ultimaSesion: {
              inicio: prev[nombre]?.ultimoCambio,
              fin: ahora,
              consumo: consumoSesion,
              duracionMin: duracionMs / 60000
            }
          };
        }
        else if (estado.status === "UP") {
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);
          const duracionHoras = duracionMs / (1000 * 60 * 60);
          const consumoSesion = duracionHoras * consumoPorHora;
          
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,
            sesionActual: consumoSesion,
            historico: historicoAnterior
          };
          
          if (Math.floor(duracionMs / 1000) % 30 === 0) {
            console.log(`⚡ ${nombre} consumo actual: ${consumoSesion.toFixed(4)}L`);
          }
        }
        else {
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,
            sesionActual: 0,
            historico: historicoAnterior
          };
        }
      });
      
      return nuevoConsumo;
    });
  };

  const resetearPlanta = (nombre) => {
    if (window.confirm(`¿Resetear el contador de ${nombre}?`)) {
      setConsumoAcumulado(prev => {
        const nuevo = { ...prev };
        delete nuevo[nombre];
        return nuevo;
      });
      mostrarMensaje(`✅ Contador de ${nombre} reseteado`, 'success');
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
        cargarPlantasConfiguradas();
      } else {
        mostrarMensaje('❌ ' + data.error, 'error');
      }
    } catch (error) {
      mostrarMensaje('❌ Error al conectar con el servidor', 'error');
    }
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

  const plantasUp = Object.values(estadosReales).filter(e => e.status === 'UP').length;
  const listaCombinada = plantasCombinadas();
  const totalCombustible = Object.values(consumoAcumulado).reduce((sum, p) => sum + (p.historico || 0), 0);

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
        .btn-reset {
          padding: 4px 8px;
          background: #ef4444;
          color: white;
          border: none;
          border-radius: 4px;
          cursor: pointer;
          font-size: 0.7rem;
          margin-left: 8px;
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
          <button
            onClick={cargarEstadosReales}
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
              const consumoData = consumoAcumulado[planta.nombre_monitor] || { sesionActual: 0, historico: 0 };
              const isUp = estadoInfo.estado.includes('🟢');
              
              return (
                <tr key={planta.nombre_monitor} style={{
                  opacity: isConfigurada ? 1 : 0.8,
                  background: !isConfigurada ? '#fff3e0' : undefined
                }}>
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
                    <div style={{ display: 'flex', gap: 4 }}>
                      <button
                        className="btn-agregar"
                        onClick={() => setPlantaSeleccionada(planta)}
                        style={{ background: '#3b82f6' }}
                      >
                        Detalle
                      </button>
                      {isConfigurada && (
                        <button
                          className="btn-reset"
                          onClick={() => resetearPlanta(planta.nombre_monitor)}
                          disabled={isUp}
                          title={isUp ? 'No se puede resetear mientras está encendida' : 'Resetear contador'}
                        >
                          Resetear
                        </button>
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
          onActualizar={cargarPlantasConfiguradas}
        />
      )}
    </div>
  );
}
EOF

echo "✅ Nuevo AdminPlantas.jsx creado"

# ========== 3. VERIFICAR SINTAXIS ==========
echo ""
echo "[3] Verificando sintaxis..."
cd "$FRONTEND_DIR"
npx eslint --no-eslintrc "$ADMIN_FILE" 2>/dev/null && echo "✅ Sintaxis OK" || echo "⚠️ Puede haber otros errores"

# ========== 4. HACER BUILD ==========
echo ""
echo "[4] Intentando build nuevamente..."
npm run build

echo ""
echo "====================================================="
echo "✅✅ ARCHIVO REEMPLAZADO CON ÉXITO ✅✅"
echo "====================================================="
echo ""
