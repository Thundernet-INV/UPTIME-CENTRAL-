#!/bin/bash
# fix-multiservice-darkmode.sh - CORRIGE MODO OSCURO EN MULTISERVICEVIEW

echo "====================================================="
echo "🌙 CORRIGIENDO MODO OSCURO EN MULTISERVICEVIEW"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_multiservice_dark_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/dark-mode.css" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. CORREGIR MULTISERVICEVIEW.JSX CON SOPORTE DARK MODE ==========
echo ""
echo "[2] Actualizando MultiServiceView.jsx con soporte completo para modo oscuro..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useRef, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange } from "./TimeRangeSelector.jsx";
import { useTheme } from "../contexts/ThemeContext.jsx";

// Color estable a partir del nombre de la sede
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
  // Obtener el tema actual
  const { isDark } = useTheme();
  
  console.log("📊 MultiServiceView - Rango seleccionado:", selectedRange.label, selectedRange.value);
  console.log("🌙 MultiServiceView - Modo oscuro:", isDark);

  // 1) Lista de servicios HTTP únicos
  const services = useMemo(() => {
    const map = new Map();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue;

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (!name) continue;

      if (!map.has(name)) {
        map.set(name, { name, type: typeRaw, count: 0 });
      }
      map.get(name).count += 1;
    }
    return Array.from(map.values()).sort((a, b) =>
      a.name.localeCompare(b.name, "es", { sensitivity: "base" })
    );
  }, [monitorsAll]);

  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState(new Map());
  const [loading, setLoading] = useState(false);
  const [autoRotate, setAutoRotate] = useState(false);
  const [rotateIntervalSec, setRotateIntervalSec] = useState(8);

  const [userTouchedInstances, setUserTouchedInstances] = useState(false);
  const servicesRef = useRef([]);

  useEffect(() => {
    servicesRef.current = services;
  }, [services]);

  // 2) Sedes que tienen ese servicio HTTP
  const instancesWithService = useMemo(() => {
    if (!selectedService) return [];
    const set = new Set();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue;

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (name === selectedService && m.instance) {
        set.add(m.instance);
      }
    }
    return Array.from(set).sort();
  }, [monitorsAll, selectedService]);

  // 3) Elegir un servicio inicial
  useEffect(() => {
    if (!selectedService && services.length > 0) {
      setSelectedService(services[0].name);
    }
  }, [services, selectedService]);

  // 4) Resetear flag al cambiar servicio
  useEffect(() => {
    setUserTouchedInstances(false);
  }, [selectedService]);

  // 5) Sincronizar sedes seleccionadas
  useEffect(() => {
    if (!instancesWithService || instancesWithService.length === 0) return;

    setSelectedInstances((prev) => {
      if (!userTouchedInstances) {
        return instancesWithService;
      }
      const intersection = prev.filter((name) =>
        instancesWithService.includes(name)
      );
      return intersection.length > 0 ? intersection : prev;
    });
  }, [instancesWithService, userTouchedInstances]);

  const toggleInstance = (name) => {
    setUserTouchedInstances(true);
    setSelectedInstances((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name]
    );
  };

  // 6) Cargar series con el rango SELECCIONADO
  useEffect(() => {
    let alive = true;

    const fetchAll = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance(new Map());
        setLoading(false);
        return;
      }

      setLoading(true);
      console.log(`📊 Cargando datos para ${selectedService} - Rango: ${selectedRange.label}`);
      
      try {
        const entries = await Promise.all(
          selectedInstances.map(async (instanceName) => {
            const arr = await History.getSeriesForMonitor(
              instanceName,
              selectedService,
              selectedRange.value
            );
            return [instanceName, Array.isArray(arr) ? arr : []];
          })
        );
        if (alive) {
          setSeriesByInstance(new Map(entries));
          console.log(`✅ Datos cargados: ${entries.length} sedes`);
        }
      } catch (error) {
        console.error("Error cargando datos:", error);
      } finally {
        if (alive) setLoading(false);
      }
    };

    fetchAll();
    
    const handleRangeChange = (e) => {
      console.log("📊 Rango cambiado, recargando datos...");
      fetchAll();
    };
    
    window.addEventListener('time-range-change', handleRangeChange);
    
    return () => {
      alive = false;
      window.removeEventListener('time-range-change', handleRangeChange);
    };
  }, [selectedService, selectedInstances, selectedRange.value]);

  // 7) Auto-rotate
  useEffect(() => {
    if (!autoRotate) return;

    const intervalMs = Math.max(2, Number(rotateIntervalSec) || 8) * 1000;
    const timer = setInterval(() => {
      const list = servicesRef.current;
      if (!list || list.length === 0) return;

      setSelectedService((prev) => {
        if (!prev) return list[0].name;
        const idx = list.findIndex((s) => s.name === prev);
        const nextIdx = idx === -1 ? 0 : (idx + 1) % list.length;
        return list[nextIdx].name;
      });
    }, intervalMs);

    return () => clearInterval(timer);
  }, [autoRotate, rotateIntervalSec]);

  // 8) Preparar datos para el chart
  const chartSeries = useMemo(() => {
    return selectedInstances.map((instanceName) => {
      const points = seriesByInstance.get(instanceName) ?? [];
      return {
        id: instanceName,
        label: instanceName,
        color: getColorForInstance(instanceName),
        points,
      };
    });
  }, [selectedInstances, seriesByInstance]);

  const hasService = !!selectedService;
  const hasSeries = chartSeries.length > 0;

  // Estilos dinámicos basados en el tema
  const styles = {
    container: {
      backgroundColor: isDark ? '#0f1217' : '#ffffff',
      color: isDark ? '#e5e7eb' : '#1f2937',
      padding: '24px',
      borderRadius: '12px',
      transition: 'all 0.3s ease',
    },
    title: {
      color: isDark ? '#f1f5f9' : '#111827',
      margin: 0,
      fontSize: '1.5rem',
      fontWeight: '600',
    },
    rangeIndicator: {
      fontSize: '0.85rem',
      color: isDark ? '#94a3b8' : '#6b7280',
      background: isDark ? '#1a1e24' : '#f3f4f6',
      padding: '6px 12px',
      borderRadius: '20px',
      border: isDark ? '1px solid #2d3238' : '1px solid #e5e7eb',
    },
    filterGroup: {
      background: isDark ? '#1a1e24' : '#f9fafb',
      border: isDark ? '1px solid #2d3238' : '1px solid #e5e7eb',
      borderRadius: '8px',
      padding: '16px',
      marginBottom: '16px',
    },
    filterLabel: {
      display: 'block',
      fontSize: '0.8rem',
      fontWeight: '600',
      textTransform: 'uppercase' as const,
      letterSpacing: '0.05em',
      color: isDark ? '#94a3b8' : '#6b7280',
      marginBottom: '8px',
    },
    select: {
      width: '100%',
      padding: '10px 12px',
      borderRadius: '6px',
      border: isDark ? '1px solid #2d3238' : '1px solid #e5e7eb',
      background: isDark ? '#0f1217' : '#ffffff',
      color: isDark ? '#e5e7eb' : '#1f2937',
      fontSize: '0.95rem',
      cursor: 'pointer',
    },
    chip: {
      padding: '6px 14px',
      borderRadius: '20px',
      border: isDark ? '1px solid #2d3238' : '1px solid #e5e7eb',
      background: 'transparent',
      color: isDark ? '#e5e7eb' : '#1f2937',
      fontSize: '0.85rem',
      cursor: 'pointer',
      transition: 'all 0.2s ease',
    },
    chipActive: {
      background: isDark ? '#2563eb' : '#3b82f6',
      borderColor: isDark ? '#2563eb' : '#3b82f6',
      color: 'white',
    },
    input: {
      width: '60px',
      padding: '8px',
      borderRadius: '6px',
      border: isDark ? '1px solid #2d3238' : '1px solid #e5e7eb',
      background: isDark ? '#0f1217' : '#ffffff',
      color: isDark ? '#e5e7eb' : '#1f2937',
      fontSize: '0.85rem',
      textAlign: 'right' as const,
    },
    muted: {
      color: isDark ? '#94a3b8' : '#6b7280',
      textAlign: 'center' as const,
      padding: '40px',
    },
    overlay: {
      position: 'absolute' as const,
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
    },
    overlayText: {
      background: isDark ? '#1a1e24' : '#ffffff',
      padding: '8px 16px',
      borderRadius: '20px',
      boxShadow: isDark ? '0 2px 8px rgba(0,0,0,0.3)' : '0 2px 8px rgba(0,0,0,0.1)',
      color: isDark ? '#e5e7eb' : '#1f2937',
      border: isDark ? '1px solid #2d3238' : '1px solid #e5e7eb',
    }
  };

  return (
    <div style={styles.container}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <h2 style={styles.title}>Comparar servicio HTTP por sede</h2>
        <div style={styles.rangeIndicator}>
          📊 {selectedRange.label}
        </div>
      </div>

      <section aria-label="Filtros de comparación">
        {/* Servicio HTTP */}
        <div style={styles.filterGroup}>
          <label style={styles.filterLabel} htmlFor="service-select">
            Servicio HTTP
          </label>
          <select
            id="service-select"
            value={selectedService}
            onChange={(e) => setSelectedService(e.target.value)}
            style={styles.select}
          >
            <option value="">Selecciona un servicio…</option>
            {services.map((s) => (
              <option key={s.name} value={s.name}>
                {s.name} {s.type ? `(${s.type.toUpperCase()})` : ""} · {s.count} monitores
              </option>
            ))}
          </select>
        </div>

        {/* Sedes */}
        {hasService && (
          <div style={styles.filterGroup}>
            <span style={styles.filterLabel}>Sedes</span>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {instancesWithService.map((name) => {
                const isActive = selectedInstances.includes(name);
                return (
                  <button
                    key={name}
                    type="button"
                    onClick={() => toggleInstance(name)}
                    style={{
                      ...styles.chip,
                      ...(isActive ? styles.chipActive : {}),
                    }}
                    onMouseEnter={(e) => {
                      if (!isActive) {
                        e.currentTarget.style.background = isDark ? '#2d3238' : '#f3f4f6';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!isActive) {
                        e.currentTarget.style.background = 'transparent';
                      }
                    }}
                  >
                    {name}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Opciones de auto-rotación */}
        <div style={styles.filterGroup}>
          <span style={styles.filterLabel}>Opciones</span>
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap' }}>
            <button
              type="button"
              onClick={() => setAutoRotate((prev) => !prev)}
              style={{
                ...styles.chip,
                ...(autoRotate ? styles.chipActive : {}),
              }}
            >
              Auto: {autoRotate ? "ON" : "OFF"}
            </button>
            <span style={{ fontSize: "0.8rem", color: isDark ? '#94a3b8' : '#6b7280' }}>
              Cada
            </span>
            <input
              type="number"
              min={2}
              max={600}
              value={rotateIntervalSec}
              onChange={(e) => setRotateIntervalSec(e.target.value)}
              style={styles.input}
            />
            <span style={{ fontSize: "0.8rem", color: isDark ? '#94a3b8' : '#6b7280' }}>seg</span>
          </div>
        </div>
      </section>

      <section aria-label="Gráfica comparativa">
        {!hasService && (
          <p style={styles.muted}>
            Selecciona un servicio HTTP para ver su comportamiento en todas las sedes.
          </p>
        )}

        {hasService && !hasSeries && !loading && (
          <p style={styles.muted}>
            No hay sedes seleccionadas o no se encontró historial para este servicio.
          </p>
        )}

        {hasService && !hasSeries && loading && (
          <p style={styles.muted}>
            Cargando series históricas para {selectedRange.label}...
          </p>
        )}

        {hasService && hasSeries && (
          <div className="multi-view-chart-wrapper" style={{ position: 'relative', marginTop: '20px' }}>
            <HistoryChart mode="multi" seriesMulti={chartSeries} h={380} />
            {loading && (
              <div style={styles.overlay}>
                <span style={styles.overlayText}>
                  Actualizando datos para {selectedRange.label}...
                </span>
              </div>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
EOF

echo "✅ MultiServiceView.jsx actualizado con soporte completo para modo oscuro"
echo ""

# ========== 3. ACTUALIZAR DARK-MODE.CSS CON ESTILOS FUERTES ==========
echo ""
echo "[3] Reforzando estilos dark-mode para MultiServiceView..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== MULTISERVICEVIEW - MODO OSCURO FORZADO ========== */
body.dark-mode .multi-view,
body.dark-mode div[style*="background-color: #0f1217"],
body.dark-mode .multi-view-chart-wrapper {
  background-color: #0f1217 !important;
}

body.dark-mode .filter-group,
body.dark-mode div[style*="background: #1a1e24"] {
  background-color: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode select,
body.dark-mode input,
body.dark-mode div[style*="background: #0f1217"] {
  background-color: #0f1217 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode option {
  background-color: #1a1e24 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn--small,
body.dark-mode button[style*="border-radius: 20px"] {
  background: transparent !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn--small.is-active,
body.dark-mode button[style*="background: #2563eb"],
body.dark-mode button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  border-color: #2563eb !important;
  color: white !important;
}

body.dark-mode div[style*="position: absolute"][style*="background: rgba(0,0,0,0.7)"] {
  background: rgba(0, 0, 0, 0.85) !important;
  backdrop-filter: blur(4px) !important;
}

body.dark-mode span[style*="background: #1a1e24"] {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

/* Forzar fondo oscuro en elementos específicos */
body.dark-mode .multi-view h2,
body.dark-mode h2[style*="color: #f1f5f9"] {
  color: #f1f5f9 !important;
}

body.dark-mode .filter-label,
body.dark-mode span[style*="color: #94a3b8"] {
  color: #94a3b8 !important;
}

body.dark-mode p,
body.dark-mode div[style*="color: #94a3b8"] {
  color: #94a3b8 !important;
}

/* Corregir dropdown del selector de tiempo dentro de MultiServiceView */
body.dark-mode .time-range-selector div[style*="position: absolute"] {
  background: #1a1e24 !important;
  border: 1px solid #2d3238 !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5) !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button {
  color: #e5e7eb !important;
  border-bottom-color: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button:hover {
  background: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  color: white !important;
}
EOF

echo "✅ dark-mode.css actualizado con estilos forzados"
echo ""

# ========== 4. VERIFICAR QUE THEMECONTEXT EXISTE ==========
echo ""
echo "[4] Verificando ThemeContext..."

if [ ! -f "${FRONTEND_DIR}/src/contexts/ThemeContext.jsx" ]; then
    echo "⚠️  ThemeContext no encontrado - el modo oscuro no funcionará correctamente"
    echo "    Ejecuta primero: ./setup-dark-mode-seguro.sh"
else
    echo "✅ ThemeContext encontrado"
fi

# ========== 5. LIMPIAR CACHÉ ==========
echo ""
echo "[5] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ MODO OSCURO CORREGIDO EN MULTISERVICEVIEW ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • MultiServiceView.jsx: AHORA USA useTheme()"
echo "   • Estilos 100% dinámicos basados en el tema"
echo "   • Fondo oscuro (#0f1217) en modo oscuro"
echo "   • Cards oscuras (#1a1e24) en modo oscuro"
echo "   • Texto claro (#e5e7eb) en modo oscuro"
echo "   • Botones con estilo consistente"
echo ""
echo "🎯 CARACTERÍSTICAS:"
echo "   • ✅ MultiServiceView COMPLETAMENTE oscuro"
echo "   • ✅ Mismos colores que el dashboard principal"
echo "   • ✅ Selector de tiempo visible y funcional"
echo "   • ✅ Hover effects en modo oscuro"
echo "   • ✅ Transiciones suaves"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Activa el modo oscuro (botón 🌙 en esquina superior derecha)"
echo "   3. Ve a 'Comparar'"
echo "   4. MultiServiceView DEBE estar COMPLETAMENTE oscuro"
echo "   5. Prueba el selector de tiempo - debe funcionar"
echo ""
echo "📌 NOTA: Si ves algún elemento blanco, recarga la página (F5)"
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
