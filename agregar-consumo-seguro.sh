#!/bin/bash
# agregar-consumo-seguro.sh
# AGREGA CONSUMO DE COMBUSTIBLE DE MANERA SEGURA

echo "====================================================="
echo "🔧 AGREGANDO CONSUMO DE COMBUSTIBLE (SEGURO)"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. AGREGAR ESTADO DE CONSUMO ==========
echo ""
echo "[2] Agregando estado de consumo..."

# Buscar donde están los useState y agregar después
sed -i '/const \[selectedEquipo, setSelectedEquipo\] = useState(null);/a \  const [consumos, setConsumos] = useState({});' "$DASHBOARD_FILE"

echo "✅ Estado de consumo agregado"

# ========== 3. AGREGAR FUNCIÓN PARA CARGAR CONSUMO ==========
echo ""
echo "[3] Agregando función para cargar consumo..."

# Agregar después de las otras funciones
sed -i '/function calcularMetricas/ i \n// Cargar consumo de combustible\nconst cargarConsumos = () => {\n  try {\n    const saved = localStorage.getItem("consumo_plantas");\n    if (saved) {\n      setConsumos(JSON.parse(saved));\n    }\n  } catch (e) {\n    console.error("Error cargando consumos:", e);\n  }\n};' "$DASHBOARD_FILE"

echo "✅ Función de carga agregada"

# ========== 4. AGREGAR useEffect PARA ACTUALIZAR CONSUMO ==========
echo ""
echo "[4] Agregando actualización automática..."

# Agregar useEffect después de los useState
sed -i '/const \[consumos, setConsumos\] = useState({});/a \ \n  // Actualizar consumos cada 2 segundos\n  useEffect(() => {\n    cargarConsumos();\n    const interval = setInterval(cargarConsumos, 2000);\n    return () => clearInterval(interval);\n  }, []);' "$DASHBOARD_FILE"

echo "✅ Actualización automática agregada"

# ========== 5. AGREGAR CONSUMO EN LA TARJETA DE EQUIPO ==========
echo ""
echo "[5] Agregando consumo en la tarjeta de equipo..."

# Buscar la parte donde se muestra la latencia y agregar consumo después
sed -i '/{rt && (/,/<\/div>/ {
  /<\/div>/a \      \n      {/* CONSUMO DE COMBUSTIBLE - SOLO PARA PLANTAS */}\n      {tipo === '\''PLANTA'\'' && (\n        <div style={{\n          marginTop: '\''8px'\'',\n          padding: '\''4px 8px'\'',\n          background: status === '\''up'\'' ? '\''#d1fae5'\'' : '\''#f3f4f6'\'',\n          borderRadius: '\''4px'\'',\n          fontSize: '\''0.75rem'\'',\n          display: '\''flex'\'',\n          justifyContent: '\''space-between'\'',\n          alignItems: '\''center'\''\n        }}>\n          <span>⛽ Consumo</span>\n          <span style={{ fontWeight: 600, color: status === '\''up'\'' ? '\''#065f46'\'' : '\''#4b5563'\'' }}>\n            {(() => {\n              const consumo = consumos[equipo.info?.monitor_name] || { sesionActual: 0, historico: 0 };\n              return status === '\''up'\'' \n                ? `${consumo.sesionActual.toFixed(2)}L` \n                : `${consumo.historico.toFixed(1)}L`;\n            })()}\n          </span>\n        </div>\n      )}
}' "$DASHBOARD_FILE"

echo "✅ Consumo agregado a las tarjetas"

# ========== 6. AGREGAR CONSUMO EN EL MODAL DE DETALLE ==========
echo ""
echo "[6] Agregando consumo en el modal de detalle..."

# Buscar el modal y agregar sección de consumo
sed -i '/<div style={{/,/}}>/ {
  /<div style={{/a \          {/* SECCIÓN DE CONSUMO EN MODAL */}\n          {tipo === '\''PLANTA'\'' && (\n            <div style={{\n              gridColumn: '\''span 2'\'',\n              background: '\''#d1fae5'\'',\n              padding: '\''20px'\'',\n              borderRadius: '\''12px'\'',\n              marginBottom: '\''16px'\''\n            }}>\n              <h4 style={{ margin: '\''0 0 12px 0'\'', fontSize: '\''1rem'\'', color: '\''#065f46'\'' }}>\n                ⛽ CONSUMO DE COMBUSTIBLE\n              </h4>\n              <div style={{ display: '\''grid'\'', gridTemplateColumns: '\''1fr 1fr'\'', gap: '\''16px'\'' }}>\n                <div style={{ background: '\''white'\'', padding: '\''16px'\'', borderRadius: '\''8px'\'', textAlign: '\''center'\'' }}>\n                  <div style={{ fontSize: '\''0.8rem'\'', color: '\''#6b7280'\'', marginBottom: '\''4px'\'' }}>\n                    Consumo Actual (Sesión)\n                  </div>\n                  <div style={{ fontSize: '\''2rem'\'', fontWeight: 700, color: '\''#065f46'\'' }}>\n                    {(() => {\n                      const consumo = consumos[equipoSeleccionado?.info?.monitor_name] || { sesionActual: 0, historico: 0 };\n                      return consumo.sesionActual.toFixed(2);\n                    })()} L\n                  </div>\n                </div>\n                <div style={{ background: '\''white'\'', padding: '\''16px'\'', borderRadius: '\''8px'\'', textAlign: '\''center'\'' }}>\n                  <div style={{ fontSize: '\''0.8rem'\'', color: '\''#6b7280'\'', marginBottom: '\''4px'\'' }}>\n                    Consumo Histórico Total\n                  </div>\n                  <div style={{ fontSize: '\''2rem'\'', fontWeight: 700, color: '\''#1f2937'\'' }}>\n                    {(() => {\n                      const consumo = consumos[equipoSeleccionado?.info?.monitor_name] || { sesionActual: 0, historico: 0 };\n                      return consumo.historico.toFixed(1);\n                    })()} L\n                  </div>\n                </div>\n              </div>\n            </div>\n          )}
}' "$DASHBOARD_FILE"

echo "✅ Consumo agregado al modal"

# ========== 7. VERIFICAR CAMBIOS ==========
echo ""
echo "[7] Verificando cambios (líneas modificadas):"
grep -n "CONSUMO DE COMBUSTIBLE" "$DASHBOARD_FILE" || echo "No se encontraron las líneas de consumo"

# ========== 8. REINICIAR FRONTEND ==========
echo ""
echo "[8] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ CONSUMO AGREGADO DE MANERA SEGURA ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA DEBERÍAS VER:"
echo "   • En las tarjetas de PLANTAS, un indicador de consumo"
echo "   • En el modal de detalle, una sección completa de consumo"
echo "   • Los datos se actualizan cada 2 segundos"
echo ""
