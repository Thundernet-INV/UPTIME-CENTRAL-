import { useSimpleRange } from "./SimpleRangeSelector.jsx";
import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";

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
  // ✅ UNA SOLA VEZ - NO DUPLICADO
  const range = useSimpleRange();
  
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState({});
  const [loading, setLoading] = useState(false);
  const [userTouched, setUserTouched] = useState(false);

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

  // 2) Auto-seleccionar primer servicio
  useEffect(() => {
    if (services.length > 0 && !selectedService) {
      setSelectedService(services[0].name);
    }
  }, [services, selectedService]);

  // 3) Obtener instancias del servicio seleccionado
  const instancesWithService = useMemo(() => {
    if (!selectedService) return [];
    const service = services.find(s => s.name === selectedService);
    return service ? Array.from(service.instances).sort() : [];
  }, [services, selectedService]);

  // 4) Seleccionar todas las sedes al cambiar servicio (si el usuario no ha intervenido)
  useEffect(() => {
    if (!userTouched && instancesWithService.length > 0) {
      setSelectedInstances(instancesWithService);
    }
  }, [selectedService, instancesWithService, userTouched]);

  // 5) Toggle de sedes
  const toggleInstance = (name) => {
    setUserTouched(true);
    setSelectedInstances(prev => 
      prev.includes(name)
        ? prev.filter(n => n !== name)
        : [...prev, name]
    );
  };

  // 6) Cargar datos - USA EL RANGO DEL SELECTOR
  useEffect(() => {
    let isMounted = true;
    
    const fetchData = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance({});
        return;
      }
      
      setLoading(true);
      console.log(`📊 Cargando ${selectedService} - ${selectedInstances.length} sedes (${range.label})`);
      
      try {
        const seriesData = {};
        
        await Promise.all(
          selectedInstances.map(async (instance) => {
            const data = await History.getSeriesForMonitor(
              instance,
              selectedService,
              range.hours
            );
            seriesData[instance] = Array.isArray(data) ? data : [];
          })
        );
        
        if (isMounted) {
          setSeriesByInstance(seriesData);
          console.log(`✅ Datos cargados: ${Object.keys(seriesData).length} sedes`);
        }
      } catch (error) {
        console.error("Error cargando datos:", error);
      } finally {
        if (isMounted) setLoading(false);
      }
    };
    
    fetchData();
    
    return () => { isMounted = false; };
  }, [selectedService, selectedInstances, range.hours, range.label]);

  // 7) Preparar datos para el chart
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
  
  // Detectar modo oscuro
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return document.body.classList.contains('dark-mode');
    }
    return false;
  });

  useEffect(() => {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === 'class') {
          setIsDark(document.body.classList.contains('dark-mode'));
        }
      });
    });
    
    observer.observe(document.body, { attributes: true });
    return () => observer.disconnect();
  }, []);

  return (
    <div style={{ 
      padding: '24px',
      backgroundColor: isDark ? '#0f1217' : '#ffffff',
      color: isDark ? '#e5e7eb' : '#1f2937',
      borderRadius: '12px',
    }}>
      {/* Header */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '24px'
      }}>
        <h2 style={{ 
          margin: 0, 
          fontSize: '1.5rem', 
          fontWeight: '600',
          color: isDark ? '#f1f5f9' : '#111827'
        }}>
          Comparar servicio HTTP por sede
        </h2>
        <div style={{
          padding: '6px 14px',
          backgroundColor: isDark ? '#1a1e24' : '#f3f4f6',
          border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
          borderRadius: '20px',
          fontSize: '0.85rem',
          color: isDark ? '#94a3b8' : '#6b7280'
        }}>
          📊 {range.label}
        </div>
      </div>

      {/* Selector de servicio */}
      <div style={{
        backgroundColor: isDark ? '#1a1e24' : '#f9fafb',
        border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
        borderRadius: '8px',
        padding: '16px',
        marginBottom: '16px'
      }}>
        <label style={{
          display: 'block',
          fontSize: '0.8rem',
          fontWeight: '600',
          textTransform: 'uppercase',
          color: isDark ? '#94a3b8' : '#6b7280',
          marginBottom: '8px'
        }}>
          Servicio HTTP
        </label>
        <select
          value={selectedService}
          onChange={(e) => {
            setSelectedService(e.target.value);
            setUserTouched(false);
          }}
          style={{
            width: '100%',
            maxWidth: '400px',
            padding: '10px 12px',
            backgroundColor: isDark ? '#0f1217' : '#ffffff',
            border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
            borderRadius: '6px',
            color: isDark ? '#e5e7eb' : '#1f2937',
            fontSize: '0.95rem',
            cursor: 'pointer'
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

      {/* Botones de sedes */}
      {selectedService && instancesWithService.length > 0 && (
        <div style={{
          backgroundColor: isDark ? '#1a1e24' : '#f9fafb',
          border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
          borderRadius: '8px',
          padding: '16px',
          marginBottom: '16px'
        }}>
          <span style={{
            display: 'block',
            fontSize: '0.8rem',
            fontWeight: '600',
            textTransform: 'uppercase',
            color: isDark ? '#94a3b8' : '#6b7280',
            marginBottom: '8px'
          }}>
            Sedes
          </span>
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            {instancesWithService.map((name) => {
              const isActive = selectedInstances.includes(name);
              return (
                <button
                  key={name}
                  onClick={() => toggleInstance(name)}
                  style={{
                    padding: '6px 14px',
                    borderRadius: '20px',
                    border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
                    background: isActive ? (isDark ? '#2563eb' : '#3b82f6') : 'transparent',
                    color: isActive ? 'white' : (isDark ? '#e5e7eb' : '#1f2937'),
                    fontSize: '0.85rem',
                    cursor: 'pointer',
                    transition: 'all 0.2s ease',
                  }}
                >
                  {name}
                </button>
              );
            })}
          </div>
          <div style={{ 
            marginTop: '8px', 
            fontSize: '0.75rem', 
            color: isDark ? '#94a3b8' : '#6b7280'
          }}>
            {selectedInstances.length} de {instancesWithService.length} sedes seleccionadas
          </div>
        </div>
      )}

      {/* Gráfica */}
      <div style={{ position: 'relative', minHeight: '380px' }}>
        {!selectedService && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: isDark ? '#94a3b8' : '#6b7280' }}>
            Selecciona un servicio HTTP para ver su comportamiento en todas las sedes.
          </div>
        )}
        
        {selectedService && selectedInstances.length === 0 && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: isDark ? '#94a3b8' : '#6b7280' }}>
            No hay sedes seleccionadas. Haz click en los botones para seleccionar sedes.
          </div>
        )}
        
        {selectedService && selectedInstances.length > 0 && !hasSeries && !loading && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: isDark ? '#94a3b8' : '#6b7280' }}>
            No hay datos históricos disponibles para {range.label.toLowerCase()}.
          </div>
        )}
        
        {selectedService && selectedInstances.length > 0 && hasSeries && !loading && (
          <HistoryChart 
            mode="multi" 
            seriesMulti={chartSeries} 
            h={380}
          />
        )}
        
        {loading && (
          <div style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: isDark ? 'rgba(0,0,0,0.7)' : 'rgba(255,255,255,0.7)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '8px',
            backdropFilter: 'blur(2px)',
          }}>
            <span style={{
              padding: '8px 16px',
              background: isDark ? '#1a1e24' : '#ffffff',
              border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
              borderRadius: '20px',
              color: isDark ? '#e5e7eb' : '#1f2937',
            }}>
              Cargando datos para {range.label}...
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
