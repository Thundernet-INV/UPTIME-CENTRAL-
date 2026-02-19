#!/bin/bash
# fix-energia-cards-consumo.sh
# AGREGA CONSUMO A LAS CARDS DE ENERGÍA

echo "====================================================="
echo "🔧 AGREGANDO CONSUMO A CARDS DE ENERGÍA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
OVERVIEW_FILE="$FRONTEND_DIR/src/views/EnergiaOverviewCards.jsx"
DETAIL_FILE="$FRONTEND_DIR/src/views/EnergiaCategoryDetail.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backups..."
cp "$OVERVIEW_FILE" "$OVERVIEW_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backups creados"

# ========== 2. MODIFICAR ENERGIAOVERVIEWCARDS.JSX ==========
echo ""
echo "[2] Modificando EnergiaOverviewCards.jsx..."

# Agregar función para obtener consumo
sed -i '/import .energia-cards-v5.css./a \n// Función para obtener consumo de combustible\nconst getConsumo = (nombreMonitor) => {\n  if (typeof window === "undefined") return { sesionActual: 0, historico: 0 };\n  const saved = localStorage.getItem("consumo_plantas");\n  const data = saved ? JSON.parse(saved) : {};\n  return data[nombreMonitor] || { sesionActual: 0, historico: 0 };\n};' "$OVERVIEW_FILE"

# Modificar el map de categorías para mostrar consumo en cards de plantas
sed -i '/const metrics = computeMetrics/ a \            const isPlanta = c === '\''plantas'\'';' "$OVERVIEW_FILE"
sed -i '/<div className="inst-footer">/ a \            {isPlanta && (\n              <div style={{\n                marginTop: 8,\n                padding: "8px 12px",\n                background: "#d1fae5",\n                borderRadius: 6,\n                fontSize: "0.8rem",\n                display: "flex",\n                justifyContent: "space-between"\n              }}>\n                <span>⛽ Consumo Total</span>\n                <span style={{ fontWeight: 600, color: "#065f46" }}>\n                  {(() => {\n                    let total = 0;\n                    byCat[c].forEach(item => {\n                      const nombre = item?.info?.monitor_name || item?.name;\n                      const consumo = getConsumo(nombre);\n                      total += consumo.historico || 0;\n                    });\n                    return total.toFixed(1);\n                  })()} L\n                </span>\n              </div>\n            )}' "$OVERVIEW_FILE"

echo "✅ EnergiaOverviewCards.jsx modificado"

# ========== 3. MODIFICAR ENERGIACATEGORYDETAIL.JSX ==========
echo ""
echo "[3] Modificando EnergiaCategoryDetail.jsx..."

# Agregar función para obtener consumo
sed -i '/import .energia-cards-v5.css./a \n// Función para obtener consumo de combustible\nconst getConsumo = (nombreMonitor) => {\n  if (typeof window === "undefined") return { sesionActual: 0, historico: 0 };\n  const saved = localStorage.getItem("consumo_plantas");\n  const data = saved ? JSON.parse(saved) : {};\n  return data[nombreMonitor] || { sesionActual: 0, historico: 0 };\n};' "$DETAIL_FILE"

# Modificar el listado de items para mostrar consumo
sed -i '/<li key={id} className={`eq-item ${st}`}>/,/<\/li>/c \              <li key={id} className={`eq-item ${st}`}>\n                <span className={`dot ${st}`} />\n                <span className="label">{label}</span>\n                {slug === '\''plantas'\'' && (\n                  <span style={{\n                    marginLeft: "auto",\n                    fontSize: "0.75rem",\n                    padding: "2px 8px",\n                    background: st === '\''up'\'' ? "#d1fae5" : "#f3f4f6",\n                    borderRadius: 12,\n                    color: st === '\''up'\'' ? "#065f46" : "#6b7280"\n                  }}>\n                    {(() => {\n                      const consumo = getConsumo(m?.info?.monitor_name || m?.name);\n                      return st === '\''up'\'' \n                        ? `⛽ ${consumo.sesionActual.toFixed(2)}L` \n                        : `📊 ${consumo.historico.toFixed(1)}L`;\n                    })()}\n                  </span>\n                )}\n              </li>' "$DETAIL_FILE"

echo "✅ EnergiaCategoryDetail.jsx modificado"

# ========== 4. REINICIAR FRONTEND ==========
echo ""
echo "[4] Reiniciando frontend..."

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
echo "   • La card de PLANTAS muestra el consumo total"
echo "   • Al entrar en PLANTAS, cada ítem muestra su consumo"
echo "   • Las plantas UP muestran consumo actual en verde"
echo "   • Las plantas DOWN muestran consumo histórico"
echo ""
