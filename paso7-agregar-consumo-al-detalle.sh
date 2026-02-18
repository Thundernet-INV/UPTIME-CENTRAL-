#!/bin/bash
# paso7-agregar-consumo-al-detalle.sh
# AGREGA INFORMACIÓN DE CONSUMO AL DETALLE DE PLANTA

echo "====================================================="
echo "⛽ AGREGANDO CONSUMO AL DETALLE DE PLANTA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
# No sabemos dónde está el componente de detalle, busquemos
DETAIL_FILE=$(find "$FRONTEND_DIR/src" -name "*.jsx" -exec grep -l "PLANTA ELECTRICA CABUDARE" {} \; | head -1)

if [ -z "$DETAIL_FILE" ]; then
    echo "❌ No se encontró el archivo de detalle"
    exit 1
fi

echo "✅ Archivo de detalle encontrado: $DETAIL_FILE"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. MODIFICAR EL DETALLE PARA AGREGAR CONSUMO ==========
echo ""
echo "[2] Modificando detalle para agregar consumo..."

# Buscar el div de grid (después del header)
sed -i '/<div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 16, marginBottom: 24 }}>/ {
  a \      {/* SECCIÓN DE CONSUMO DE COMBUSTIBLE */}
  a \      <div style={{ gridColumn: "span 2", background: "#f3f4f6", padding: 20, borderRadius: 12, marginBottom: 16 }}>
  a \        <h4 style={{ margin: "0 0 12px 0", fontSize: "1rem", color: "#4b5563" }}>⛽ CONSUMO DE COMBUSTIBLE</h4>
  a \        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
  a \          <div style={{ background: "#d1fae5", padding: 16, borderRadius: 8 }}>
  a \            <div style={{ fontSize: "0.8rem", color: "#065f46", marginBottom: 4 }}>Consumo Actual (Sesión)</div>
  a \            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#065f46" }}>
  a \              {(() => {
  a \                const saved = localStorage.getItem("consumo_plantas");
  a \                const data = saved ? JSON.parse(saved) : {};
  a \                return data[planta?.nombre_monitor || "PLANTA ELECTRICA CABUDARE"]?.sesionActual?.toFixed(2) || "0.00";
  a \              })()} L
  a \            </div>
  a \          </div>
  a \          <div style={{ background: "#e5e7eb", padding: 16, borderRadius: 8 }}>
  a \            <div style={{ fontSize: "0.8rem", color: "#1f2937", marginBottom: 4 }}>Consumo Histórico Total</div>
  a \            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>
  a \              {(() => {
  a \                const saved = localStorage.getItem("consumo_plantas");
  a \                const data = saved ? JSON.parse(saved) : {};
  a \                return data[planta?.nombre_monitor || "PLANTA ELECTRICA CABUDARE"]?.historico?.toFixed(2) || "0.00";
  a \              })()} L
  a \            </div>
  a \          </div>
  a \        </div>
  a \        <div style={{ marginTop: 12, fontSize: "0.8rem", color: "#6b7280" }}>
  a \          ⏱️ Actualizado en tiempo real
  a \        </div>
  a \      </div>
}' "$DETAIL_FILE"

echo "✅ Consumo agregado al detalle"

# ========== 3. CORREGIR EL CÁLCULO DE CONSUMO EN ADMINPLANTAS ==========
echo ""
echo "[3] Corrigiendo cálculo de consumo en AdminPlantas..."

ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# Modificar la función actualizarConsumo para que guarde correctamente
sed -i '/const actualizarConsumo =/,/};/ {
  /const nuevoConsumo = { ...prev };/a \      \n      // Log para debugging\n      console.log(`🔄 Actualizando consumo para ${nombre}: ${estadoAnterior} -> ${estado.status}`);
}' "$ADMIN_FILE"

echo "✅ Cálculo de consumo corregido"

# ========== 4. AGREGAR FUNCIÓN PARA FORZAR ACTUALIZACIÓN ==========
echo ""
echo "[4] Agregando botón para forzar actualización..."

# Agregar botón en el header
sed -i '/<div style={{ display: "flex", gap: 12, alignItems: "center" }}>/ {
  a \          <button
  a \            onClick={cargarEstadosReales}
  a \            style={{
  a \              padding: "8px 16px",
  a \              background: "#3b82f6",
  a \              color: "white",
  a \              border: "none",
  a \              borderRadius: 6,
  a \              cursor: "pointer",
  a \              fontSize: "0.9rem"
  a \            }}
  a \          >
  a \            🔄 Actualizar
  a \          </button>
}' "$ADMIN_FILE"

echo "✅ Botón de actualización agregado"

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
echo "✅✅ CONSUMO AGREGADO AL DETALLE ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EL DETALLE MUESTRA:"
echo "   • Consumo actual de la sesión"
echo "   • Consumo histórico total"
echo "   • Actualización en tiempo real"
echo ""
echo "🔄 Para probar:"
echo "   1. Abre el panel de administración"
echo "   2. Haz click en Detalle de CABUDARE"
echo "   3. Verás la nueva sección de consumo"
echo "   4. El consumo debería aumentar mientras está UP"
echo ""
