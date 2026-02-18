#!/bin/bash
# fix-mover-selector-derecha.sh - MOVER SELECTOR DE TIEMPO A LA DERECHA

echo "====================================================="
echo "🎯 MOVIENDO SELECTOR DE TIEMPO A LA DERECHA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_mover_selector_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR INSTANCEDETAIL.JSX - SELECTOR A LA DERECHA ==========
echo "[2] Moviendo selector a la derecha en InstanceDetail..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import TimeRangeSelector, { useTimeRange } from "./TimeRangeSelector.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
}) {
  // 🟢 USAR EL HOOK DE RANGO DE TIEMPO
  const range = useTimeRange();
  
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());

  // Monitores de la sede actual
  const group = monitorsAll.filter((m) => m.instance === instanceName);

  // Cargar promedio cuando cambia instancia o rango
  useEffect(() => {
    let active = true;
    const load = async () => {
      const hours = range?.hours || 1;
      console.log(`🏢 Cargando promedio de ${instanceName} (${hours}h)`);
      const series = await History.getAvgSeriesByInstance(instanceName, hours);
      if (active) setAvgSeries(series);
    };
    load();
    return () => { active = false; };
  }, [instanceName, range]);

  // Cargar monitores
  useEffect(() => {
    let active = true;
    const load = async () => {
      const hours = range?.hours || 1;
      const entries = await Promise.all(
        group.map(async (m) => {
          const name = m.info?.monitor_name ?? "";
          const series = await History.getSeriesForMonitor(instanceName, name, hours);
          return [name, series];
        })
      );
      if (active) setSeriesMonMap(new Map(entries));
    };
    load();
    return () => { active = false; };
  }, [instanceName, group.length, range]);

  const chartData = focus ? seriesMonMap.get(focus) || [] : avgSeries;
  const rangeLabel = range?.label || '1 hora';

  return (
    <div className="instance-detail-page">
      {/* HEADER CON SELECTOR A LA DERECHA */}
      <div style={{ 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between',
        padding: '16px 24px',
        borderBottom: '1px solid var(--border, #e5e7eb)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <button
            className="k-btn k-btn--primary"
            onClick={() => window.history.back()}
            style={{ padding: '6px 16px' }}
          >
            ← Volver
          </button>
          <h2 style={{ margin: 0, fontSize: '1.5rem' }}>{instanceName}</h2>
        </div>
        
        {/* 🟢 SELECTOR DE TIEMPO - A LA DERECHA */}
        <TimeRangeSelector />
      </div>

      {/* CHIP DE CONTEXTO */}
      <div style={{ padding: '12px 24px' }}>
        <div className="k-chip k-chip--muted">
          {focus ? (
            <span>Mostrando: <strong>{focus}</strong></span>
          ) : (
            <span>📊 <strong>Promedio de {instanceName}</strong> · {rangeLabel}</span>
          )}
          {focus && (
            <button 
              className="k-btn k-btn--ghost k-chip-action" 
              onClick={() => setFocus(null)}
              style={{ marginLeft: '8px' }}
            >
              Ver promedio
            </button>
          )}
        </div>
      </div>

      {/* GRID DE SERVICIOS */}
      <section className="instance-detail-grid" style={{ padding: '0 24px 24px' }}>
        {/* GRÁFICA PRINCIPAL */}
        <div className="instance-detail-chart">
          <HistoryChart
            mode="instance"
            seriesMon={chartData}
            title={`${focus || instanceName} - ${rangeLabel}`}
          />

          <div className="instance-detail-actions" style={{ 
            display: 'flex', 
            gap: '12px', 
            marginTop: '16px',
            justifyContent: 'flex-end'
          }}>
            <button className="k-btn k-btn--danger">Ocultar todos</button>
            <button className="k-btn k-btn--ghost">Mostrar todos</button>
          </div>
        </div>

        {/* CARDS DE SERVICIOS */}
        {group.map((m) => {
          const name = m.info?.monitor_name ?? "";
          return (
            <div
              key={name}
              className="instance-detail-service-card"
              onClick={() => setFocus(name)}
              style={{ cursor: 'pointer' }}
            >
              <ServiceCard service={m} series={seriesMonMap.get(name) || []} />
            </div>
          );
        })}
      </section>
    </div>
  );
}
EOF

echo "✅ InstanceDetail.jsx actualizado - selector a la derecha"
echo ""

# ========== 3. ACTUALIZAR MULTISERVICEVIEW.JSX - SELECTOR A LA DERECHA ==========
echo "[3] Moviendo selector a la derecha en MultiServiceView..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useState, useRef } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import TimeRangeSelector, { useTimeRange } from "./TimeRangeSelector.jsx";

function getColor(name) {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  return `hsl(${hash % 360}, 70%, 50%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // 🟢 USAR EL HOOK DE RANGO DE TIEMPO
  const range = useTimeRange();
  
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesData, setSeriesData] = useState({});
  
  // Ref para saber si el usuario ha interactuado con las sedes
  const userInteracted = useRef(false);
  const prevServiceRef = useRef("");

  // Lista de servicios HTTP
  const services = useMemo(() => {
    const map = new Map();
    monitorsAll.forEach(m => {
      if (m.info?.monitor_type?.toLowerCase() !== "http") return;
      const name = m.info?.monitor_name;
      if (name && m.instance) {
        if (!map.has(name)) map.set(name, { name, instances: new Set() });
        map.get(name).instances.add(m.instance);
      }
    });
    return Array.from(map.values()).map(s => ({
      ...s,
      instances: Array.from(s.instances).sort(),
      count: s.instances.size
    })).sort((a, b) => a.name.localeCompare(b.name));
  }, [monitorsAll]);

  // Auto-seleccionar primer servicio
  useEffect(() => {
    if (services.length > 0 && !selectedService) {
      setSelectedService(services[0].name);
    }
  }, [services, selectedService]);

  // Instancias del servicio seleccionado
  const instancesWithService = useMemo(() => {
    const service = services.find(s => s.name === selectedService);
    return service?.instances || [];
  }, [services, selectedService]);

  // Seleccionar todas las instancias SOLO si cambia el servicio
  useEffect(() => {
    if (!selectedService || instancesWithService.length === 0) return;
    
    if (prevServiceRef.current !== selectedService) {
      console.log(`🔄 Servicio cambiado: ${prevServiceRef.current} → ${selectedService}`);
      userInteracted.current = false;
      setSelectedInstances(instancesWithService);
      prevServiceRef.current = selectedService;
    }
  }, [selectedService, instancesWithService]);

  // Toggle de sedes
  const toggleInstance = (name) => {
    userInteracted.current = true;
    setSelectedInstances(prev =>
      prev.includes(name) ? prev.filter(n => n !== name) : [...prev, name]
    );
  };

  // Cargar datos
  useEffect(() => {
    let active = true;
    const load = async () => {
      if (!selectedService || selectedInstances.length === 0) return;
      
      const hours = range?.hours || 1;
      console.log(`📊 Cargando ${selectedService} - ${selectedInstances.length} sedes (${hours}h)`);
      
      const data = {};
      await Promise.all(
        selectedInstances.map(async (instance) => {
          const points = await History.getSeriesForMonitor(instance, selectedService, hours);
          data[instance] = points;
        })
      );
      
      if (active) setSeriesData(data);
    };
    
    load();
    return () => { active = false; };
  }, [selectedService, selectedInstances, range]);

  const chartSeries = selectedInstances.map(instance => ({
    id: instance,
    label: instance,
    color: getColor(instance),
    points: seriesData[instance] || []
  }));

  const rangeLabel = range?.label || '1 hora';

  return (
    <div style={{ padding: '24px' }}>
      {/* HEADER CON SELECTOR A LA DERECHA */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        marginBottom: '24px' 
      }}>
        <h2 style={{ margin: 0, fontSize: '1.5rem' }}>Comparar servicio HTTP por sede</h2>
        {/* 🟢 SELECTOR DE TIEMPO - A LA DERECHA */}
        <TimeRangeSelector />
      </div>

      {/* SELECTOR DE SERVICIO */}
      <div style={{ marginBottom: '24px' }}>
        <select
          value={selectedService}
          onChange={(e) => {
            setSelectedService(e.target.value);
            userInteracted.current = false;
          }}
          style={{
            padding: '10px 16px',
            borderRadius: '8px',
            border: '1px solid var(--border, #e5e7eb)',
            minWidth: '250px',
            fontSize: '0.95rem',
          }}
        >
          {services.map(s => (
            <option key={s.name} value={s.name}>
              {s.name} · {s.count} {s.count === 1 ? 'sede' : 'sedes'}
            </option>
          ))}
        </select>
      </div>

      {/* BOTONES DE SEDES */}
      {selectedService && instancesWithService.length > 0 && (
        <div style={{ marginBottom: '24px' }}>
          <div style={{ 
            display: 'flex', 
            gap: '10px', 
            flexWrap: 'wrap',
            marginBottom: '8px'
          }}>
            {instancesWithService.map(name => (
              <button
                key={name}
                onClick={() => toggleInstance(name)}
                style={{
                  padding: '8px 18px',
                  borderRadius: '30px',
                  border: '1px solid var(--border, #e5e7eb)',
                  background: selectedInstances.includes(name) ? '#3b82f6' : 'transparent',
                  color: selectedInstances.includes(name) ? 'white' : 'var(--text-primary, #1f2937)',
                  cursor: 'pointer',
                  fontSize: '0.9rem',
                  fontWeight: selectedInstances.includes(name) ? '600' : '400',
                  transition: 'all 0.2s ease',
                }}
              >
                {name}
              </button>
            ))}
          </div>
          <div style={{ fontSize: '0.9rem', color: 'var(--text-secondary, #6b7280)' }}>
            {selectedInstances.length} de {instancesWithService.length} sedes seleccionadas · Rango: {rangeLabel}
          </div>
        </div>
      )}

      {/* GRÁFICA */}
      <div style={{ minHeight: '400px', marginTop: '20px' }}>
        {selectedService && selectedInstances.length > 0 && (
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

echo "✅ MultiServiceView.jsx actualizado - selector a la derecha"
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
echo "✅✅ SELECTOR MOVIDO A LA DERECHA ✅✅"
echo "====================================================="
echo ""
echo "📍 UBICACIÓN DEL SELECTOR:"
echo ""
echo "   🏢 INSTANCEDETAIL:"
echo "   • Header: [← Volver] [Caracas]               [🕒 Selector]"
echo ""
echo "   📊 MULTISERVICEVIEW:"
echo "   • Header: [Comparar servicio HTTP por sede]  [🕒 Selector]"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Entra a Caracas - SELECTOR a la DERECHA"
echo "   3. ✅ Ve a 'Comparar' - SELECTOR a la DERECHA"
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
