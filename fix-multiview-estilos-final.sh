#!/bin/bash
# fix-multiview-estilos-final.sh - RESTAURAR ESTILOS ORIGINALES Y CORREGIR DESELECCIÓN

echo "====================================================="
echo "🎨 RESTAURANDO ESTILOS ORIGINALES DE MULTISERVICEVIEW"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_multiview_estilos_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. REEMPLAZAR MULTISERVICEVIEW.JSX CON ESTILOS ORIGINALES ==========
echo "[2] Restaurando MultiServiceView.jsx con ESTILOS ORIGINALES y SELECCIÓN PERSISTENTE..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useRef, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange, TIME_RANGE_CHANGE_EVENT } from "./TimeRangeSelector.jsx";

// Color estable a partir del nombre de la sede (MISMO ESTILO ORIGINAL)
function getColorForInstance(name = "") {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  const hue = hash % 360;
  const saturation = 70;
  const lightness = 50;
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  const [rangeValue, setRangeValue] = useState(selectedRange.value);

  // ESTADO PERSISTENTE - usar ref para evitar re-renders innecesarios
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState({});
  const [loading, setLoading] = useState(false);
  
  // Flag para controlar si el usuario ha interactuado con las sedes
  const [userTouched, setUserTouched] = useState(false);
  const prevServiceRef = useRef("");

  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log(`📊 MultiServiceView - Rango cambiado a: ${e.detail.label}`);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  // 1) Lista de servicios HTTP únicos - MISMA LÓGICA ORIGINAL
  const services = useMemo(() => {
    const map = new Map();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue;

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (!name) continue;

      const type = typeRaw.toLowerCase();
      if (!map.has(name)) {
        map.set(name, { name, type, count: 0, instances: new Set() });
      }
      map.get(name).count += 1;
      if (m.instance) {
        map.get(name).instances.add(m.instance);
      }
    }
    return Array.from(map.values()).sort((a, b) =>
      a.name.localeCompare(b.name, "es", { sensitivity: "base" })
    );
  }, [monitorsAll]);

  // 2) Auto-seleccionar primer servicio SOLO si no hay ninguno seleccionado
  useEffect(() => {
    if (services.length > 0 && !selectedService) {
      const primerServicio = services[0].name;
      console.log("🎯 Auto-seleccionando primer servicio:", primerServicio);
      setSelectedService(primerServicio);
    }
  }, [services, selectedService]);

  // 3) Obtener instancias del servicio seleccionado
  const instancesWithService = useMemo(() => {
    if (!selectedService) return [];
    const service = services.find(s => s.name === selectedService);
    return service ? Array.from(service.instances).sort() : [];
  }, [services, selectedService]);

  // 4) 🟢 CORREGIDO: SELECCIÓN PERSISTENTE - NO se resetea al actualizar
  useEffect(() => {
    // Solo cuando cambia el servicio Y el usuario NO ha tocado las sedes
    if (!userTouched && selectedService && instancesWithService.length > 0) {
      console.log(`🏢 Seleccionando TODAS las sedes para ${selectedService}`);
      setSelectedInstances(instancesWithService);
    }
    
    // Actualizar ref del servicio anterior
    prevServiceRef.current = selectedService;
  }, [selectedService, instancesWithService, userTouched]);

  // 5) 🟢 RESETEAR flag SOLO cuando el usuario CAMBIA ACTIVAMENTE de servicio
  const handleServiceChange = (e) => {
    const newService = e.target.value;
    setSelectedService(newService);
    setUserTouched(false); // Resetear flag SOLO al cambiar servicio manualmente
  };

  // 6) 🟢 BOTONES DE SEDES - ESTILO ORIGINAL
  const toggleInstance = (name) => {
    setUserTouched(true); // Marcar que el usuario ha interactuado
    setSelectedInstances(prev => 
      prev.includes(name)
        ? prev.filter(n => n !== name)
        : [...prev, name]
    );
  };

  // 7) Cargar datos cuando cambia el servicio, sedes o rango
  useEffect(() => {
    let isMounted = true;
    
    const fetchData = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance({});
        return;
      }
      
      setLoading(true);
      console.log(`📊 Cargando datos para ${selectedService} - ${selectedInstances.length} sedes (${selectedRange.label})`);
      
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

  // 8) Preparar datos para el chart
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
    <div className="multi-view" style={{ 
      padding: '24px',
      backgroundColor: isDark ? '#0f1217' : '#ffffff',
      color: isDark ? '#e5e7eb' : '#1f2937',
      borderRadius: '12px',
      transition: 'all 0.3s ease'
    }}>
      {/* Header con título y selector de rango - ESTILO ORIGINAL */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '24px'
      }}>
        <h2 className="multi-view-title" style={{ 
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
          📊 {selectedRange.label}
        </div>
      </div>

      {/* FILTROS - ESTILO ORIGINAL */}
      <section className="filters-toolbar" aria-label="Filtros de comparación" style={{
        backgroundColor: isDark ? '#1a1e24' : '#f9fafb',
        border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
        borderRadius: '8px',
        padding: '16px',
        marginBottom: '16px'
      }}>
        {/* Servicio HTTP - SELECTOR ORIGINAL */}
        <div className="filter-group">
          <label className="filter-label" htmlFor="service-select" style={{
            display: 'block',
            fontSize: '0.8rem',
            fontWeight: '600',
            textTransform: 'uppercase',
            letterSpacing: '0.05em',
            color: isDark ? '#94a3b8' : '#6b7280',
            marginBottom: '8px'
          }}>
            Servicio HTTP
          </label>
          <select
            id="service-select"
            className="filter-select"
            value={selectedService}
            onChange={handleServiceChange}
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
            <option value="">Selecciona un servicio…</option>
            {services.map((s) => (
              <option key={s.name} value={s.name}>
                {s.name} {s.type ? `(${s.type.toUpperCase()})` : ""} · {s.count} monitores
              </option>
            ))}
          </select>
        </div>

        {/* 🟢 BOTONES DE SEDES - ESTILO ORIGINAL */}
        {hasService && instancesWithService.length > 0 && (
          <div className="filter-group" style={{ marginTop: '16px' }}>
            <span className="filter-label" style={{
              display: 'block',
              fontSize: '0.8rem',
              fontWeight: '600',
              textTransform: 'uppercase',
              letterSpacing: '0.05em',
              color: isDark ? '#94a3b8' : '#6b7280',
              marginBottom: '8px'
            }}>
              Sedes
            </span>
            <div className="filter-chips" style={{
              display: 'flex',
              gap: '8px',
              flexWrap: 'wrap'
            }}>
              {instancesWithService.map((name) => {
                const isActive = selectedInstances.includes(name);
                return (
                  <button
                    key={name}
                    type="button"
                    className={`k-btn k-btn--small ${isActive ? 'is-active' : ''}`}
                    onClick={() => toggleInstance(name)}
                    style={{
                      padding: '6px 14px',
                      borderRadius: '20px',
                      border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
                      background: isActive 
                        ? (isDark ? '#2563eb' : '#3b82f6')
                        : 'transparent',
                      color: isActive 
                        ? 'white' 
                        : (isDark ? '#e5e7eb' : '#1f2937'),
                      fontSize: '0.85rem',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease',
                      fontWeight: isActive ? '600' : '400'
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
      </section>

      {/* CONTENEDOR DE GRÁFICA - ESTILO ORIGINAL */}
      <section className="multi-view-chart-section" aria-label="Gráfica comparativa">
        {!hasService && (
          <p className="muted" style={{ 
            textAlign: 'center', 
            padding: '60px 20px',
            color: isDark ? '#94a3b8' : '#6b7280'
          }}>
            Selecciona un servicio HTTP para ver su comportamiento en todas las sedes.
          </p>
        )}

        {hasService && selectedInstances.length === 0 && (
          <p className="muted" style={{ 
            textAlign: 'center', 
            padding: '60px 20px',
            color: isDark ? '#94a3b8' : '#6b7280'
          }}>
            No hay sedes seleccionadas. Haz click en los botones para seleccionar sedes.
          </p>
        )}

        {hasService && selectedInstances.length > 0 && !hasSeries && !loading && (
          <p className="muted" style={{ 
            textAlign: 'center', 
            padding: '60px 20px',
            color: isDark ? '#94a3b8' : '#6b7280'
          }}>
            No hay datos históricos disponibles para {selectedRange.label.toLowerCase()}.
          </p>
        )}

        {hasService && selectedInstances.length > 0 && hasSeries && !loading && (
          <div className="multi-view-chart-wrapper" style={{ 
            position: 'relative',
            marginTop: '20px'
          }}>
            <HistoryChart 
              mode="multi" 
              seriesMulti={chartSeries} 
              h={380}
            />
          </div>
        )}

        {loading && (
          <div style={{
            position: 'relative',
            height: '380px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: isDark ? '#1a1e24' : '#f9fafb',
            borderRadius: '8px',
            border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`
          }}>
            <span style={{
              padding: '8px 16px',
              backgroundColor: isDark ? '#0f1217' : '#ffffff',
              border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
              borderRadius: '20px',
              color: isDark ? '#e5e7eb' : '#1f2937'
            }}>
              Cargando datos para {selectedRange.label}...
            </span>
          </div>
        )}
      </section>
    </div>
  );
}
EOF

echo "✅ MultiServiceView.jsx restaurado - ESTILOS ORIGINALES y SELECCIÓN PERSISTENTE"
echo ""

# ========== 3. ACTUALIZAR DARK-MODE.CSS PARA LOS ESTILOS ORIGINALES ==========
echo "[3] Actualizando dark-mode.css con estilos originales..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== MULTISERVICEVIEW - ESTILOS ORIGINALES ========== */
body.dark-mode .multi-view {
  background-color: #0f1217 !important;
  color: #e5e7eb !important;
}

body.dark-mode .filters-toolbar {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode .filter-label {
  color: #94a3b8 !important;
}

body.dark-mode .filter-select {
  background-color: #0f1217 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn--small {
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn--small:hover {
  background-color: #2d3238 !important;
}

body.dark-mode .k-btn--small.is-active {
  background-color: #2563eb !important;
  border-color: #2563eb !important;
  color: white !important;
}

body.dark-mode .multi-view-chart-wrapper {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode .muted {
  color: #94a3b8 !important;
}
EOF

echo "✅ dark-mode.css actualizado"
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
echo "✅✅ ESTILOS ORIGINALES RESTAURADOS ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🎨 BOTONES DE SEDES: ESTILO ORIGINAL"
echo "      • Clase 'k-btn k-btn--small'"
echo "      • Hover effects originales"
echo "      • Active state con color azul"
echo ""
echo "   2. 🔒 SELECCIÓN PERSISTENTE - CORREGIDA"
echo "      • Ya NO se deseleccionan las sedes al actualizar"
echo "      • Solo se resetea al cambiar de servicio MANUALMENTE"
echo "      • Al cambiar servicio, selecciona TODAS las sedes"
echo ""
echo "   3. 📊 SELECTOR DE RANGO: FUNCIONAL"
echo "      • Cambia el rango de tiempo"
echo "      • Actualiza la gráfica automáticamente"
echo ""
echo "   4. 🌙 MODO OSCURO: ESTILOS ORIGINALES"
echo "      • Mismos colores que el dashboard principal"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Ve a 'Comparar'"
echo "   3. ✅ BOTONES con ESTILO ORIGINAL"
echo "   4. ✅ Selecciona/deselecciona sedes - NO se resetean"
echo "   5. ✅ Cambia el rango de tiempo 📊 - SE ACTUALIZA"
echo "   6. ✅ Cambia de servicio - selecciona TODAS las sedes"
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
