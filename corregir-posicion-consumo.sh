#!/bin/bash
# corregir-posicion-consumo.sh
# MUEVE EL CONSUMO A LA POSICIÓN CORRECTA

echo "====================================================="
echo "🔧 CORRIGIENDO POSICIÓN DEL CONSUMO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. ELIMINAR EL CONSUMO INSERTADO EN LÍNEA 2 ==========
echo ""
echo "[2] Eliminando consumo de línea 2..."
sed -i '2,22d' "$DETAIL_FILE"
echo "✅ Eliminado"

# ========== 3. BUSCAR EL LUGAR CORRECTO ==========
echo ""
echo "[3] Buscando lugar correcto para insertar..."

# Buscar la sección de INFORMACIÓN ADICIONAL
LINE_NUM=$(grep -n "INFORMACIÓN ADICIONAL" "$DETAIL_FILE" | head -1 | cut -d: -f1)

if [ -n "$LINE_NUM" ]; then
    echo "✅ Sección 'INFORMACIÓN ADICIONAL' encontrada en línea $LINE_NUM"
    INSERT_LINE=$((LINE_NUM - 1))
else
    # Si no encuentra, buscar el final del div de las cards
    LINE_NUM=$(grep -n '</div>' "$DETAIL_FILE" | head -4 | tail -1 | cut -d: -f1)
    INSERT_LINE=$LINE_NUM
fi

echo "✅ Insertando antes de la línea $INSERT_LINE"

# ========== 4. INSERTAR CONSUMO EN LA POSICIÓN CORRECTA ==========
echo ""
echo "[4] Insertando consumo en posición correcta..."

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
                  return (data[nombre]?.sesionActual || 0).toFixed(2);
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
                  return (data[nombre]?.historico || 0).toFixed(2);
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

sed -i "${INSERT_LINE}r /tmp/consumo-code.txt" "$DETAIL_FILE"

echo "✅ Consumo insertado en posición correcta"

# ========== 5. VERIFICAR ==========
echo ""
echo "[5] Verificando inserción..."

if grep -q "CONSUMO DE COMBUSTIBLE" "$DETAIL_FILE"; then
    echo "✅ Sección de consumo encontrada"
    
    # Mostrar líneas alrededor
    echo ""
    echo "Líneas alrededor de la inserción:"
    grep -A 5 -B 2 "CONSUMO DE COMBUSTIBLE" "$DETAIL_FILE"
else
    echo "❌ No se encontró la sección"
fi

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ CONSUMO COLOCADO EN POSICIÓN CORRECTA ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA DEBERÍAS VER:"
echo "   • El consumo aparece después de las 4 cards"
echo "   • Antes de la sección 'INFORMACIÓN ADICIONAL'"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
