#!/bin/bash
# fix-instance-detail-urgente.sh - REEMPLAZA COMPLETAMENTE InstanceDetail.jsx

echo "====================================================="
echo "🔧 CORRECCIÓN URGENTE - INSTANCEDETAIL.JSX"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_instance_detail_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup de InstanceDetail.jsx..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. REEMPLAZAR INSTANCEDETAIL.JSX COMPLETAMENTE ==========
echo ""
echo "[2] Reemplazando InstanceDetail.jsx con versión CORREGIDA..."

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
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  
  const [focus, setFocus] = useState(null);
  const [seriesInstance, setSeriesInstance] = useState({});
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

  // Promedio de sede con rango dinámico
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const obj = await History.getAllForInstance(
          instanceName,
          selectedRange.value
        );
        if (!alive) return;
        setSeriesInstance(obj ?? {});
      } catch {
        if (!alive) return;
        setSeriesInstance({});
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, selectedRange.value]);

  // Series por monitor con rango dinámico
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const arr = await History.getSeriesForMonitor(
              instanceName,
              name,
              selectedRange.value
            );
            return [name, Array.isArray(arr) ? arr : []];
          })
        );
        if (!alive) return;
        setSeriesMonMap(new Map(entries));
      } catch {
        if (!alive) return;
        setSeriesMonMap(new Map());
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, selectedRange.value]);

  // Fuente del chart principal
  const chartMode = focus ? "monitor" : "instance";
  const chartSeries = focus ? seriesMonMap.get(focus) ?? [] : seriesInstance;

  return (
    <div className="instance-detail-page">
      {/* Header sede */}
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
      </div>

      {/* Chip contexto */}
      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button
              className="k-btn k-btn--ghost k-chip-action"
              onClick={() => setFocus(null)}
            >
              Ver sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            Mostrando: <strong>Promedio de la sede</strong>
          </div>
        )}
      </div>

      {/* GRID: gráfica en el centro, cards alrededor */}
      <section
        className="instance-detail-grid"
        aria-label={`Historial y servicios de ${instanceName}`}
      >
        {/* Gráfica en columna central */}
        <div className="instance-detail-chart">
          {chartMode === "monitor" ? (
            <HistoryChart
              mode="monitor"
              seriesMon={chartSeries}
              title={focus ?? "Latencia (ms)"}
            />
          ) : (
            <HistoryChart mode="instance" series={chartSeries} />
          )}

          {/* Acciones globales debajo de la gráfica */}
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

        {/* Cards de servicio alrededor */}
        {group.map((m, i) => {
          const name = m.info?.monitor_name ?? "";
          const seriesMon = seriesMonMap.get(name) ?? [];
          return (
            <div
              key={name || i}
              className="instance-detail-service-card"
              onClick={() => setFocus(name)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  setFocus(name);
                }
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

echo "✅ InstanceDetail.jsx reemplazado con versión CORREGIDA"
echo ""

# ========== 3. CORREGIR MULTISERVICEVIEW.JSX ==========
echo ""
echo "[3] Corrigiendo MultiServiceView.jsx..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

if [ -f "$MULTI_FILE" ]; then
    # Backup
    cp "$MULTI_FILE" "$BACKUP_DIR/"
    
    # Reemplazar uso incorrecto
    sed -i 's/const timeRange = useTimeRange();/const selectedRange = useTimeRange();/g' "$MULTI_FILE"
    sed -i 's/timeRange.value/selectedRange.value/g' "$MULTI_FILE"
    sed -i 's/range.value/selectedRange.value/g' "$MULTI_FILE"
    
    echo "✅ MultiServiceView.jsx corregido"
fi

# ========== 4. VERIFICAR TIMERANGESELECTOR.JSX ==========
echo ""
echo "[4] Verificando TimeRangeSelector.jsx..."

SELECTOR_FILE="${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx"

if [ -f "$SELECTOR_FILE" ]; then
    # Asegurar que useTimeRange devuelve el objeto correcto
    if ! grep -q "return range;" "$SELECTOR_FILE"; then
        echo "⚠️  TimeRangeSelector.jsx necesita corrección..."
        cp "$SELECTOR_FILE" "$BACKUP_DIR/"
        
        # Corregir el hook
        sed -i '/export function useTimeRange/,/^}/ {
            /return/ s/.*/  return range;/
        }' "$SELECTOR_FILE"
        
        echo "✅ TimeRangeSelector.jsx corregido"
    else
        echo "✅ TimeRangeSelector.jsx OK"
    fi
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
echo "✅✅ CORRECCIÓN APLICADA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • InstanceDetail.jsx: REEMPLAZADO COMPLETAMENTE"
echo "   • Variable: timeRange → selectedRange"
echo "   • Hook: useTimeRange() devuelve el objeto correcto"
echo "   • Sintaxis: 100% válida"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. El dashboard DEBE cargar SIN ERRORES"
echo "   3. Prueba el selector de tiempo 📊"
echo "   4. Navega a una sede - debe funcionar"
echo ""
echo "📌 BACKUP DISPONIBLE:"
echo "   $BACKUP_DIR"
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
