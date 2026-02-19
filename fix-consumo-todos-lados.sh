#!/bin/bash
# fix-consumo-todos-lados.sh
# INYECTA CONSUMO EN TODOS LOS POSIBLES LUGARES

echo "====================================================="
echo "🔧 INYECTANDO CONSUMO EN TODOS LOS LUGARES POSIBLES"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# Buscar archivos que podrían contener el detalle
ARCHIVOS=$(grep -r -l "ESTADO\|LATENCIA\|ÚLTIMO CHECK" "$FRONTEND_DIR/src/" 2>/dev/null | grep -v "backup")

if [ -z "$ARCHIVOS" ]; then
    echo "❌ No se encontraron archivos con esos patrones"
    exit 1
fi

echo "✅ Archivos encontrados:"
echo "$ARCHIVOS"
echo ""

for archivo in $ARCHIVOS; do
    echo "Procesando: $archivo"
    
    # Hacer backup
    cp "$archivo" "$archivo.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Buscar un div con grid de 2 columnas (típico del detalle)
    if grep -q "gridTemplateColumns.*repeat(2, 1fr)" "$archivo"; then
        echo "  → Encontrado grid de 2 columnas, agregando consumo..."
        
        # Insertar sección de consumo después del grid
        sed -i '/<div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)",/a \n        {/* SECCIÓN DE CONSUMO */}\n        <div style={{ gridColumn: "span 2", background: "#d1fae5", padding: 20, borderRadius: 12, marginBottom: 16 }}>\n          <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#065f46" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>\n          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>\n            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>\n              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Actual (Sesión)</div>\n              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>\n                {(() => {\n                  const saved = localStorage.getItem("consumo_plantas");\n                  const data = saved ? JSON.parse(saved) : {};\n                  const nombre = monitor?.info?.monitor_name || monitor?.name || props?.monitor?.info?.monitor_name;\n                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                  return consumo.sesionActual.toFixed(2);\n                })()} L\n              </div>\n            </div>\n            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>\n              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Histórico Total</div>\n              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>\n                {(() => {\n                  const saved = localStorage.getItem("consumo_plantas");\n                  const data = saved ? JSON.parse(saved) : {};\n                  const nombre = monitor?.info?.monitor_name || monitor?.name || props?.monitor?.info?.monitor_name;\n                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };\n                  return consumo.historico.toFixed(1);\n                })()} L\n              </div>\n            </div>\n          </div>\n        </div>' "$archivo"
        
        echo "  ✅ Consumo agregado"
    fi
done

# ========== 2. REINICIAR FRONTEND ==========
echo ""
echo "[2] Reiniciando frontend..."
cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ CONSUMO INYECTADO EN ARCHIVOS POSIBLES ✅✅"
echo "====================================================="
echo ""
echo "📊 Archivos procesados:"
echo "$ARCHIVOS"
echo ""
