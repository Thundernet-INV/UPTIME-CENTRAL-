#!/bin/bash
# fix-energia-view-consumo.sh
# AGREGA CONSUMO A LA VISTA DE ENERGÍA

echo "====================================================="
echo "🔧 AGREGANDO CONSUMO A VISTA ENERGÍA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
OVERVIEW_FILE="$FRONTEND_DIR/src/views/EnergiaOverviewCards.jsx"
DETAIL_FILE="$FRONTEND_DIR/src/views/EnergiaCategoryDetail.jsx"

# ========== 1. MODIFICAR ENERGIAOVERVIEWCARDS.JSX ==========
if [ -f "$OVERVIEW_FILE" ]; then
    echo ""
    echo "[1] Modificando EnergiaOverviewCards.jsx..."
    cp "$OVERVIEW_FILE" "$OVERVIEW_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Agregar función para obtener consumo
    sed -i '/import/a \n// Función para obtener consumo\nconst getConsumo = (nombreMonitor) => {\n  if (typeof window === "undefined") return 0;\n  const saved = localStorage.getItem("consumo_plantas");\n  const data = saved ? JSON.parse(saved) : {};\n  return data[nombreMonitor]?.sesionActual || 0;\n};' "$OVERVIEW_FILE"
    
    # Agregar consumo en la card de plantas
    sed -i '/<div className="inst-footer">/a \            {c === '\''plantas'\'' && (\n              <div style={{\n                marginTop: 8,\n                padding: "8px 12px",\n                background: "#d1fae5",\n                borderRadius: 6,\n                display: "flex",\n                justifyContent: "space-between",\n                alignItems: "center",\n                fontSize: "0.8rem"\n              }}>\n                <span style={{ fontWeight: 600, color: "#065f46" }}>⛽ Consumo Total</span>\n                <span style={{ fontWeight: 700, color: "#059669" }}>\n                  {(() => {\n                    let total = 0;\n                    byCat[c].forEach(item => {\n                      const nombre = item?.info?.monitor_name || item?.name;\n                      total += getConsumo(nombre);\n                    });\n                    return total.toFixed(2);\n                  })()} L\n                </span>\n              </div>\n            )}' "$OVERVIEW_FILE"
    
    echo "✅ EnergiaOverviewCards.jsx modificado"
fi

# ========== 2. MODIFICAR ENERGIACATEGORYDETAIL.JSX ==========
if [ -f "$DETAIL_FILE" ]; then
    echo ""
    echo "[2] Modificando EnergiaCategoryDetail.jsx..."
    cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Agregar función para obtener consumo
    sed -i '/import/a \n// Función para obtener consumo\nconst getConsumo = (nombreMonitor) => {\n  if (typeof window === "undefined") return { sesionActual: 0, historico: 0 };\n  const saved = localStorage.getItem("consumo_plantas");\n  const data = saved ? JSON.parse(saved) : {};\n  return data[nombreMonitor] || { sesionActual: 0, historico: 0 };\n};' "$DETAIL_FILE"
    
    # Modificar la lista de items para mostrar consumo
    sed -i '/<li key={id} className={`eq-item ${st}`}>/,/<\/li>/c \              <li key={id} className={`eq-item ${st}`} style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 0", borderBottom: "1px dashed rgba(125,125,125,.25)" }}>\n                <span className={`dot ${st}`} />\n                <span className="label" style={{ flex: 1 }}>{label}</span>\n                {slug === '\''plantas'\'' && (\n                  <span style={{\n                    padding: "2px 8px",\n                    background: st === '\''up'\'' ? "#d1fae5" : "#f3f4f6",\n                    borderRadius: 12,\n                    fontSize: "0.7rem",\n                    fontWeight: 600,\n                    color: st === '\''up'\'' ? "#065f46" : "#4b5563"\n                  }}>\n                    {(() => {\n                      const consumo = getConsumo(m?.info?.monitor_name || m?.name);\n                      return st === '\''up'\'' \n                        ? `⛽ ${consumo.sesionActual.toFixed(2)}L` \n                        : `📊 ${consumo.historico.toFixed(1)}L`;\n                    })()}\n                  </span>\n                )}\n              </li>' "$DETAIL_FILE"
    
    echo "✅ EnergiaCategoryDetail.jsx modificado"
fi

# ========== 3. VERIFICAR ARCHIVOS MODIFICADOS ==========
echo ""
echo "[3] Archivos modificados:"
[ -f "$OVERVIEW_FILE" ] && echo "  • $OVERVIEW_FILE"
[ -f "$DETAIL_FILE" ] && echo "  • $DETAIL_FILE"

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
echo "   • Las plantas UP muestran ⛽ con consumo actual"
echo "   • Las plantas DOWN muestran 📊 con consumo histórico"
echo ""
