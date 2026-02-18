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
