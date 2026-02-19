#!/bin/bash
# forzar-agregar-consumo-v2.sh
# BUSCA EL LUGAR CORRECTO PARA INSERTAR EL CONSUMO

echo "====================================================="
echo "🔧 FORZANDO AGREGACIÓN DE CONSUMO (V2)"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

# ========== 1. VERIFICAR ARCHIVO ==========
echo ""
echo "[1] Verificando archivo..."

if [ ! -f "$DETAIL_FILE" ]; then
    echo "❌ No se encuentra: $DETAIL_FILE"
    exit 1
fi

echo "✅ Archivo encontrado: $DETAIL_FILE"
echo ""
echo "Mostrando primeras 50 líneas del archivo:"
echo "----------------------------------------"
head -50 "$DETAIL_FILE"
echo "----------------------------------------"

# ========== 2. HACER BACKUP ==========
echo ""
echo "[2] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 3. PEDIR AL USUARIO QUE IDENTIFIQUE LA LÍNEA ==========
echo ""
echo "❓ Necesito que me ayudes a identificar dónde insertar el consumo."
echo ""
echo "Por favor, responde:"
echo "   1. ¿Después de qué línea quieres insertar el consumo?"
echo "   2. ¿O quieres que lo inserte al final del todo?"
echo ""
read -p "Número de línea (o 'end' para final): " LINE_NUM

if [ "$LINE_NUM" = "end" ]; then
    echo ""
    echo "[3] Insertando al final del archivo..."
    
    cat >> "$DETAIL_FILE" << 'EOF'

      {/* SECCIÓN DE CONSUMO DE COMBUSTIBLE */}
      <div style={{ gridColumn: "span 2", background: "#f3f4f6", padding: 20, borderRadius: 12, marginBottom: 16 }}>
        <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#4b5563" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div style={{ background: "#d1fae5", padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: "0.8rem", color: "#065f46", marginBottom: 4 }}>Consumo Actual (Sesión)</div>
            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>
              {(() => {
                try {
                  const saved = localStorage.getItem("consumo_plantas");
                  const data = saved ? JSON.parse(saved) : {};
                  const nombre = window.plantaActual || "PLANTA ELECTRICA EL ROSAL";
                  return data[nombre]?.sesionActual?.toFixed(2) || "0.00";
                } catch (e) {
                  return "0.00";
                }
              })()} L
            </div>
          </div>
          <div style={{ background: "#e5e7eb", padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: "0.8rem", color: "#1f2937", marginBottom: 4 }}>Consumo Histórico Total</div>
            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>
              {(() => {
                try {
                  const saved = localStorage.getItem("consumo_plantas");
                  const data = saved ? JSON.parse(saved) : {};
                  const nombre = window.plantaActual || "PLANTA ELECTRICA EL ROSAL";
                  return data[nombre]?.historico?.toFixed(2) || "0.00";
                } catch (e) {
                  return "0.00";
                }
              })()} L
            </div>
          </div>
        </div>
        <div style={{ marginTop: 12, fontSize: "0.8rem", color: "#6b7280" }}>
          ⏱️ Actualizado en tiempo real · Los datos se guardan automáticamente
        </div>
      </div>
EOF

    echo "✅ Código insertado al final"
    
else
    echo ""
    echo "[3] Insertando en la línea $LINE_NUM..."
    
    # Crear archivo temporal con el código
    cat > /tmp/consumo-code.txt << 'EOF'
      {/* SECCIÓN DE CONSUMO DE COMBUSTIBLE */}
      <div style={{ gridColumn: "span 2", background: "#f3f4f6", padding: 20, borderRadius: 12, marginBottom: 16 }}>
        <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#4b5563" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div style={{ background: "#d1fae5", padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: "0.8rem", color: "#065f46", marginBottom: 4 }}>Consumo Actual (Sesión)</div>
            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>
              {(() => {
                try {
                  const saved = localStorage.getItem("consumo_plantas");
                  const data = saved ? JSON.parse(saved) : {};
                  const nombre = window.plantaActual || "PLANTA ELECTRICA EL ROSAL";
                  return data[nombre]?.sesionActual?.toFixed(2) || "0.00";
                } catch (e) {
                  return "0.00";
                }
              })()} L
            </div>
          </div>
          <div style={{ background: "#e5e7eb", padding: 16, borderRadius: 8 }}>
            <div style={{ fontSize: "0.8rem", color: "#1f2937", marginBottom: 4 }}>Consumo Histórico Total</div>
            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>
              {(() => {
                try {
                  const saved = localStorage.getItem("consumo_plantas");
                  const data = saved ? JSON.parse(saved) : {};
                  const nombre = window.plantaActual || "PLANTA ELECTRICA EL ROSAL";
                  return data[nombre]?.historico?.toFixed(2) || "0.00";
                } catch (e) {
                  return "0.00";
                }
              })()} L
            </div>
          </div>
        </div>
        <div style={{ marginTop: 12, fontSize: "0.8rem", color: "#6b7280" }}>
          ⏱️ Actualizado en tiempo real · Los datos se guardan automáticamente
        </div>
      </div>
EOF

    sed -i "${LINE_NUM}r /tmp/consumo-code.txt" "$DETAIL_FILE"
    echo "✅ Código insertado en línea $LINE_NUM"
fi

# ========== 4. AGREGAR VARIABLE GLOBAL ==========
echo ""
echo "[4] Agregando variable global para el nombre de la planta..."

if ! grep -q "window.plantaActual" "$DETAIL_FILE"; then
    sed -i '/export default function EnergiaDetail/ a \ \ // Guardar nombre de la planta para consumo\n  useEffect(() => {\n    if (planta?.nombre_monitor) {\n      window.plantaActual = planta.nombre_monitor;\n    }\n  }, [planta]);' "$DETAIL_FILE"
fi

if ! grep -q "import { useEffect" "$DETAIL_FILE"; then
    sed -i 's/import React/import React, { useEffect }/' "$DETAIL_FILE"
fi

echo "✅ Variable global agregada"

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
echo "✅✅ PROCESO COMPLETADO ✅✅"
echo "====================================================="
echo ""
echo "📊 Ahora abre el detalle de cualquier planta"
echo "   Deberías ver la sección de consumo"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
