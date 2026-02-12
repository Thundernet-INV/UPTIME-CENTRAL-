import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange, TIME_RANGE_CHANGE_EVENT } from "./TimeRangeSelector.jsx";

// Colores para modo claro y oscuro
const COLORS = {
  light: {
    bg: '#ffffff',
    text: '#1f2937',
    textSecondary: '#6b7280',
    border: '#e5e7eb',
    cardBg: '#f9fafb',
    hover: '#f3f4f6',
    chartGrid: '#e5e7eb',
    chartText: '#6b7280',
  },
  dark: {
    bg: '#0f1217',
    text: '#e5e7eb',
    textSecondary: '#94a3b8',
    border: '#2d3238',
    cardBg: '#1a1e24',
    hover: '#2d3238',
    chartGrid: '#2d3238',
    chartText: '#94a3b8',
  }
};

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
  // Detectar modo oscuro
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return document.body.classList.contains('dark-mode');
    }
    return false;
  });

  // Escuchar cambios en el modo oscuro
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

  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  const [rangeValue, setRangeValue] = useState(selectedRange.value);
  
  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log("📊 MultiServiceView - Rango cambiado a:", e.detail.label);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);
  
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

  // 🎯 MEJORA 2: Auto-seleccionar el primer servicio cuando se carga el componente
  useEffect(() => {
    if (services.length > 0 && !selectedService) {
      const primerServicio = services[0].name;
      console.log("🎯 Auto-seleccionando primer servicio:", primerServicio);
      setSelectedService(primerServicio);
    }
  }, [services, selectedService]);

  // 2) Cuando se selecciona un servicio, actualizar instancias disponibles
  useEffect(() => {
    if (!selectedService) {
      setSelectedInstances([]);
      return;
    }
    
    const service = services.find(s => s.name === selectedService);
    if (service) {
      const instancias = Array.from(service.instances).sort();
      console.log(`🏢 Servicio "${selectedService}" tiene ${instancias.length} sedes:`, instancias);
      setSelectedInstances(instancias);
    }
  }, [selectedService, services]);

  // 3) Cargar datos cuando cambia el servicio, las instancias o el rango
  useEffect(() => {
    let isMounted = true;
    
    const fetchData = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance({});
        return;
      }
      
      setLoading(true);
      console.log(`📊 Cargando datos para ${selectedService} - Rango: ${selectedRange.label} (${rangeValue}ms)`);
      
      try {
        const seriesData = {};
        
        await Promise.all(
          selectedInstances.map(async (instance) => {
            const data = await History.getSeriesForMonitor(
              instance,
              selectedService,
              rangeValue
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
        if (isMounted) {
          setLoading(false);
        }
      }
    };
    
    fetchData();
    
    return () => {
      isMounted = false;
    };
  }, [selectedService, selectedInstances, rangeValue, selectedRange.label]);

  // 4) Preparar datos para el chart
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
  
  // Estilos según modo
  const styles = {
    container: {
      padding: '24px',
      backgroundColor: isDark ? COLORS.dark.bg : COLORS.light.bg,
      color: isDark ? COLORS.dark.text : COLORS.light.text,
      borderRadius: '12px',
      transition: 'all 0.3s ease',
    },
    header: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: '24px',
    },
    title: {
      margin: 0,
      fontSize: '1.5rem',
      fontWeight: '600',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
    },
    rangeBadge: {
      padding: '6px 14px',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.cardBg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '20px',
      fontSize: '0.85rem',
      color: isDark ? COLORS.dark.textSecondary : COLORS.light.textSecondary,
    },
    select: {
      width: '100%',
      maxWidth: '400px',
      padding: '10px 12px',
      backgroundColor: isDark ? COLORS.dark.bg : COLORS.light.bg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '6px',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
      fontSize: '0.95rem',
      marginTop: '8px',
    },
    instancesContainer: {
      display: 'flex',
      gap: '8px',
      flexWrap: 'wrap',
      alignItems: 'center',
      marginTop: '12px',
      marginBottom: '20px',
    },
    instanceBadge: {
      padding: '4px 12px',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.cardBg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '16px',
      fontSize: '0.85rem',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
    },
    chartContainer: {
      minHeight: '400px',
      position: 'relative',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.cardBg,
      borderRadius: '8px',
      padding: '20px',
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      marginTop: '20px',
    },
    message: {
      textAlign: 'center',
      color: isDark ? COLORS.dark.textSecondary : COLORS.light.textSecondary,
      padding: '60px 20px',
    },
    loadingOverlay: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: isDark ? 'rgba(0,0,0,0.7)' : 'rgba(255,255,255,0.7)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      borderRadius: '8px',
      backdropFilter: 'blur(2px)',
    },
    loadingText: {
      padding: '8px 16px',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.bg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '20px',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
    }
  };

  return (
    <div style={styles.container}>
      {/* Header con título y rango actual */}
      <div style={styles.header}>
        <h2 style={styles.title}>Comparar servicio HTTP por sede</h2>
        <div style={styles.rangeBadge}>
          📊 {selectedRange.label}
        </div>
      </div>

      {/* Selector de servicio - ya viene preseleccionado */}
      <div>
        <label style={{ 
          display: 'block', 
          fontSize: '0.9rem',
          fontWeight: '600',
          color: isDark ? COLORS.dark.text : COLORS.light.text,
        }}>
          Servicio HTTP
        </label>
        <select
          value={selectedService}
          onChange={(e) => setSelectedService(e.target.value)}
          style={styles.select}
        >
          <option value="">Selecciona un servicio...</option>
          {services.map(service => (
            <option key={service.name} value={service.name}>
              {service.name} · {service.count} {service.count === 1 ? 'sede' : 'sedes'}
            </option>
          ))}
        </select>
      </div>

      {/* Instancias del servicio seleccionado */}
      {hasService && selectedInstances.length > 0 && (
        <div style={styles.instancesContainer}>
          <span style={{ fontSize: '0.9rem', color: isDark ? COLORS.dark.textSecondary : COLORS.light.textSecondary }}>
            Sedes monitorizadas:
          </span>
          {selectedInstances.map(instance => (
            <span
              key={instance}
              style={styles.instanceBadge}
            >
              {instance}
            </span>
          ))}
        </div>
      )}

      {/* Contenedor de la gráfica - SIEMPRE visible cuando hay servicio */}
      <div style={styles.chartContainer}>
        {!hasService && services.length > 0 && (
          <div style={styles.message}>
            Cargando servicio por defecto...
          </div>
        )}
        
        {hasService && selectedInstances.length === 0 && (
          <div style={styles.message}>
            Este servicio no está disponible en ninguna sede.
          </div>
        )}
        
        {hasService && selectedInstances.length > 0 && !hasSeries && !loading && (
          <div style={styles.message}>
            No hay datos históricos disponibles para {selectedRange.label.toLowerCase()}.
          </div>
        )}
        
        {hasService && selectedInstances.length > 0 && hasSeries && !loading && (
          <HistoryChart 
            mode="multi" 
            seriesMulti={chartSeries} 
            h={380}
            options={{
              scales: {
                x: {
                  grid: { color: isDark ? COLORS.dark.chartGrid : COLORS.light.chartGrid },
                  ticks: { color: isDark ? COLORS.dark.chartText : COLORS.light.chartText }
                },
                y: {
                  grid: { color: isDark ? COLORS.dark.chartGrid : COLORS.light.chartGrid },
                  ticks: { color: isDark ? COLORS.dark.chartText : COLORS.light.chartText }
                }
              },
              plugins: {
                legend: {
                  labels: { color: isDark ? COLORS.dark.chartText : COLORS.light.chartText }
                }
              }
            }}
          />
        )}
        
        {loading && (
          <div style={styles.loadingOverlay}>
            <span style={styles.loadingText}>
              Cargando datos para {selectedRange.label}...
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
