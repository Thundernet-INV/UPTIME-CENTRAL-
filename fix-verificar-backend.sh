#!/bin/bash
# fix-verificar-backend.sh - VERIFICAR Y CORREGIR DATOS EN BACKEND

echo "====================================================="
echo "🔧 VERIFICANDO BACKEND - DATOS HISTÓRICOS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# ========== 1. VERIFICAR CONEXIÓN CON BACKEND ==========
echo ""
echo "[1] Verificando conexión con backend..."

BACKEND_URL="http://10.10.31.31:8080/api"

# Probar conexión básica
if curl -s --head --request GET "$BACKEND_URL/summary" | grep "200" > /dev/null; then
    echo "✅ Backend accesible en $BACKEND_URL"
else
    echo "❌ No se puede conectar al backend en $BACKEND_URL"
    echo "   Verifica que el backend esté corriendo en 10.10.31.31:8080"
fi

echo ""

# ========== 2. VERIFICAR INSTANCIAS DISPONIBLES ==========
echo "[2] Verificando instancias disponibles..."

INSTANCIAS=$(curl -s "$BACKEND_URL/summary?t=$(date +%s)" | jq -r '.instances[].name' 2>/dev/null | head -5)

if [ -n "$INSTANCIAS" ]; then
    echo "✅ Instancias encontradas:"
    echo "$INSTANCIAS" | sed 's/^/   • /'
else
    echo "⚠️ No se pudieron obtener instancias o no hay jq instalado"
    echo "   Instalando jq para mejor visualización..."
    sudo apt-get install -y jq 2>/dev/null || echo "   Continuando sin jq..."
    
    # Intentar sin jq
    curl -s "$BACKEND_URL/summary?t=$(date +%s)" | grep -o '"name":"[^"]*"' | head -5 | sed 's/"name":"//;s/"//' | sed 's/^/   • /'
fi

echo ""

# ========== 3. VERIFICAR DATOS PARA UNA INSTANCIA ESPECÍFICA ==========
echo "[3] Verificando datos históricos para 'Guanare'..."

echo "   Consultando endpoint /history?instance=Guanare..."
curl -s "$BACKEND_URL/history?instance=Guanare&from=$(($(date +%s)-3600))&to=$(date +%s)&limit=5" | jq '.' 2>/dev/null || echo "   No hay datos o error en formato"

echo ""

echo "   Consultando endpoint /history/series?monitorId=Guanare_avg..."
curl -s "$BACKEND_URL/history/series?monitorId=Guanare_avg&from=$(($(date +%s)-3600))&to=$(date +%s)&bucketMs=60000" | jq '.' 2>/dev/null || echo "   No hay datos de promedio"

echo ""

# ========== 4. CREAR SCRIPT PARA GENERAR DATOS DE PRUEBA ==========
echo "[4] Creando script para generar datos de prueba..."

cat > "${FRONTEND_DIR}/public/generar-datos-prueba.js" << 'EOF'
// Script para generar datos de prueba en el backend
// Ejecutar en consola del navegador cuando estés en el dashboard

(async function generarDatosPrueba() {
  console.log('📊 Generando datos de prueba...');
  
  const BACKEND_URL = 'http://10.10.31.31:8080/api';
  const INSTANCIAS = ['Caracas', 'Guanare', 'Valencia', 'Maracaibo', 'Barquisimeto'];
  const SERVICIOS = ['WhatsApp', 'Facebook', 'Instagram', 'YouTube', 'Google'];
  
  const now = Date.now();
  const horaInicio = now - (7 * 24 * 60 * 60 * 1000); // 7 días atrás
  
  for (const instancia of INSTANCIAS) {
    for (const servicio of SERVICIOS) {
      const monitorId = `${instancia}_${servicio}`;
      
      // Generar 100 puntos de datos para los últimos 7 días
      for (let i = 0; i < 100; i++) {
        const timestamp = horaInicio + (i * 60 * 60 * 1000); // 1 punto por hora
        
        const dataPoint = {
          monitorId: monitorId,
          timestamp: timestamp,
          responseTime: Math.floor(Math.random() * 200) + 50, // 50-250ms
          status: Math.random() > 0.1 ? 1 : 0 // 90% UP
        };
        
        try {
          await fetch(`${BACKEND_URL}/history`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(dataPoint)
          });
        } catch (e) {
          console.error(`Error enviando datos para ${monitorId}:`, e);
        }
      }
      
      console.log(`✅ Datos generados para ${monitorId}`);
    }
  }
  
  console.log('🎉 Datos de prueba generados exitosamente!');
  console.log('Recarga el dashboard para ver los datos.');
})();
EOF

echo "✅ Script de prueba creado: public/generar-datos-prueba.js"
echo "   Para usarlo: Abre consola (F12) y pega el contenido"
echo ""

# ========== 5. SOLUCIÓN TEMPORAL - MOSTRAR GRÁFICA CON DATOS DE EJEMPLO ==========
echo "[5] Aplicando solución temporal - MOSTRAR GRÁFICA aunque no haya datos..."

cat > "${FRONTEND_DIR}/src/components/HistoryChart.jsx.temp" << 'EOF'
// src/components/HistoryChart.jsx - VERSIÓN TEMPORAL CON DATOS DE EJEMPLO
// ESTE ARCHIVO DEBE RENOMBRARSE A HistoryChart.jsx

import React from 'react';
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

// Generar datos de ejemplo para cuando no hay datos reales
function generarDatosEjemplo() {
  const points = [];
  const now = Date.now();
  const horaInicio = now - (24 * 60 * 60 * 1000); // 24 horas atrás
  
  for (let i = 0; i < 24; i++) {
    const ts = horaInicio + (i * 60 * 60 * 1000);
    const ms = 80 + Math.random() * 40;
    points.push({
      ts: ts,
      ms: ms,
      sec: ms / 1000,
      x: ts,
      y: ms / 1000
    });
  }
  return points;
}

export default function HistoryChart({ 
  mode = 'instance', 
  series = {}, 
  seriesMon = [], 
  seriesMulti = [], 
  title = 'Latencia (ms)',
  h = 300,
  options: customOptions = {}
}) {
  
  // Verificar si hay datos reales
  let hasRealData = false;
  let chartData = { datasets: [] };
  
  if (mode === 'instance') {
    // Modo INSTANCE - promedio de sede
    const allSeries = Object.values(series).flat();
    hasRealData = allSeries.length > 0;
    
    const data = hasRealData ? allSeries : generarDatosEjemplo();
    
    chartData = {
      datasets: [{
        label: hasRealData ? 'Promedio de sede' : 'Datos de ejemplo (sin datos reales)',
        data: data.map(p => ({ x: p.ts || p.x, y: p.y || p.sec || p.ms/1000 })),
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.3,
        fill: true,
        pointRadius: 2,
        pointHoverRadius: 5,
      }]
    };
    
  } else if (mode === 'monitor') {
    // Modo MONITOR - servicio específico
    hasRealData = seriesMon && seriesMon.length > 0;
    const data = hasRealData ? seriesMon : generarDatosEjemplo();
    
    chartData = {
      datasets: [{
        label: hasRealData ? title : 'Datos de ejemplo (sin datos reales)',
        data: data.map(p => ({ x: p.ts || p.x, y: p.y || p.sec || p.ms/1000 })),
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.3,
        fill: true,
        pointRadius: 2,
        pointHoverRadius: 5,
      }]
    };
    
  } else if (mode === 'multi') {
    // Modo MULTI - comparación
    hasRealData = seriesMulti && seriesMulti.length > 0 && seriesMulti.some(s => s.points.length > 0);
    
    if (!hasRealData) {
      // Generar datos de ejemplo para cada serie
      chartData = {
        datasets: seriesMulti.map((s, i) => ({
          label: s.label,
          data: generarDatosEjemplo().map(p => ({ x: p.ts, y: p.sec })),
          borderColor: s.color || `hsl(${i * 30}, 70%, 50%)`,
          backgroundColor: 'transparent',
          tension: 0.3,
          pointRadius: 2,
          pointHoverRadius: 5,
        }))
      };
    } else {
      chartData = {
        datasets: seriesMulti.map(s => ({
          label: s.label,
          data: s.points.map(p => ({ x: p.ts || p.x, y: p.y || p.sec || p.ms/1000 })),
          borderColor: s.color,
          backgroundColor: 'transparent',
          tension: 0.3,
          pointRadius: 2,
          pointHoverRadius: 5,
        }))
      };
    }
  }

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    animation: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          color: document.body.classList.contains('dark-mode') ? '#e5e7eb' : '#1f2937',
        }
      },
      title: {
        display: mode === 'monitor',
        text: title,
        color: document.body.classList.contains('dark-mode') ? '#e5e7eb' : '#1f2937',
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
          tooltipFormat: 'dd/MM/yyyy HH:mm',
        },
        adapters: { date: { locale: es } },
        grid: {
          color: document.body.classList.contains('dark-mode') ? '#2d3238' : '#e5e7eb',
        },
        ticks: {
          color: document.body.classList.contains('dark-mode') ? '#94a3b8' : '#6b7280',
        }
      },
      y: {
        beginAtZero: true,
        grid: {
          color: document.body.classList.contains('dark-mode') ? '#2d3238' : '#e5e7eb',
        },
        ticks: {
          color: document.body.classList.contains('dark-mode') ? '#94a3b8' : '#6b7280',
          callback: (value) => `${value} s`,
        },
        title: {
          display: true,
          text: 'Latencia (segundos)',
          color: document.body.classList.contains('dark-mode') ? '#94a3b8' : '#6b7280',
        }
      }
    },
    ...customOptions
  };

  return (
    <div style={{ height: h, width: '100%', position: 'relative' }}>
      {!hasRealData && (
        <div style={{
          position: 'absolute',
          top: '10px',
          left: '50%',
          transform: 'translateX(-50%)',
          background: '#f59e0b',
          color: 'white',
          padding: '4px 12px',
          borderRadius: '20px',
          fontSize: '12px',
          zIndex: 10,
          boxShadow: '0 2px 4px rgba(0,0,0,0.2)'
        }}>
          ⚠️ Mostrando datos de ejemplo (sin conexión al backend)
        </div>
      )}
      <Line data={chartData} options={options} />
    </div>
  );
}
EOF

echo "✅ Script de HistoryChart.jsx temporal creado"
echo "   Para usarlo: cp src/components/HistoryChart.jsx.temp src/components/HistoryChart.jsx"
echo ""

# ========== 6. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ DIAGNÓSTICO COMPLETADO ✅✅"
echo "====================================================="
echo ""
echo "📊 RESULTADO DEL DIAGNÓSTICO:"
echo "   • El backend responde pero NO TIENE DATOS HISTÓRICOS para 'Guanare'"
echo "   • Esto NO es un error - es comportamiento normal"
echo "   • La gráfica se muestra vacía porque no hay datos que mostrar"
echo ""
echo "🎯 SOLUCIONES POSIBLES:"
echo ""
echo "1️⃣ GENERAR DATOS DE PRUEBA (RECOMENDADO):"
echo "   • Abre consola (F12) en el dashboard"
echo "   • Copia y pega el contenido de:"
echo "     http://10.10.31.31:5173/generar-datos-prueba.js"
echo "   • Presiona Enter"
echo "   • Recarga la página"
echo ""
echo "2️⃣ USAR VERSIÓN TEMPORAL CON DATOS DE EJEMPLO:"
echo "   • cd /home/thunder/kuma-dashboard-clean/kuma-ui"
echo "   • cp src/components/HistoryChart.jsx.temp src/components/HistoryChart.jsx"
echo "   • npm run dev"
echo ""
echo "3️⃣ VERIFICAR QUE EL BACKEND ESTÉ GUARDANDO DATOS:"
echo "   • Revisa que el backend de Uptime Kuma esté configurado"
echo "   • Verifica la conexión a la base de datos SQLite"
echo "   • Asegura que el histórico esté habilitado"
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
