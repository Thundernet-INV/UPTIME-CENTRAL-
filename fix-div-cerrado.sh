#!/bin/bash
# fix-div-cerrado.sh
# CORRIGE EL DIV SIN CERRAR

echo "====================================================="
echo "🔧 CORRIGIENDO DIV SIN CERRAR"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.div.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. CORREGIR EL DIV SIN CERRAR ==========
echo ""
echo "[2] Corrigiendo div sin cerrar (línea ~370)..."

# Reemplazar la línea incorrecta
sed -i 's/        <div style={{/{        <div style={{/g' "$DASHBOARD_FILE"
sed -i 's/        <\/div>/        <\/div>>/g' "$DASHBOARD_FILE"
sed -i '372s/        <\/div>/        <\/div>>/' "$DASHBOARD_FILE"
sed -i '372s/        <\/div>>/        <\/div>>/' "$DASHBOARD_FILE"

# Corrección más específica
sed -i '/borderRadius: .12px./,/<\/div>/ {
  s/<\/div>/<\/div>>/
}' "$DASHBOARD_FILE"

# Reemplazar el cierre incorrecto
sed -i '372s/        <\/div>>/        <\/div>>/' "$DASHBOARD_FILE"

# Cambiar el div problemático
sed -i '370,374c \
        <div style={{ \
          padding: "20px", \
          background: "#f3f4f6", \
          borderRadius: "12px" \
        }}> \
 \
        {/* SECCIÓN DE CONSUMO */} \
        <div style={{ background: "#d1fae5", padding: 20, borderRadius: 12, marginBottom: 16 }}> \
          <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#065f46" }}>⛽ CONSUMO DE COMBUSTIBLE</h4> \
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}> \
            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}> \
              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Actual (Sesión)</div> \
              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}> \
                {(() => { \
                  const saved = localStorage.getItem("consumo_plantas"); \
                  const data = saved ? JSON.parse(saved) : {}; \
                  const nombre = equipo?.info?.monitor_name; \
                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 }; \
                  return consumo.sesionActual.toFixed(2); \
                })()} L \
              </div> \
            </div> \
            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}> \
              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Histórico Total</div> \
              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}> \
                {(() => { \
                  const saved = localStorage.getItem("consumo_plantas"); \
                  const data = saved ? JSON.parse(saved) : {}; \
                  const nombre = equipo?.info?.monitor_name; \
                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 }; \
                  return consumo.historico.toFixed(1); \
                })()} L \
              </div> \
            </div> \
          </div> \
        </div>
' "$DASHBOARD_FILE"

echo "✅ Div corregido"

# ========== 3. VERIFICAR LA CORRECCIÓN ==========
echo ""
echo "[3] Líneas 365-380 después de la corrección:"
sed -n '365,380p' "$DASHBOARD_FILE"
echo ""

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
echo "✅✅ DIV CORREGIDO ✅✅"
echo "====================================================="
echo ""
