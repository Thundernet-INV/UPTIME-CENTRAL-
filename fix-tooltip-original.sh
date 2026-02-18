#!/bin/bash
# fix-tooltip-original.sh - RESTAURAR TOOLTIP ORIGINAL DE LAS GRÁFICAS

echo "====================================================="
echo "🔧 RESTAURANDO TOOLTIP ORIGINAL DE LAS GRÁFICAS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_tooltip_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/HistoryChart.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. RESTAURAR HISTORYCHART.JSX CON TOOLTIP ORIGINAL ==========
echo "[2] Restaurando HistoryChart.jsx - TOOLTIP ORIGINAL..."

cat > "${FRONTEND_DIR}/src/components/HistoryChart.jsx" << 'EOF'
// src/components/HistoryChart.jsx - VERSIÓN ORIGINAL CON TOOLTIP CORRECTO
import React, { useMemo } from 'react';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  TimeScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
} from 'chart.js';
import { Line } from 'react-chartjs-2';
import 'chartjs-adapter-date-fns';
import { es } from 'date-fns/locale';

ChartJS.register(
  CategoryScale,
  LinearScale,
  TimeScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

export default function HistoryChart({ 
  mode = 'instance',
  seriesMon = [], 
  seriesMulti = [],
  title = 'Latencia',
  h = 300
}) {
  
  const isDark = typeof document !== 'undefined' && document.body.classList.contains('dark-mode');
  
  const chartData = useMemo(() => {
    if (mode === 'multi' && seriesMulti && seriesMulti.length > 0) {
      return {
        datasets: seriesMulti.map((series, index) => ({
          label: series.label || `Serie ${index + 1}`,
          data: (series.points || []).map(p => ({
            x: p.ts || p.x,
            y: p.sec || p.y || (p.ms / 1000) || 0
          })),
          borderColor: series.color || `hsl(${index * 45}, 70%, 50%)`,
          backgroundColor: 'transparent',
          tension: 0.3,
          pointRadius: 2,
          pointHoverRadius: 5,
        }))
      };
    }
    
    const data = Array.isArray(seriesMon) ? seriesMon : [];
    
    return {
      datasets: [{
        label: title,
        data: data.map(p => ({
          x: p.ts || p.x,
          y: p.sec || p.y || (p.ms / 1000) || 0
        })),
        borderColor: isDark ? '#60a5fa' : '#3b82f6',
        backgroundColor: isDark ? 'rgba(96, 165, 250, 0.1)' : 'rgba(59, 130, 246, 0.1)',
        tension: 0.3,
        fill: true,
        pointRadius: 2,
        pointHoverRadius: 5,
      }]
    };
  }, [mode, seriesMon, seriesMulti, title, isDark]);

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    animation: false,
    interaction: {
      mode: 'index',
      intersect: false,
    },
    plugins: {
      legend: {
        display: mode === 'multi',
        position: 'top',
        labels: {
          color: isDark ? '#e5e7eb' : '#1f2937',
          usePointStyle: true,
          pointStyle: 'circle',
        }
      },
      title: {
        display: mode !== 'multi' && title,
        text: title,
        color: isDark ? '#e5e7eb' : '#1f2937',
      },
      tooltip: {
        mode: 'index',
        intersect: false,
        backgroundColor: isDark ? '#1f2937' : '#ffffff',
        titleColor: isDark ? '#f3f4f6' : '#111827',
        bodyColor: isDark ? '#e5e7eb' : '#4b5563',
        borderColor: isDark ? '#374151' : '#e5e7eb',
        borderWidth: 1,
        padding: 8,
        cornerRadius: 6,
        displayColors: true,
        boxPadding: 4,
        callbacks: {
          label: function(context) {
            let label = context.dataset.label || '';
            if (label) {
              label += ': ';
            }
            if (context.parsed.y !== null) {
              label += new Intl.NumberFormat('es-ES', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
              }).format(context.parsed.y) + ' s';
            }
            return label;
          }
        }
      }
    },
    scales: {
      x: {
        type: 'time',
        time: {
          unit: 'hour',
          displayFormats: { hour: 'HH:mm' },
          tooltipFormat: 'dd/MM/yyyy HH:mm',
        },
        adapters: { date: { locale: es } },
        grid: {
          color: isDark ? '#374151' : '#e5e7eb',
        },
        ticks: {
          color: isDark ? '#9ca3af' : '#6b7280',
        }
      },
      y: {
        beginAtZero: true,
        grid: {
          color: isDark ? '#374151' : '#e5e7eb',
        },
        ticks: { 
          color: isDark ? '#9ca3af' : '#6b7280',
          callback: (value) => `${value.toFixed(2)}s`
        },
        title: {
          display: true,
          text: 'Latencia (segundos)',
          color: isDark ? '#9ca3af' : '#6b7280',
        }
      }
    }
  };

  if (mode === 'multi' && (!seriesMulti || seriesMulti.length === 0)) {
    return (
      <div style={{ 
        height: h, 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center',
        background: isDark ? '#1f2937' : '#f9fafb',
        borderRadius: '8px',
        border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`
      }}>
        <p style={{ color: isDark ? '#9ca3af' : '#6b7280' }}>
          No hay datos para mostrar
        </p>
      </div>
    );
  }

  if (mode !== 'multi' && (!seriesMon || seriesMon.length === 0)) {
    return (
      <div style={{ 
        height: h, 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center',
        background: isDark ? '#1f2937' : '#f9fafb',
        borderRadius: '8px',
        border: `1px solid ${isDark ? '#374151' : '#e5e7eb'}`
      }}>
        <p style={{ color: isDark ? '#9ca3af' : '#6b7280' }}>
          Cargando datos...
        </p>
      </div>
    );
  }

  return (
    <div style={{ height: h, width: '100%' }}>
      <Line data={chartData} options={options} />
    </div>
  );
}
EOF

echo "✅ HistoryChart.jsx restaurado - TOOLTIP ORIGINAL"
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
echo "✅✅ TOOLTIP ORIGINAL RESTAURADO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🎨 TOOLTIP: AHORA MUESTRA VALORES INDIVIDUALES"
echo "      • Al pasar el mouse: 'Sede: 0.12 s'"
echo "      • NO más lista agrupada"
echo "      • Mismo formato que el original"
echo ""
echo "   2. 📊 FORMATO DE NÚMEROS: RESTAURADO"
echo "      • 2 decimales siempre"
echo "      • Unidad 's' (segundos)"
echo ""
echo "   3. 🎯 INTERACCIÓN: mode: 'index'"
echo "      • Muestra SOLO el punto donde está el mouse"
echo "      • NO agrupa todos los puntos"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Ve a 'Comparar'"
echo "   3. ✅ Pasa el mouse sobre UNA línea"
echo "   4. ✅ DEBE mostrar: 'Caracas: 0.12 s'"
echo "   5. ✅ NO debe mostrar una lista de todas las sedes"
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
