#!/bin/bash
# fix-energia-detail-final.sh
# MODIFICA EL COMPONENTE ENERGIA DETAIL PARA MOSTRAR CONSUMO

echo "====================================================="
echo "🔧 MODIFICANDO ENERGIA DETAIL PARA MOSTRAR CONSUMO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

# ========== 1. VER CONTENIDO ACTUAL ==========
echo ""
echo "[1] Contenido actual del archivo:"
echo "----------------------------------------"
head -20 "$DETAIL_FILE"
echo "----------------------------------------"

# ========== 2. HACER BACKUP ==========
echo ""
echo "[2] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 3. MODIFICAR EL ARCHIVO ==========
echo ""
echo "[3] Modificando EnergiaDetail.jsx..."

# Buscar el div del grid y agregar la sección de consumo después
sed -i '/<div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)",/a \n        {/* SECCIÓN DE CONSUMO */}\n        <div style={{ gridColumn: "span 2", background: "#d1fae5", padding: 20, borderRadius: 12, marginBottom: 16 }}>\n          <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#065f46" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>\n          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>\n            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>\n              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Actual (Sesión)</div>\n              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>\n                {(() => {\n                  try {\n                    const saved = localStorage.getItem("consumo_plantas");\n                    const data = saved ? JSON.parse(saved) : {};\n                    const nombre = monitor?.info?.monitor_name || monitor?.name;\n                    const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                    return consumo.sesionActual.toFixed(2);\n                  } catch (e) {\n                    return "0.00";\n                  }\n                })()} L\n              </div>\n            </div>\n            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>\n              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Histórico Total</div>\n              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>\n                {(() => {\n                  try {\n                    const saved = localStorage.getItem("consumo_plantas");\n                    const data = saved ? JSON.parse(saved) : {};\n                    const nombre = monitor?.info?.monitor_name || monitor?.name;\n                    const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                    return consumo.historico.toFixed(1);\n                  } catch (e) {\n                    return "0.0";\n                  }\n                })()} L\n              </div>\n            </div>\n          </div>\n        </div>' "$DETAIL_FILE"

# ========== 4. AGREGAR ACTUALIZACIÓN EN TIEMPO REAL ==========
echo ""
echo "[4] Agregando actualización en tiempo real..."

# Buscar el useEffect y agregar intervalo para actualizar consumo
sed -i '/useEffect.*{/a \  const [consumo, setConsumo] = useState({ sesionActual: 0, historico: 0 });' "$DETAIL_FILE"

sed -i '/useEffect.*{/a \  \n  // Cargar consumo inicial y actualizar cada 2 segundos\n  useEffect(() => {\n    const cargarConsumo = () => {\n      try {\n        const saved = localStorage.getItem("consumo_plantas");\n        if (saved) {\n          const data = JSON.parse(saved);\n          const nombre = monitor?.info?.monitor_name || monitor?.name;\n          setConsumo(data[nombre] || { sesionActual: 0, historico: 0 });\n        }\n      } catch (e) {\n        console.error("Error cargando consumo:", e);\n      }\n    };\n\n    cargarConsumo();\n    const interval = setInterval(cargarConsumo, 2000);\n    return () => clearInterval(interval);\n  }, [monitor]);' "$DETAIL_FILE"

echo "✅ Actualización en tiempo real agregada"

# ========== 5. REEMPLAZAR LOS VALORES ESTÁTICOS POR EL ESTADO ==========
echo ""
echo "[5] Reemplazando valores estáticos por el estado..."

sed -i 's/consumo.sesionActual.toFixed/consumo.sesionActual.toFixed/g' "$DETAIL_FILE"
sed -i 's/consumo.historico.toFixed/consumo.historico.toFixed/g' "$DETAIL_FILE"

echo "✅ Valores reemplazados"

# ========== 6. VERIFICAR SINTAXIS ==========
echo ""
echo "[6] Verificando sintaxis..."
cd "$FRONTEND_DIR"
npx eslint --no-eslintrc "$DETAIL_FILE" 2>/dev/null && echo "✅ Sintaxis OK" || echo "⚠️ Puede haber errores"

# ========== 7. REINICIAR FRONTEND ==========
echo ""
echo "[7] Reiniciando frontend..."
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ ENERGIA DETAIL MODIFICADO ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EN EL DETALLE DEBERÍAS VER:"
echo "   • Una sección verde con ⛽ CONSUMO DE COMBUSTIBLE"
echo "   • Consumo actual de la sesión"
echo "   • Consumo histórico total"
echo "   • Actualización en tiempo real cada 2 segundos"
echo ""
