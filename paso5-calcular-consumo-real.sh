#!/bin/bash
# paso5-calcular-consumo-real.sh
# CALCULA EL CONSUMO EN TIEMPO REAL BASADO EN EL ESTADO ACTUAL

echo "====================================================="
echo "⛽ PASO 5: CALCULANDO CONSUMO EN TIEMPO REAL"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. ACTUALIZAR COMPONENTE CON CÁLCULO DE CONSUMO ==========
echo ""
echo "[2] Actualizando AdminPlantas.jsx con cálculo de consumo..."

# Reemplazar el archivo completo con la nueva versión
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

const MODELO_DEFAULT = '46-GI-30FW';
const CONSUMO_DEFAULT = 7.0;

export default function AdminPlantas() {
  const [plantas, setPlantas] = useState([]);
  const [plantasDetectadas, setPlantasDetectadas] = useState([]);
  const [loading, setLoading] = useState(true);
  const [mensaje, setMensaje] = useState({ texto: '', tipo: '' });
  const [estadosReales, setEstadosReales] = useState({});
  
  // ESTADO PARA EL CONSUMO ACUMULADO
  const [consumoAcumulado, setConsumoAcumulado] = useState(() => {
    const saved = localStorage.getItem('consumo_plantas');
    return saved ? JSON.parse(saved) : {};
  });

  // TIMESTAMP DE INICIO DE SESIÓN ACTUAL
  const [inicioSesion, setInicioSesion] = useState(() => {
    return Date.now();
  });

  // Cargar datos al inicio
  useEffect(() => {
    cargarTodo();
    // Actualizar cada 2 segundos para cálculo en tiempo real
    const interval = setInterval(actualizarEstados, 2000);
    return () => clearInterval(interval);
  }, []);

  // Guardar consumo acumulado cuando cambie
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
      const res = await fetch('http://10.10.31.31:8080/api/summary');
      const data = await res.json();
      
      const monitoresEnergia = data.monitors.filter(m => 
        m.instance === 'Energia' && 
        m.info.monitor_name.startsWith('PLANTA')
      );
      
      const estados = {};
      const detectadas = [];
      const ahora = Date.now();
      
      monitoresEnergia.forEach(m => {
        const nombre = m.info.monitor_name;
        const status = m.latest?.status === 1 ? 'UP' : 'DOWN';
        const responseTime = m.latest?.responseTime || 0;
        const lastCheck = m.latest?.timestamp || ahora;
        
        estados[nombre] = {
          status,
          responseTime,
          lastCheck
        };
        
        detectadas.push({ nombre_monitor: nombre });
      });
      
      // Actualizar consumo basado en el estado actual
      actualizarConsumo(estados);
      
      setEstadosReales(estados);
      setPlantasDetectadas(detectadas);
      
    } catch (error) {
      console.error('Error cargando estados:', error);
    }
  };

  const actualizarEstados = () => {
    cargarEstadosReales();
  };

  // ========== FUNCIÓN PRINCIPAL DE CÁLCULO DE CONSUMO ==========
  const actualizarConsumo = (nuevosEstados) => {
    setConsumoAcumulado(prev => {
      const nuevoConsumo = { ...prev };
      const ahora = Date.now();
      
      // Procesar cada planta
      Object.entries(nuevosEstados).forEach(([nombre, estado]) => {
        // Buscar la configuración de la planta
        const plantaConfig = plantas.find(p => p.nombre_monitor === nombre);
        if (!plantaConfig) return; // No configurada, no calculamos consumo
        
        const consumoPorHora = plantaConfig.consumo_lh || 7.0;
        const estadoAnterior = prev[nombre]?.estado;
        const ultimoCambio = prev[nombre]?.ultimoCambio || ahora;
        
        // Si estaba UP y ahora está DOWN, calcular consumo del período
        if (estadoAnterior === 'UP' && estado.status === 'DOWN') {
          const duracionHoras = (ahora - ultimoCambio) / (1000 * 60 * 60);
          const consumoSesion = duracionHoras * consumoPorHora;
          
          nuevoConsumo[nombre] = {
            ...prev[nombre],
            estado: estado.status,
            ultimoCambio: ahora,
            sesionActual: 0,
            historico: (prev[nombre]?.historico || 0) + consumoSesion,
            ultimaSesion: {
              inicio: prev[nombre]?.ultimoCambio || ahora,
              fin: ahora,
              consumo: consumoSesion
            }
          };
          
          console.log(`📊 ${nombre} se apagó - Consumió ${consumoSesion.toFixed(2)}L`);
        }
        // Si estaba DOWN y ahora UP, nueva sesión
        else if (estadoAnterior !== 'UP' && estado.status === 'UP') {
          nuevoConsumo[nombre] = {
            ...prev[nombre],
            estado: estado.status,
            ultimoCambio: ahora,
            sesionActual: 0,
            inicioSesion: ahora
          };
          
          console.log(`🔌 ${nombre} se encendió`);
        }
        // Si sigue UP, calcular consumo actual
        else if (estado.status === 'UP') {
          const duracionHoras = (ahora - (prev[nombre]?.ultimoCambio || ahora)) / (1000 * 60 * 60);
          const consumoSesion = duracionHoras * consumoPorHora;
          
          nuevoConsumo[nombre] = {
            ...prev[nombre],
            estado: estado.status,
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,
            sesionActual: consumoSesion,
            historico: prev[nombre]?.historico || 0
          };
        }
        // Si sigue DOWN, no cambia
        else {
          nuevoConsumo[nombre] = {
            ...prev[nombre],
            estado: estado.status,
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,
            sesionActual: 0,
            historico: prev[nombre]?.historico || 0
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

  const resetearTodo = () => {
    if (window.confirm('¿Resetear TODOS los contadores de consumo?')) {
      setConsumoAcumulado({});
      mostrarMensaje('✅ Todos los contadores reseteados', 'success');
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
  
  // Calcular total de combustible consumido
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
          font-size: 1.1rem;
          font-weight: 700;
          color: #16a34a;
        }
        .consumo-historico {
          font-size: 0.9rem;
          color: #6b7280;
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
            onClick={resetearTodo}
            style={{
              padding: '8px 16px',
              background: '#ef4444',
              color: 'white',
              border: 'none',
              borderRadius: 6,
              cursor: 'pointer',
              fontSize: '0.9rem'
            }}
          >
            Resetear Todos
          </button>
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
              <th>Consumo Actual</th>
              <th>Histórico Total</th>
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
                    {isConfigurada && isUp ? (
                      <span className="consumo-actual">
                        {consumoData.sesionActual.toFixed(2)} L
                      </span>
                    ) : (
                      <span style={{ color: '#6b7280' }}>—</span>
                    )}
                  </td>
                  <td>
                    {isConfigurada ? (
                      <span className="consumo-historico">
                        {consumoData.historico.toFixed(2)} L
                      </span>
                    ) : (
                      <span style={{ color: '#6b7280' }}>—</span>
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
                        className="btn-reset"
                        onClick={() => resetearPlanta(planta.nombre_monitor)}
                        disabled={isUp}
                        title={isUp ? 'No se puede resetear mientras está encendida' : 'Resetear contador'}
                      >
                        Resetear
                      </button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

echo "✅ AdminPlantas.jsx actualizado con cálculo de consumo"

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
echo "✅✅ CÁLCULO DE CONSUMO EN TIEMPO REAL ACTIVADO ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EL PANEL:"
echo "   • Calcula consumo automáticamente mientras la planta está UP"
echo "   • Guarda el consumo cuando la planta se apaga"
echo "   • Muestra consumo actual e histórico"
echo "   • Botón Resetear para volver a cero el contador"
echo "   • Los datos se guardan en localStorage"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
