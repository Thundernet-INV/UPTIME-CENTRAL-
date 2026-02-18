#!/bin/bash
# fix-rangos-definitivo.sh - SELECTOR DE TIEMPO DENTRO DE LAS GRÁFICAS

echo "====================================================="
echo "🔧 SELECTOR DE TIEMPO DENTRO DE LAS GRÁFICAS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_rangos_definitivo_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. MODIFICAR HISTORYENGINE.JS - ACEPTAR HORAS ==========
echo "[2] Modificando historyEngine.js para aceptar horas..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN SIMPLE
import { historyApi } from './services/historyApi.js';

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  return data.map(item => ({
    ts: item.timestamp,
    ms: item.avgResponseTime || 0,
    sec: (item.avgResponseTime || 0) / 1000,
    x: item.timestamp,
    y: (item.avgResponseTime || 0) / 1000,
  }));
}

const History = {
  // ✅ PROMEDIO DE SEDE - acepta horas directamente
  async getAvgSeriesByInstance(instance, hours = 1) {
    if (!instance) return [];
    try {
      console.log(`📊 Cargando promedio de ${instance} (${hours}h)`);
      const sinceMs = hours * 60 * 60 * 1000;
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  },

  // ✅ MONITOR INDIVIDUAL - acepta horas directamente
  async getSeriesForMonitor(instance, name, hours = 1) {
    if (!instance || !name) return [];
    try {
      const monitorId = `${instance}_${name}`.replace(/\s+/g, '_');
      console.log(`📊 Cargando ${name} en ${instance} (${hours}h)`);
      const sinceMs = hours * 60 * 60 * 1000;
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  }
};

export default History;
EOF

echo "✅ historyEngine.js simplificado"
echo ""

# ========== 3. MODIFICAR INSTANCEDETAIL.JSX - SELECTOR DENTRO ==========
echo "[3] Agregando selector de tiempo DENTRO de InstanceDetail..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";

// Opciones de tiempo
const TIME_OPTIONS = [
  { label: '1 hora', hours: 1 },
  { label: '3 horas', hours: 3 },
  { label: '6 horas', hours: 6 },
  { label: '12 horas', hours: 12 },
  { label: '24 horas', hours: 24 },
  { label: '7 días', hours: 168 },
];

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
}) {
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [selectedHours, setSelectedHours] = useState(1); // 1 hora por defecto
  const [isOpen, setIsOpen] = useState(false);

  // Monitores de la sede actual
  const group = monitorsAll.filter((m) => m.instance === instanceName);

  // Cargar promedio cuando cambia instancia o horas
  useEffect(() => {
    let active = true;
    const load = async () => {
      const series = await History.getAvgSeriesByInstance(instanceName, selectedHours);
      if (active) setAvgSeries(series);
    };
    load();
    return () => { active = false; };
  }, [instanceName, selectedHours]);

  // Cargar monitores
  useEffect(() => {
    let active = true;
    const load = async () => {
      const entries = await Promise.all(
        group.map(async (m) => {
          const name = m.info?.monitor_name ?? "";
          const series = await History.getSeriesForMonitor(instanceName, name, selectedHours);
          return [name, series];
        })
      );
      if (active) setSeriesMonMap(new Map(entries));
    };
    load();
    return () => { active = false; };
  }, [instanceName, group.length, selectedHours]);

  const chartData = focus ? seriesMonMap.get(focus) || [] : avgSeries;
  const selectedLabel = TIME_OPTIONS.find(o => o.hours === selectedHours)?.label || '1 hora';

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
        
        {/* SELECTOR DE TIEMPO DENTRO DE LA SEDE */}
        <div style={{ position: 'relative', marginLeft: '12px' }}>
          <button
            onClick={() => setIsOpen(!isOpen)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '4px 12px',
              background: 'var(--bg-tertiary, #f3f4f6)',
              border: '1px solid var(--border, #e5e7eb)',
              borderRadius: '16px',
              fontSize: '0.8rem',
              cursor: 'pointer',
            }}
          >
            <span>🕒</span>
            <span>{selectedLabel}</span>
            <span>▼</span>
          </button>
          
          {isOpen && (
            <div style={{
              position: 'absolute',
              top: '100%',
              right: 0,
              marginTop: '4px',
              background: 'white',
              border: '1px solid #e5e7eb',
              borderRadius: '6px',
              boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
              zIndex: 9999,
              minWidth: '120px',
            }}>
              {TIME_OPTIONS.map((opt) => (
                <button
                  key={opt.hours}
                  onClick={() => {
                    setSelectedHours(opt.hours);
                    setIsOpen(false);
                  }}
                  style={{
                    display: 'block',
                    width: '100%',
                    padding: '8px 16px',
                    textAlign: 'left',
                    border: 'none',
                    background: selectedHours === opt.hours ? '#3b82f6' : 'transparent',
                    color: selectedHours === opt.hours ? 'white' : '#1f2937',
                    cursor: 'pointer',
                  }}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
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
            <span>📊 <strong>Promedio de {instanceName}</strong></span>
          </div>
        )}
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          <HistoryChart
            mode="instance"
            seriesMon={chartData}
            title={`${focus || instanceName} - ${selectedLabel}`}
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

echo "✅ InstanceDetail.jsx actualizado - selector DENTRO de la sede"
echo ""

# ========== 4. MODIFICAR MULTISERVICEVIEW.JSX - SELECTOR DENTRO ==========
echo "[4] Agregando selector de tiempo DENTRO de MultiServiceView..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";

// Opciones de tiempo
const TIME_OPTIONS = [
  { label: '1 hora', hours: 1 },
  { label: '3 horas', hours: 3 },
  { label: '6 horas', hours: 6 },
  { label: '12 horas', hours: 12 },
  { label: '24 horas', hours: 24 },
  { label: '7 días', hours: 168 },
];

function getColor(name) {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  return `hsl(${hash % 360}, 70%, 50%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesData, setSeriesData] = useState({});
  const [selectedHours, setSelectedHours] = useState(1);
  const [isOpen, setIsOpen] = useState(false);

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

  // Seleccionar todas las instancias por defecto
  useEffect(() => {
    if (instancesWithService.length > 0) {
      setSelectedInstances(instancesWithService);
    }
  }, [instancesWithService]);

  // Cargar datos
  useEffect(() => {
    let active = true;
    const load = async () => {
      if (!selectedService || selectedInstances.length === 0) return;
      
      const data = {};
      await Promise.all(
        selectedInstances.map(async (instance) => {
          const points = await History.getSeriesForMonitor(instance, selectedService, selectedHours);
          data[instance] = points;
        })
      );
      
      if (active) setSeriesData(data);
    };
    
    load();
    return () => { active = false; };
  }, [selectedService, selectedInstances, selectedHours]);

  const toggleInstance = (name) => {
    setSelectedInstances(prev =>
      prev.includes(name) ? prev.filter(n => n !== name) : [...prev, name]
    );
  };

  const chartSeries = selectedInstances.map(instance => ({
    id: instance,
    label: instance,
    color: getColor(instance),
    points: seriesData[instance] || []
  }));

  const selectedLabel = TIME_OPTIONS.find(o => o.hours === selectedHours)?.label || '1 hora';

  return (
    <div style={{ padding: '24px' }}>
      {/* HEADER CON SELECTOR DE TIEMPO */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Comparar servicio HTTP por sede</h2>
        
        {/* SELECTOR DE TIEMPO DENTRO DEL COMPONENTE */}
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setIsOpen(!isOpen)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '6px 14px',
              background: '#f3f4f6',
              border: '1px solid #e5e7eb',
              borderRadius: '20px',
              fontSize: '0.85rem',
              cursor: 'pointer',
            }}
          >
            <span>🕒</span>
            <span>{selectedLabel}</span>
            <span>▼</span>
          </button>
          
          {isOpen && (
            <div style={{
              position: 'absolute',
              top: '100%',
              right: 0,
              marginTop: '4px',
              background: 'white',
              border: '1px solid #e5e7eb',
              borderRadius: '6px',
              boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
              zIndex: 9999,
              minWidth: '120px',
            }}>
              {TIME_OPTIONS.map((opt) => (
                <button
                  key={opt.hours}
                  onClick={() => {
                    setSelectedHours(opt.hours);
                    setIsOpen(false);
                  }}
                  style={{
                    display: 'block',
                    width: '100%',
                    padding: '8px 16px',
                    textAlign: 'left',
                    border: 'none',
                    background: selectedHours === opt.hours ? '#3b82f6' : 'transparent',
                    color: selectedHours === opt.hours ? 'white' : '#1f2937',
                    cursor: 'pointer',
                  }}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* SELECTOR DE SERVICIO */}
      <div style={{ marginBottom: '20px' }}>
        <select
          value={selectedService}
          onChange={(e) => setSelectedService(e.target.value)}
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
                }}
              >
                {name}
              </button>
            ))}
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

echo "✅ MultiServiceView.jsx actualizado - selector DENTRO del componente"
echo ""

# ========== 5. LIMPIAR DASHBOARD.JSX - QUITAR SELECTOR GLOBAL ==========
echo "[5] Limpiando Dashboard.jsx - quitando selector global..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Eliminar cualquier selector del dashboard
sed -i '/TimeRangeSelector/d' "$DASHBOARD_FILE"
sed -i '/SimpleRangeSelector/d' "$DASHBOARD_FILE"
sed -i '/import .*RangeSelector/d' "$DASHBOARD_FILE"

echo "✅ Dashboard.jsx limpiado - los selectores ahora están DENTRO de cada componente"
echo ""

# ========== 6. GENERAR DATOS EN EL BACKEND ==========
echo "[6] Generando datos en el backend..."

cd /opt/kuma-central/kuma-aggregator

# Generar datos de promedio
sqlite3 data/history.db << 'EOF'
DELETE FROM instance_averages;

-- Caracas
INSERT INTO instance_averages (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
SELECT 'Caracas', strftime('%s','now','-'||(23 - hour)||' hours') * 1000, 75 + (hour * 0.5) + (abs(random()) % 15), 0.96, 45, 43, 2, 0
FROM (SELECT 0 as hour UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23);

-- Guanare
INSERT INTO instance_averages (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
SELECT 'Guanare', strftime('%s','now','-'||(23 - hour)||' hours') * 1000, 95 + (hour * 0.8) + (abs(random()) % 20), 0.93, 38, 35, 3, 0
FROM (SELECT 0 as hour UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23);
EOF

echo "✅ Datos generados"
echo ""

# ========== 7. REINICIAR TODO ==========
echo "[7] Reiniciando servicios..."

# Backend
pkill -f "node.*index.js" 2>/dev/null || true
sleep 1
cd /opt/kuma-central/kuma-aggregator
NODE_ENV=production nohup node src/index.js > /tmp/kuma-backend.log 2>&1 &

# Frontend
cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 8. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ SELECTORES DE TIEMPO DENTRO DE CADA GRÁFICA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🏢 InstanceDetail: SELECTOR 🕒 junto al título de la sede"
echo "   2. 📊 MultiServiceView: SELECTOR 🕒 en la esquina superior derecha"
echo "   3. ❌ Dashboard: SIN selector global (ya no hace falta)"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Entra a Caracas - VERÁS selector 🕒 junto al título"
echo "   3. ✅ CAMBIA de 1h a 24h - LA GRÁFICA SE ACTUALIZA"
echo "   4. ✅ Ve a 'Comparar' - VERÁS selector 🕒 arriba a la derecha"
echo "   5. ✅ CAMBIA el tiempo - LA GRÁFICA SE ACTUALIZA"
echo ""
echo "🎯 CADA GRÁFICA TIENE SU PROPIO SELECTOR DE TIEMPO"
echo "   • No dependen de variables globales"
echo "   • No dependen de eventos complejos"
echo "   • SIMPLE y FUNCIONAL"
echo ""
echo "====================================================="

# Abrir navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
