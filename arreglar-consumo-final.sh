#!/bin/bash
# arreglar-consumo-final.sh
# MUEVE EL CONSUMO AL LUGAR CORRECTO EN EnergiaDetail

echo "====================================================="
echo "🔧 ARREGLANDO UBICACIÓN DEL CONSUMO"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. ELIMINAR EL CÓDIGO DE CONSUMO DEL PRINCIPIO ==========
echo ""
echo "[2] Eliminando código de consumo del principio..."

# Crear un archivo temporal sin las líneas del consumo
sed -i '/SECCIÓN DE CONSUMO DE COMBUSTIBLE/,/<\/div>/d' "$DETAIL_FILE"
sed -i '/window.plantaActual/d' "$DETAIL_FILE"

echo "✅ Código eliminado"

# ========== 3. ENCONTRAR EL LUGAR CORRECTO PARA INSERTAR ==========
echo ""
echo "[3] Buscando lugar para insertar el consumo..."

# Buscar la función TarjetaTipo
LINE_NUM=$(grep -n "function TarjetaTipo" "$DETAIL_FILE" | head -1 | cut -d: -f1)

if [ -n "$LINE_NUM" ]; then
    echo "✅ Función TarjetaTipo encontrada en línea $LINE_NUM"
    
    # Insertar después de calcularMetricas
    INSERT_LINE=$((LINE_NUM - 5))
    
    cat > /tmp/consumo-final.txt << 'EOF'
// ========== FUNCIÓN PARA CALCULAR CONSUMO ==========
function calcularConsumo(monitorName) {
  try {
    const saved = localStorage.getItem("consumo_plantas");
    const data = saved ? JSON.parse(saved) : {};
    return {
      sesionActual: data[monitorName]?.sesionActual || 0,
      historico: data[monitorName]?.historico || 0
    };
  } catch (e) {
    return { sesionActual: 0, historico: 0 };
  }
}

EOF

    sed -i "${INSERT_LINE}r /tmp/consumo-final.txt" "$DETAIL_FILE"
    echo "✅ Función calcularConsumo insertada"
    
    # Ahora buscar dónde agregar el consumo en la tarjeta
    # Buscar dentro de TarjetaTipo donde están las métricas
    sed -i '/<div style={{/,/<\/div>/ {
      /display: "grid", gridTemplateColumns: "repeat(auto-fit/ {
        a \          
        {/* CONSUMO DE COMBUSTIBLE */}
        a \          <div style={{ gridColumn: "span 2", background: "#f3f4f6", padding: 16, borderRadius: 8, marginTop: 16 }}>
        a \            <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#4b5563" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>
        a \            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        a \              <div style={{ background: "#d1fae5", padding: 12, borderRadius: 6 }}>
        a \                <div style={{ fontSize: "0.7rem", color: "#065f46" }}>Sesión Actual</div>
        a \                <div style={{ fontSize: "1.2rem", fontWeight: 700, color: "#065f46" }}>
        a \                  {(() => {
        a \                    const consumo = calcularConsumo(monitor.info?.monitor_name);
        a \                    return consumo.sesionActual.toFixed(2);
        a \                  })()} L
        a \                </div>
        a \              </div>
        a \              <div style={{ background: "#e5e7eb", padding: 12, borderRadius: 6 }}>
        a \                <div style={{ fontSize: "0.7rem", color: "#1f2937" }}>Histórico Total</div>
        a \                <div style={{ fontSize: "1.2rem", fontWeight: 700, color: "#1f2937" }}>
        a \                  {(() => {
        a \                    const consumo = calcularConsumo(monitor.info?.monitor_name);
        a \                    return consumo.historico.toFixed(2);
        a \                  })()} L
        a \                </div>
        a \              </div>
        a \            </div>
        a \          </div>
      }
    }' "$DETAIL_FILE"
    
    echo "✅ Consumo agregado a las tarjetas"
    
else
    echo "❌ No se encontró la función TarjetaTipo"
    exit 1
fi

# ========== 4. VERIFICAR ==========
echo ""
echo "[4] Verificando cambios..."

if grep -q "calcularConsumo" "$DETAIL_FILE"; then
    echo "✅ Función calcularConsumo encontrada"
else
    echo "❌ No se encontró la función"
fi

if grep -q "CONSUMO DE COMBUSTIBLE" "$DETAIL_FILE"; then
    echo "✅ Sección de consumo encontrada en tarjetas"
else
    echo "❌ No se encontró el consumo en tarjetas"
fi

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
echo "✅✅ CONSUMO ARREGLADO ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EL CONSUMO DEBERÍA APARECER:"
echo "   • Dentro de cada tarjeta de tipo (PLANTA, AVR, etc.)"
echo "   • Para cada equipo individual"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
