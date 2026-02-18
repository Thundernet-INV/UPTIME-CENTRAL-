// src/components/HistoryChart.jsx - VERSIÓN CON TOOLTIP INDIVIDUAL
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
      mode: 'nearest', // 🟢 CAMBIADO DE 'index' a 'nearest'
      intersect: false,
      axis: 'xy',      // 🟢 AÑADIDO para mejor precisión
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
        mode: 'nearest',     // 🟢 CAMBIADO DE 'index' a 'nearest'
        intersect: false,
        axis: 'xy',          // 🟢 AÑADIDO para mejor precisión
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
          title: function(context) {
            // Mostrar la fecha/hora del punto
            if (context[0]) {
              const date = new Date(context[0].parsed.x);
              return date.toLocaleString('es-ES', {
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                day: '2-digit',
                month: '2-digit'
              });
            }
            return '';
          },
          label: function(context) {
            // 🟢 MOSTRAR SOLO EL PUNTO ACTUAL - SIN LISTA
            let label = context.dataset.label || '';
            if (label) {
              label += ': ';
            }
            if (context.parsed.y !== null) {
              label += context.parsed.y.toFixed(3) + ' s';
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
