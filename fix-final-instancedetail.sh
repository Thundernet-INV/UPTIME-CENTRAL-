#!/bin/bash
# fix-final-instancedetail.sh - CORREGIR INSTANCEDETAIL.JSX Y MULTISERVICEVIEW.JSX

echo "====================================================="
echo "🔧 CORRECCIÓN FINAL - ELIMINAR HOOKS DUPLICADOS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_final_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CORREGIR INSTANCEDETAIL.JSX ==========
echo "[2] Corrigiendo InstanceDetail.jsx - ELIMINAR HOOKS DUPLICADOS..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import { useTimeRange } from "./TimeRangeSelector.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  // ✅ UNA SOLA VEZ - NO DUPLICADO
  const range = useTimeRange();
  
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  // Refresco periódico
  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // ✅ PROMEDIO DE SEDE - USA EL RANGO DEL SELECTOR
  useEffect(() => {
    let alive = true;
    
    const fetchAvg = async () => {
      try {
        console.log(`🏢 Cargando promedio de ${instanceName} (${range.label})`);
        const series = await History.getAvgSeriesByInstance(instanceName, range.value);
        if (alive) {
          setAvgSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series?.length || 0} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (alive) setAvgSeries([]);
      }
    };
    
    fetchAvg();
    
    return () => { alive = false; };
  }, [instanceName, range.value, range.label, tick]);

  // ✅ MONITORES INDIVIDUALES - USA EL RANGO DEL SELECTOR
  useEffect(() => {
    let alive = true;
    
    const fetchMonitors = async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const series = await History.getSeriesForMonitor(
              instanceName,
              name,
              range.value
            );
            return [name, series || []];
          })
        );
        
        if (alive) {
          setSeriesMonMap(new Map(entries));
        }
      } catch (error) {
        console.error(`Error cargando monitores de ${instanceName}:`, error);
        if (alive) setSeriesMonMap(new Map());
      }
    };
    
    fetchMonitors();
    
    return () => { alive = false; };
  }, [instanceName, group.length, range.value, range.label, tick]);

  // Datos para la gráfica
  const chartData = focus 
    ? seriesMonMap.get(focus) || [] 
    : avgSeries;

  return (
    <div className="instance-detail-page">
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
        <span style={{
          marginLeft: '12px',
          padding: '4px 12px',
          background: 'var(--bg-tertiary, #f3f4f6)',
          borderRadius: '16px',
          fontSize: '0.75rem',
          color: 'var(--text-secondary, #6b7280)'
        }}>
          📊 {range.label}
        </span>
      </div>

      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button
              className="k-btn k-btn--ghost k-chip-action"
              onClick={() => setFocus(null)}
            >
              Ver promedio
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            <span>📊 <strong>Promedio de {instanceName}</strong></span>
          </div>
        )}
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          <HistoryChart
            mode={focus ? "monitor" : "instance"}
            seriesMon={chartData}
            title={focus || `Promedio de ${instanceName}`}
          />

          <div className="instance-detail-actions">
            <button
              className="k-btn k-btn--danger"
              onClick={() => onHideAll?.(instanceName)}
            >
              Ocultar todos
            </button>
            <button
              className="k-btn k-btn--ghost"
              onClick={() => onUnhideAll?.(instanceName)}
            >
              Mostrar todos
            </button>
          </div>
        </div>

        {group.map((m, i) => {
          const name = m.info?.monitor_name ?? "";
          const seriesMon = seriesMonMap.get(name) ?? [];
          const isSelected = focus === name;
          
          return (
            <div
              key={name || i}
              className={`instance-detail-service-card ${isSelected ? 'selected' : ''}`}
              onClick={() => setFocus(name)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  setFocus(name);
                }
              }}
              style={{
                cursor: 'pointer',
                border: isSelected ? '2px solid #3b82f6' : '1px solid transparent',
                transition: 'all 0.2s ease'
              }}
            >
              <ServiceCard service={m} series={seriesMon} />
            </div>
          );
        })}
      </section>
    </div>
  );
}
EOF

echo "✅ InstanceDetail.jsx corregido - 1 SOLO hook useTimeRange()"
echo ""

# ========== 3. CORREGIR MULTISERVICEVIEW.JSX ==========
echo "[3] Corrigiendo MultiServiceView.jsx - ELIMINAR HOOKS DUPLICADOS..."

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
  // ✅ UNA SOLA VEZ - NO DUPLICADO
  const range = useTimeRange();
  
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
              range.value
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
  }, [selectedService, selectedInstances, range.value, range.label]);

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
EOF

echo "✅ MultiServiceView.jsx corregido - 1 SOLO hook useTimeRange()"
echo ""

# ========== 4. LIMPIAR CACHÉ ==========
echo "[4] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 5. REINICIAR FRONTEND ==========
echo "[5] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 6. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CORRECCIÓN FINAL APLICADA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🏢 InstanceDetail.jsx: 1 SOLO hook useTimeRange()"
echo "   2. 📊 MultiServiceView.jsx: 1 SOLO hook useTimeRange()"
echo "   3. ✅ TODOS los hooks duplicados ELIMINADOS"
echo "   4. ✅ El selector de rango funciona en AMBOS componentes"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ EL DASHBOARD DEBE CARGAR SIN ERRORES"
echo "   3. ✅ Ve a 'Comparar' - DEBE FUNCIONAR"
echo "   4. ✅ Entra a Caracas - DEBE MOSTRAR PROMEDIO"
echo "   5. ✅ Cambia el selector 📊 - TODAS LAS GRÁFICAS SE ACTUALIZAN"
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
