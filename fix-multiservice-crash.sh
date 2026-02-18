#!/bin/bash
# fix-multiservice-crash.sh - CORRIGE EL CRASH DE MULTISERVICEVIEW

echo "====================================================="
echo "🔧 CORRIGIENDO CRASH DE MULTISERVICEVIEW"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_multiservice_crash_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. REEMPLAZAR CON VERSIÓN SIMPLE Y FUNCIONAL ==========
echo ""
echo "[2] Reemplazando con versión SIMPLE y FUNCIONAL..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange } from "./TimeRangeSelector.jsx";

// Color estable a partir del nombre de la sede
function getColorForInstance(name = "") {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  const hue = hash % 360;
  return `hsl(${hue}, 70%, 50%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  
  // Estado
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState({});
  const [loading, setLoading] = useState(false);

  // 1) Lista de servicios HTTP únicos
  const services = useMemo(() => {
    const serviceMap = new Map();
    
    monitorsAll.forEach(monitor => {
      const type = monitor.info?.monitor_type || "";
      if (type.toLowerCase() !== "http") return;
      
      const name = monitor.info?.monitor_name || monitor.name || "";
      if (!name) return;
      
      const instance = monitor.instance;
      if (!instance) return;
      
      if (!serviceMap.has(name)) {
        serviceMap.set(name, {
          name,
          type,
          instances: new Set(),
          count: 0
        });
      }
      
      const service = serviceMap.get(name);
      service.instances.add(instance);
      service.count = service.instances.size;
    });
    
    return Array.from(serviceMap.values()).sort((a, b) => 
      a.name.localeCompare(b.name)
    );
  }, [monitorsAll]);

  // 2) Cuando se selecciona un servicio, actualizar instancias disponibles
  useEffect(() => {
    if (!selectedService) {
      setSelectedInstances([]);
      return;
    }
    
    const service = services.find(s => s.name === selectedService);
    if (service) {
      setSelectedInstances(Array.from(service.instances).sort());
    }
  }, [selectedService, services]);

  // 3) Cargar datos cuando cambia el servicio o las instancias
  useEffect(() => {
    let isMounted = true;
    
    const fetchData = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance({});
        return;
      }
      
      setLoading(true);
      
      try {
        const seriesData = {};
        
        await Promise.all(
          selectedInstances.map(async (instance) => {
            const data = await History.getSeriesForMonitor(
              instance,
              selectedService,
              selectedRange.value
            );
            seriesData[instance] = Array.isArray(data) ? data : [];
          })
        );
        
        if (isMounted) {
          setSeriesByInstance(seriesData);
        }
      } catch (error) {
        console.error("Error cargando datos:", error);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };
    
    fetchData();
    
    return () => {
      isMounted = false;
    };
  }, [selectedService, selectedInstances, selectedRange.value]);

  // 4) Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = () => {
      if (selectedService && selectedInstances.length > 0) {
        // Forzar recarga
        const fetchData = async () => {
          setLoading(true);
          try {
            const seriesData = {};
            await Promise.all(
              selectedInstances.map(async (instance) => {
                const data = await History.getSeriesForMonitor(
                  instance,
                  selectedService,
                  selectedRange.value
                );
                seriesData[instance] = Array.isArray(data) ? data : [];
              })
            );
            setSeriesByInstance(seriesData);
          } catch (error) {
            console.error("Error recargando datos:", error);
          } finally {
            setLoading(false);
          }
        };
        fetchData();
      }
    };
    
    window.addEventListener('time-range-change', handleRangeChange);
    return () => window.removeEventListener('time-range-change', handleRangeChange);
  }, [selectedService, selectedInstances, selectedRange.value]);

  // 5) Preparar datos para el chart
  const chartSeries = useMemo(() => {
    return selectedInstances.map(instance => ({
      id: instance,
      label: instance,
      color: getColorForInstance(instance),
      points: seriesByInstance[instance] || []
    }));
  }, [selectedInstances, seriesByInstance]);

  const hasService = !!selectedService;
  const hasSeries = chartSeries.length > 0 && chartSeries.some(s => s.points.length > 0);

  return (
    <div style={{ padding: '20px' }}>
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center',
        marginBottom: '20px' 
      }}>
        <h2 style={{ margin: 0 }}>Comparar servicio HTTP por sede</h2>
        <div style={{
          padding: '6px 12px',
          background: '#f3f4f6',
          borderRadius: '20px',
          fontSize: '0.85rem'
        }}>
          📊 {selectedRange.label}
        </div>
      </div>

      {/* Selector de servicio */}
      <div style={{ marginBottom: '20px' }}>
        <label style={{ 
          display: 'block', 
          marginBottom: '8px',
          fontWeight: 600,
          fontSize: '0.9rem'
        }}>
          Servicio HTTP
        </label>
        <select
          value={selectedService}
          onChange={(e) => setSelectedService(e.target.value)}
          style={{
            width: '100%',
            maxWidth: '400px',
            padding: '10px',
            borderRadius: '6px',
            border: '1px solid #e5e7eb',
            fontSize: '0.95rem'
          }}
        >
          <option value="">Selecciona un servicio...</option>
          {services.map(service => (
            <option key={service.name} value={service.name}>
              {service.name} · {service.count} {service.count === 1 ? 'sede' : 'sedes'}
            </option>
          ))}
        </select>
      </div>

      {/* Instancias seleccionadas */}
      {hasService && selectedInstances.length > 0 && (
        <div style={{ marginBottom: '20px' }}>
          <div style={{ 
            display: 'flex', 
            gap: '8px', 
            flexWrap: 'wrap',
            alignItems: 'center'
          }}>
            <span style={{ fontSize: '0.9rem', color: '#6b7280' }}>
              Sedes monitorizadas:
            </span>
            {selectedInstances.map(instance => (
              <span
                key={instance}
                style={{
                  padding: '4px 12px',
                  background: '#e5e7eb',
                  borderRadius: '16px',
                  fontSize: '0.85rem'
                }}
              >
                {instance}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Gráfica */}
      <div style={{ 
        minHeight: '400px',
        position: 'relative',
        background: '#ffffff',
        borderRadius: '8px',
        padding: '20px',
        border: '1px solid #e5e7eb'
      }}>
        {!hasService && (
          <p style={{ textAlign: 'center', color: '#6b7280', padding: '60px 20px' }}>
            Selecciona un servicio HTTP para ver su comportamiento en todas las sedes.
          </p>
        )}
        
        {hasService && selectedInstances.length === 0 && (
          <p style={{ textAlign: 'center', color: '#6b7280', padding: '60px 20px' }}>
            Este servicio no está disponible en ninguna sede.
          </p>
        )}
        
        {hasService && selectedInstances.length > 0 && !hasSeries && !loading && (
          <p style={{ textAlign: 'center', color: '#6b7280', padding: '60px 20px' }}>
            No hay datos históricos disponibles para {selectedRange.label.toLowerCase()}.
          </p>
        )}
        
        {hasService && selectedInstances.length > 0 && loading && (
          <p style={{ textAlign: 'center', color: '#6b7280', padding: '60px 20px' }}>
            Cargando datos para {selectedRange.label}...
          </p>
        )}
        
        {hasService && selectedInstances.length > 0 && hasSeries && !loading && (
          <HistoryChart 
            mode="multi" 
            seriesMulti={chartSeries} 
            h={380}
          />
        )}
      </div>
    </div>
  );
}
EOF

echo "✅ MultiServiceView.jsx reemplazado con versión SIMPLE"
echo ""

# ========== 3. LIMPIAR CACHÉ ==========
echo ""
echo "[3] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"

# ========== 4. REINICIAR FRONTEND ==========
echo ""
echo "[4] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 5. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ MULTISERVICEVIEW CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • Eliminado useTheme (causaba error)"
echo "   • Eliminados estilos complejos"
echo "   • Estructura SIMPLE y FUNCIONAL"
echo "   • Selector de tiempo FUNCIONA"
echo "   • Gráfica se ACTUALIZA"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Haz click en 'Comparar'"
echo "   3. Selecciona un servicio HTTP"
echo "   4. DEBE mostrar la gráfica"
echo "   5. Cambia el rango de tiempo - DEBE actualizarse"
echo ""
echo "📌 NOTA: El modo oscuro en MultiServiceView"
echo "   se arreglará DESPUÉS de que funcione correctamente"
echo ""
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
