#!/bin/bash
# fix-energia-dashboard-manual.sh
# MODIFICA ENERGIA DASHBOARD EN LAS LÍNEAS EXACTAS

echo "====================================================="
echo "🔧 MODIFICANDO ENERGIA DASHBOARD MANUALMENTE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR LAS LÍNEAS ALREDEDOR DE DONDE INSERTAREMOS ==========
echo ""
echo "[2] Mostrando líneas 365-385 (para referencia):"
sed -n '365,385p' "$DASHBOARD_FILE"
echo ""

# ========== 3. INSERTAR LA SECCIÓN DE CONSUMO ANTES DE INFORMACIÓN ADICIONAL ==========
echo ""
echo "[3] Insertando sección de consumo en línea 374..."

# Insertar antes de la línea 375 (INFORMACIÓN ADICIONAL)
sed -i '374i \n        {/* SECCIÓN DE CONSUMO */}\n        <div style={{ background: "#d1fae5", padding: 20, borderRadius: 12, marginBottom: 16 }}>\n          <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#065f46" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>\n          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>\n            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>\n              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Actual (Sesión)</div>\n              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>\n                {(() => {\n                  const saved = localStorage.getItem("consumo_plantas");\n                  const data = saved ? JSON.parse(saved) : {};\n                  const nombre = monitor?.info?.monitor_name;\n                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                  return consumo.sesionActual.toFixed(2);\n                })()} L\n              </div>\n            </div>\n            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>\n              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Histórico Total</div>\n              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>\n                {(() => {\n                  const saved = localStorage.getItem("consumo_plantas");\n                  const data = saved ? JSON.parse(saved) : {};\n                  const nombre = monitor?.info?.monitor_name;\n                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                  return consumo.historico.toFixed(1);\n                })()} L\n              </div>\n            </div>\n          </div>\n        </div>' "$DASHBOARD_FILE"

echo "✅ Sección de consumo insertada"

# ========== 4. AGREGAR EL ESTADO DE CONSUMO ==========
echo ""
echo "[4] Agregando estado de consumo..."

# Buscar donde están los useState y agregar después
sed -i '/const .* = useState(/a \  const [consumo, setConsumo] = useState({ sesionActual: 0, historico: 0 });' "$DASHBOARD_FILE"

echo "✅ Estado de consumo agregado"

# ========== 5. AGREGAR ACTUALIZACIÓN EN TIEMPO REAL ==========
echo ""
echo "[5] Agregando actualización en tiempo real..."

# Buscar el último useEffect y agregar después
sed -i '/useEffect.*{/a \  \n  // Actualizar consumo cada 2 segundos\n  useEffect(() => {\n    const actualizarConsumo = () => {\n      try {\n        const saved = localStorage.getItem("consumo_plantas");\n        if (saved) {\n          const data = JSON.parse(saved);\n          const nombre = monitor?.info?.monitor_name;\n          setConsumo(data[nombre] || { sesionActual: 0, historico: 0 });\n        }\n      } catch (e) {\n        console.error("Error actualizando consumo:", e);\n      }\n    };\n\n    actualizarConsumo();\n    const interval = setInterval(actualizarConsumo, 2000);\n    return () => clearInterval(interval);\n  }, [monitor]);' "$DASHBOARD_FILE"

echo "✅ Actualización en tiempo real agregada"

# ========== 6. MOSTRAR LAS LÍNEAS DESPUÉS DE LA MODIFICACIÓN ==========
echo ""
echo "[6] Verificando líneas 370-390 después de la modificación:"
sed -n '370,390p' "$DASHBOARD_FILE"

# ========== 7. REINICIAR FRONTEND ==========
echo ""
echo "[7] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ ENERGIA DASHBOARD MODIFICADO ✅✅"
echo "====================================================="
echo ""
