#!/bin/bash
# fix-agregar-selector-de-nuevo.sh - AGREGAR SELECTOR DE TIEMPO DE VUELTA

echo "====================================================="
echo "🕒 AGREGANDO SELECTOR DE TIEMPO DE VUELTA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_agregar_selector_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR INSTANCEDETAIL.JSX CON SELECTOR ==========
echo "[2] Agregando selector de tiempo a InstanceDetail..."

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
      // range.hours viene del hook useTimeRange
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
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
        
        {/* 🟢 SELECTOR DE TIEMPO - VISIBLE Y FUNCIONAL */}
        <div style={{ marginLeft: 'auto' }}>
          <TimeRangeSelector />
        </div>
      </div>

      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button className="k-btn k-btn--ghost" onClick={() => setFocus(null)}>
              Ver promedio
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            <span>📊 <strong>Promedio de {instanceName}</strong> · {rangeLabel}</span>
          </div>
        )}
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          <HistoryChart
            mode="instance"
            seriesMon={chartData}
            title={`${focus || instanceName} - ${rangeLabel}`}
          />

          <div className="instance-detail-actions">
            <button className="k-btn k-btn--danger">Ocultar todos</button>
            <button className="k-btn k-btn--ghost">Mostrar todos</button>
          </div>
        </div>

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

echo "✅ InstanceDetail.jsx actualizado - selector agregado"
echo ""

# ========== 3. ACTUALIZAR MULTISERVICEVIEW.JSX CON SELECTOR ==========
echo "[3] Agregando selector de tiempo a MultiServiceView..."

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
      {/* HEADER CON SELECTOR DE TIEMPO */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Comparar servicio HTTP por sede</h2>
        {/* 🟢 SELECTOR DE TIEMPO - VISIBLE Y FUNCIONAL */}
        <TimeRangeSelector />
      </div>

      {/* SELECTOR DE SERVICIO */}
      <div style={{ marginBottom: '20px' }}>
        <select
          value={selectedService}
          onChange={(e) => {
            setSelectedService(e.target.value);
            userInteracted.current = false;
          }}
          style={{
            padding: '8px 12px',
            borderRadius: '6px',
            border: '1px solid #e5e7eb',
            minWidth: '200px',
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
        <div style={{ marginBottom: '20px' }}>
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            {instancesWithService.map(name => (
              <button
                key={name}
                onClick={() => toggleInstance(name)}
                style={{
                  padding: '6px 14px',
                  borderRadius: '20px',
                  border: '1px solid #e5e7eb',
                  background: selectedInstances.includes(name) ? '#3b82f6' : 'transparent',
                  color: selectedInstances.includes(name) ? 'white' : '#1f2937',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                }}
              >
                {name}
              </button>
            ))}
          </div>
          <div style={{ marginTop: '8px', fontSize: '0.8rem', color: '#6b7280' }}>
            {selectedInstances.length} de {instancesWithService.length} sedes seleccionadas · Rango: {rangeLabel}
          </div>
        </div>
      )}

      {/* GRÁFICA */}
      <div style={{ minHeight: '400px' }}>
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

echo "✅ MultiServiceView.jsx actualizado - selector agregado"
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
echo "✅✅ SELECTOR DE TIEMPO RESTAURADO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🕒 INSTANCEDETAIL: Selector agregado en el header (derecha)"
echo "   2. 🕒 MULTISERVICEVIEW: Selector agregado en el header (derecha)"
echo "   3. ✅ rangeLabel mostrado en chips para referencia"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Entra a una sede - VERÁS selector 🕒 arriba a la derecha"
echo "   3. ✅ CAMBIA el rango - LA GRÁFICA SE ACTUALIZA"
echo "   4. ✅ Ve a 'Comparar' - VERÁS selector 🕒 arriba a la derecha"
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
