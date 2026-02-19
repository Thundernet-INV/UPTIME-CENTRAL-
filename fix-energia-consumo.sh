#!/bin/bash
# fix-energia-consumo.sh
# AGREGA CONSUMO DE COMBUSTIBLE A LA VISTA ENERGIA

echo "====================================================="
echo "🔧 AGREGANDO CONSUMO A VISTA ENERGIA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ENERGIA_FILE="$FRONTEND_DIR/src/views/Energia.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ENERGIA_FILE" "$ENERGIA_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MODIFICAR ENERGIA.JSX ==========
echo ""
echo "[2] Modificando Energia.jsx para mostrar consumo..."

# Crear un nuevo componente de card con consumo
sed -i '/{sec.items.map(({ raw, name }) => (/,/<\/div>/c\
                {sec.items.map(({ raw, name }) => {\
                  const nombreMonitor = raw.info?.monitor_name || name;\
                  const saved = typeof window !== "undefined" ? localStorage.getItem("consumo_plantas") : null;\
                  const data = saved ? JSON.parse(saved) : {};\
                  const consumo = data[nombreMonitor] || { sesionActual: 0, historico: 0 };\
                  const isUp = raw.latest?.status === 1;\
                  \
                  return (\
                    <div\
                      key={`${raw.instance ?? "?"}-${name}`}\
                      className="k-card"\
                      style={{ padding: 12, position: "relative" }}\
                    >\
                      <ServiceCard service={raw} series={[]} />\
                      \
                      {/* CONSUMO DE COMBUSTIBLE */}\
                      {raw.info?.monitor_name?.startsWith("PLANTA") && (\
                        <div style={{\
                          marginTop: 8,\
                          padding: "8px 12px",\
                          background: isUp ? "#d1fae5" : "#f3f4f6",\
                          borderRadius: 6,\
                          display: "flex",\
                          justifyContent: "space-between",\
                          alignItems: "center",\
                          fontSize: "0.8rem"\
                        }}>\
                          <span style={{ fontWeight: 600, color: isUp ? "#065f46" : "#4b5563" }}>\
                            ⛽ Consumo\
                          </span>\
                          <span style={{ fontWeight: 700, color: isUp ? "#059669" : "#6b7280" }}>\
                            {isUp ? `${consumo.sesionActual.toFixed(2)} L` : `${consumo.historico.toFixed(1)} L`}\
                          </span>\
                        </div>\
                      )}\
                    </div>\
                  );\
                })
' "$ENERGIA_FILE"

echo "✅ Consumo agregado a las cards"

# ========== 3. CREAR COMPONENTE DE DETALLE CON CONSUMO ==========
echo ""
echo "[3] Creando componente de detalle con consumo..."

# Buscar si existe un componente de detalle
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

if [ ! -f "$DETAIL_FILE" ]; then
    # Crear el componente de detalle
    cat > "$DETAIL_FILE" << 'EOF'
import React, { useState, useEffect } from 'react';

export default function EnergiaDetail({ monitor, onClose }) {
  const [consumo, setConsumo] = useState({ sesionActual: 0, historico: 0 });

  useEffect(() => {
    const saved = localStorage.getItem('consumo_plantas');
    if (saved) {
      const data = JSON.parse(saved);
      setConsumo(data[monitor.info?.monitor_name] || { sesionActual: 0, historico: 0 });
    }

    const interval = setInterval(() => {
      const updated = localStorage.getItem('consumo_plantas');
      if (updated) {
        const data = JSON.parse(updated);
        setConsumo(data[monitor.info?.monitor_name] || { sesionActual: 0, historico: 0 });
      }
    }, 2000);

    return () => clearInterval(interval);
  }, [monitor]);

  const isUp = monitor.latest?.status === 1;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(0,0,0,0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }}>
      <div style={{
        background: 'white',
        borderRadius: 16,
        padding: 32,
        maxWidth: 600,
        width: '100%',
        position: 'relative',
        boxShadow: '0 20px 40px rgba(0,0,0,0.2)'
      }}>
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: 20,
            right: 20,
            background: 'transparent',
            border: 'none',
            fontSize: 28,
            cursor: 'pointer',
            color: '#6b7280'
          }}
        >
          ×
        </button>

        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 24 }}>
          <span style={{ fontSize: '3rem' }}>🏭</span>
          <div>
            <h2 style={{ margin: 0, fontSize: '1.8rem', color: '#1f2937' }}>
              {monitor.info?.monitor_name}
            </h2>
            <p style={{ margin: '4px 0 0', fontSize: '1rem', color: '#6b7280' }}>
              Plantas eléctricas · Energia
            </p>
          </div>
        </div>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: 16,
          marginBottom: 24
        }}>
          <div style={{
            background: isUp ? '#d1fae5' : '#fee2e2',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>ESTADO</div>
            <div style={{ fontSize: '2rem', fontWeight: 700, color: isUp ? '#16a34a' : '#dc2626' }}>
              {isUp ? 'UP' : 'DOWN'}
            </div>
          </div>

          <div style={{
            background: '#f3f4f6',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>LATENCIA</div>
            <div style={{ fontSize: '2rem', fontWeight: 700, color: '#1f2937' }}>
              {monitor.latest?.responseTime?.toFixed(2) || '-1'} ms
            </div>
          </div>

          <div style={{
            background: '#e5e7eb',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>TIPO</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 600, color: '#3b82f6' }}>PLANTA</div>
          </div>

          <div style={{
            background: '#e5e7eb',
            padding: 20,
            borderRadius: 12,
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: 8 }}>ÚLTIMO CHECK</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 600, color: '#1f2937' }}>
              {monitor.latest?.timestamp ? new Date(monitor.latest.timestamp).toLocaleTimeString() : '—'}
            </div>
          </div>
        </div>

        {/* SECCIÓN DE CONSUMO */}
        <div style={{
          background: '#d1fae5',
          padding: 20,
          borderRadius: 12,
          marginBottom: 16
        }}>
          <h4 style={{ margin: '0 0 12px 0', fontSize: '1rem', color: '#065f46' }}>
            ⛽ CONSUMO DE COMBUSTIBLE
          </h4>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <div style={{ background: 'white', padding: 16, borderRadius: 8, textAlign: 'center' }}>
              <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: 4 }}>
                Consumo Actual (Sesión)
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 700, color: '#065f46' }}>
                {consumo.sesionActual.toFixed(2)} L
              </div>
            </div>
            <div style={{ background: 'white', padding: 16, borderRadius: 8, textAlign: 'center' }}>
              <div style={{ fontSize: '0.8rem', color: '#6b7280', marginBottom: 4 }}>
                Consumo Histórico Total
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 700, color: '#1f2937' }}>
                {consumo.historico.toFixed(1)} L
              </div>
            </div>
          </div>
        </div>

        <div style={{
          padding: 20,
          background: '#f3f4f6',
          borderRadius: 12
        }}>
          <h4 style={{ margin: '0 0 12px', fontSize: '1rem', color: '#4b5563' }}>
            INFORMACIÓN ADICIONAL
          </h4>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div><strong>URL:</strong> {monitor.info?.monitor_url || '—'}</div>
            <div><strong>Tipo de monitor:</strong> {monitor.info?.monitor_type || '—'}</div>
            <div><strong>Tags:</strong> {monitor.info?.tags?.join(', ') || 'Ninguno'}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

    echo "✅ EnergiaDetail.jsx creado"
fi

# ========== 4. MODIFICAR SERVICE CARD PARA HACER CLICK ==========
echo ""
echo "[4] Haciendo las cards clickeables..."

# Modificar el map para agregar onClick
sed -i 's/<ServiceCard service={raw} series={[]} \/>/<div onClick={() => setSelectedMonitor(raw)} style={{ cursor: "pointer" }}>\n                        <ServiceCard service={raw} series={[]} \/>\n                      <\/div>/g' "$ENERGIA_FILE"

# Agregar estado para monitor seleccionado después de los otros useState
sed -i '/const \[q, setQ\] = useState("");/a \  const [selectedMonitor, setSelectedMonitor] = useState(null);' "$ENERGIA_FILE"

# Agregar el modal al final del componente, antes del último </div>
sed -i '/<\/div>$/ {
  i \      {selectedMonitor && (\n        <EnergiaDetail\n          monitor={selectedMonitor}\n          onClose={() => setSelectedMonitor(null)}\n        />\n      )}
}' "$ENERGIA_FILE"

# Agregar import al principio
sed -i '1i import EnergiaDetail from "../components/EnergiaDetail.jsx";' "$ENERGIA_FILE"

echo "✅ Cards clickeables con detalle de consumo"

# ========== 5. REINICIAR FRONTEND ==========
echo ""
echo "[5] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ CONSUMO AGREGADO A VISTA ENERGÍA ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EN LA VISTA ENERGÍA:"
echo "   • Las cards de PLANTAS muestran el consumo actual"
echo "   • Las cards son clickeables y abren detalle"
echo "   • El detalle muestra consumo actual e histórico"
echo "   • Los datos se actualizan en tiempo real"
echo ""
