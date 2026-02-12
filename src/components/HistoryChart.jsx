// src/components/HistoryChart.jsx - VERSIÓN FUNCIONAL
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
  
  // 🟢 MODO MULTI - Para MultiServiceView
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
    
    // 🟢 MODO MONITOR/INSTANCE
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
    plugins: {
      legend: {
        display: mode === 'multi',
        position: 'top',
        labels: {
          color: isDark ? '#e5e7eb' : '#1f2937',
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
      },
    },
    scales: {
      x: {
        type: 'time',
        time: {
          unit: 'hour',
          displayFormats: { hour: 'HH:mm' },
          tooltipFormat: 'HH:mm',
        },
        adapters: { date: { locale: es } },
        grid: {
          color: isDark ? '#2d3238' : '#e5e7eb',
        },
        ticks: {
          color: isDark ? '#94a3b8' : '#6b7280',
        }
      },
      y: {
        beginAtZero: true,
        grid: {
          color: isDark ? '#2d3238' : '#e5e7eb',
        },
        ticks: { 
          color: isDark ? '#94a3b8' : '#6b7280',
          callback: (v) => `${v.toFixed(2)}s`
        },
        title: {
          display: true,
          text: 'Latencia (s)',
          color: isDark ? '#94a3b8' : '#6b7280',
        }
      }
    }
  };

  // Si no hay datos, mostrar mensaje
  if (mode === 'multi' && (!seriesMulti || seriesMulti.length === 0)) {
    return (
      <div style={{ 
        height: h, 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center',
        background: isDark ? '#1a1e24' : '#f9fafb',
        borderRadius: '8px',
        border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`
      }}>
        <p style={{ color: isDark ? '#94a3b8' : '#6b7280' }}>
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
        background: isDark ? '#1a1e24' : '#f9fafb',
        borderRadius: '8px',
        border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`
      }}>
        <p style={{ color: isDark ? '#94a3b8' : '#6b7280' }}>
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
