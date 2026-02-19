#!/bin/bash
# agregar-consumo-a-energiadetail.sh
# AGREGA INFORMACIÓN DE CONSUMO AL DETALLE DE PLANTA

echo "====================================================="
echo "⛽ AGREGANDO CONSUMO A EnergiaDetail.jsx"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DETAIL_FILE="$FRONTEND_DIR/src/components/EnergiaDetail.jsx"

# ========== 1. VERIFICAR QUE EL ARCHIVO EXISTE ==========
echo ""
echo "[1] Verificando archivo..."

if [ ! -f "$DETAIL_FILE" ]; then
    echo "❌ No se encuentra el archivo: $DETAIL_FILE"
    echo "   Buscando en backups..."
    
    # Buscar en backups
    BACKUP_FILE=$(find "$FRONTEND_DIR" -name "EnergiaDetail.jsx" -type f 2>/dev/null | head -1)
    if [ -n "$BACKUP_FILE" ]; then
        echo "✅ Encontrado en: $BACKUP_FILE"
        cp "$BACKUP_FILE" "$DETAIL_FILE"
    else
        echo "❌ No se encontró el archivo"
        exit 1
    fi
fi

# ========== 2. HACER BACKUP ==========
echo ""
echo "[2] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 3. AGREGAR CONSUMO AL DETALLE ==========
echo ""
echo "[3] Agregando sección de consumo al detalle..."

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
  a \                return data[planta?.nombre_monitor]?.sesionActual?.toFixed(2) || "0.00";
  a \              })()} L
  a \            </div>
  a \          </div>
  a \          <div style={{ background: "#e5e7eb", padding: 16, borderRadius: 8 }}>
  a \            <div style={{ fontSize: "0.8rem", color: "#1f2937", marginBottom: 4 }}>Consumo Histórico Total</div>
  a \            <div style={{ fontSize: "2rem", fontWeight: 700, color: "#1f2937" }}>
  a \              {(() => {
  a \                const saved = localStorage.getItem("consumo_plantas");
  a \                const data = saved ? JSON.parse(saved) : {};
  a \                return data[planta?.nombre_monitor]?.historico?.toFixed(2) || "0.00";
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

# ========== 4. VERIFICAR QUE EL ARCHIVO USA LA VARIABLE CORRECTA ==========
echo ""
echo "[4] Verificando nombre de variable..."

# Buscar cómo se llama la variable de la planta en el archivo
PLANT_VAR=$(grep -o "planta\.[a-zA-Z_]*" "$DETAIL_FILE" | head -1 | cut -d. -f1)

if [ -n "$PLANT_VAR" ]; then
    echo "✅ Variable de planta detectada: $PLANT_VAR"
    # Reemplazar en el código si es necesario
    sed -i "s/planta\.nombre_monitor/$PLANT_VAR.nombre_monitor/g" "$DETAIL_FILE"
else
    echo "⚠️ No se detectó variable de planta, asumiendo 'planta'"
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
echo "✅✅ CONSUMO AGREGADO AL DETALLE ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA EL DETALLE DE PLANTA DEBERÍA MOSTRAR:"
echo "   • Consumo actual de la sesión (en verde)"
echo "   • Consumo histórico total (en gris)"
echo "   • Actualización en tiempo real"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
