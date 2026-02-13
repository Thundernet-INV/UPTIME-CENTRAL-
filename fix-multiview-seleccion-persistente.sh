#!/bin/bash
# fix-multiview-seleccion-persistente.sh - MANTENER SEDES SELECCIONADAS AL ACTUALIZAR

echo "====================================================="
echo "🔧 CORRIGIENDO SELECCIÓN PERSISTENTE EN MULTIVIEW"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_multiview_persistente_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. ACTUALIZAR MULTISERVICEVIEW.JSX ==========
echo "[2] Actualizando MultiServiceView.jsx con selección persistente..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useState, useRef } from "react";
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
  
  // 🟢 REF para saber si el usuario ha interactuado con las sedes
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

  // 🟢 CORREGIDO: Seleccionar todas las instancias SOLO si:
  // 1. Cambió el servicio
  // 2. El usuario NO ha interactuado con las sedes
  useEffect(() => {
    // Solo ejecutar si hay un servicio seleccionado
    if (!selectedService || instancesWithService.length === 0) return;
    
    // Si cambió el servicio (diferente al anterior)
    if (prevServiceRef.current !== selectedService) {
      console.log(`🔄 Servicio cambiado: ${prevServiceRef.current} → ${selectedService}`);
      
      // Resetear interacción del usuario al cambiar servicio
      userInteracted.current = false;
      
      // Seleccionar TODAS las instancias del nuevo servicio
      setSelectedInstances(instancesWithService);
      
      // Actualizar referencia
      prevServiceRef.current = selectedService;
    }
    // Si NO ha cambiado el servicio y el usuario NO ha interactuado, NO hacer nada
    // (mantener las selecciones actuales)
    
  }, [selectedService, instancesWithService]);

  // 🟢 Función para toggle de sedes - MARCA QUE EL USUARIO INTERACTUÓ
  const toggleInstance = (name) => {
    userInteracted.current = true;
    setSelectedInstances(prev =>
      prev.includes(name) ? prev.filter(n => n !== name) : [...prev, name]
    );
  };

  // Cargar datos (mantiene selectedInstances actual)
  useEffect(() => {
    let active = true;
    const load = async () => {
      if (!selectedService || selectedInstances.length === 0) return;
      
      console.log(`📊 Cargando datos para ${selectedService} - ${selectedInstances.length} sedes (${selectedHours}h) - Interacción usuario: ${userInteracted.current}`);
      
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
        
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setIsOpen(!isOpen)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              padding: '6px 14px',
              background: 'var(--bg-tertiary, #f3f4f6)',
              border: '1px solid var(--border, #e5e7eb)',
              borderRadius: '20px',
              fontSize: '0.85rem',
              color: 'var(--text-primary, #1f2937)',
              cursor: 'pointer',
              transition: 'all 0.2s ease',
            }}
          >
            <span style={{ fontSize: '1rem' }}>🕒</span>
            <span style={{ fontWeight: '500' }}>{selectedLabel}</span>
            <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>▼</span>
          </button>
          
          {isOpen && (
            <div style={{
              position: 'absolute',
              top: '100%',
              right: 0,
              marginTop: '4px',
              background: 'white',
              border: '1px solid #e5e7eb',
              borderRadius: '8px',
              boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
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
          onChange={(e) => {
            // Cuando el usuario cambia el servicio MANUALMENTE
            setSelectedService(e.target.value);
            // Resetear interacción para que el nuevo servicio seleccione todas sus sedes
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
            {selectedInstances.length} de {instancesWithService.length} sedes seleccionadas
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

echo "✅ MultiServiceView.jsx actualizado - selección PERSISTENTE"
echo ""

# ========== 3. LIMPIAR CACHÉ ==========
echo "[3] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 4. REINICIAR FRONTEND ==========
echo "[4] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 5. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ SELECCIÓN PERSISTENTE CORREGIDA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🟢 userInteracted.useRef(false) - Marca cuando el usuario toca las sedes"
echo "   2. 🟢 prevServiceRef - Guarda el servicio anterior"
echo "   3. 🎯 Lógica corregida:"
echo "      • Al cambiar SERVICIO → selecciona TODAS las sedes"
echo "      • Al actualizar DATOS → mantiene las sedes seleccionadas"
echo "      • Al hacer click en una sede → marca interacción y NO se resetea"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Ve a 'Comparar'"
echo "   3. ✅ Selecciona SOLO 3 sedes (deselecciona las demás)"
echo "   4. ✅ Espera 30 segundos (que se actualicen los datos)"
echo "   5. ✅ LAS 3 SEDES SIGUEN SELECCIONADAS"
echo "   6. ✅ Cambia de servicio - selecciona TODAS las sedes del nuevo servicio"
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
