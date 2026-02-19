#!/bin/bash
# fix-estructura-energia.sh
# CORRIGE LA ESTRUCTURA DEL JSX EN ENERGIA DASHBOARD

echo "====================================================="
echo "🔧 CORRIGIENDO ESTRUCTURA JSX"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DASHBOARD_FILE="$FRONTEND_DIR/src/components/EnergiaDashboard.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.backup.estructura.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MOSTRAR EL ÁREA PROBLEMÁTICA ==========
echo ""
echo "[2] Área problemática (líneas 370-390):"
sed -n '370,390p' "$DASHBOARD_FILE"
echo ""

# ========== 3. CORREGIR LA ESTRUCTURA ==========
echo ""
echo "[3] Corrigiendo estructura..."

# Crear un archivo temporal con la corrección
cat > /tmp/energia-fix.txt << 'EOF'
        </div>

        {/* SECCIÓN DE CONSUMO */}
        <div style={{ background: "#d1fae5", padding: 20, borderRadius: 12, marginBottom: 16 }}>
          <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#065f46" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>
              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Actual (Sesión)</div>
              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>
                {(() => {
                  const saved = localStorage.getItem("consumo_plantas");
                  const data = saved ? JSON.parse(saved) : {};
                  const nombre = equipo?.info?.monitor_name;
                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };
                  return consumo.sesionActual.toFixed(2);
                })()} L
              </div>
            </div>
            <div style={{ background: "white", padding: 16, borderRadius: 8, textAlign: "center" }}>
              <div style={{ fontSize: "0.8rem", color: "#6b7280", marginBottom: 4 }}>Consumo Histórico Total</div>
              <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>
                {(() => {
                  const saved = localStorage.getItem("consumo_plantas");
                  const data = saved ? JSON.parse(saved) : {};
                  const nombre = equipo?.info?.monitor_name;
                  const consumo = data[nombre] || { sesionActual: 0, historico: 0 };
                  return consumo.historico.toFixed(1);
                })()} L
              </div>
            </div>
          </div>
        </div>

        <div style={{
          padding: '20px',
          background: '#f3f4f6',
          borderRadius: '12px'
        }}>
EOF

# Reemplazar las líneas 375-390 con el contenido corregido
sed -i '375,390d' "$DASHBOARD_FILE"
sed -i '374r /tmp/energia-fix.txt' "$DASHBOARD_FILE"

echo "✅ Estructura corregida"

# ========== 4. VERIFICAR LA CORRECCIÓN ==========
echo ""
echo "[4] Líneas después de la corrección (370-400):"
sed -n '370,400p' "$DASHBOARD_FILE"
echo ""

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
echo "✅✅ ESTRUCTURA JSX CORREGIDA ✅✅"
echo "====================================================="
echo ""
