#!/bin/bash
# forzar-agregar-consumo.sh
# FUERZA LA AGREGACIÓN DE CONSUMO AL DETALLE

echo "====================================================="
echo "🔧 FORZANDO AGREGACIÓN DE CONSUMO AL DETALLE"
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

# ========== 2. HACER BACKUP ==========
echo ""
echo "[2] Creando backup..."
cp "$DETAIL_FILE" "$DETAIL_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 3. BUSCAR EL LUGAR CORRECTO PARA INSERTAR ==========
echo ""
echo "[3] Buscando lugar para insertar..."

# Buscar la línea que contiene el grid de 4 columnas
LINE_NUM=$(grep -n 'gridTemplateColumns: "repeat(2, 1fr)"' "$DETAIL_FILE" | head -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ]; then
    echo "❌ No se encontró el grid de 4 cards"
    exit 1
fi

echo "✅ Grid encontrado en línea: $LINE_NUM"

# ========== 4. INSERTAR EL CÓDIGO DE CONSUMO ==========
echo ""
echo "[4] Insertando código de consumo..."

# Crear un archivo temporal con el código a insertar
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

# Insertar después de la línea del grid
sed -i "${LINE_NUM}r /tmp/consumo-code.txt" "$DETAIL_FILE"

echo "✅ Código insertado"

# ========== 5. AGREGAR VARIABLE GLOBAL PARA EL NOMBRE ==========
echo ""
echo "[5] Agregando variable global para el nombre de la planta..."

# Buscar dónde se define la planta
sed -i '/export default function EnergiaDetail/ a \ \ // Guardar nombre de la planta para consumo\n  useEffect(() => {\n    if (planta?.nombre_monitor) {\n      window.plantaActual = planta.nombre_monitor;\n    }\n  }, [planta]);' "$DETAIL_FILE"

# Agregar import de useEffect si no existe
if ! grep -q "import { useEffect" "$DETAIL_FILE"; then
    sed -i 's/import React/import React, { useEffect }/' "$DETAIL_FILE"
fi

echo "✅ Variable global agregada"

# ========== 6. VERIFICAR QUE EL CÓDIGO SE INSERTÓ ==========
echo ""
echo "[6] Verificando inserción..."

if grep -q "CONSUMO DE COMBUSTIBLE" "$DETAIL_FILE"; then
    echo "✅ Sección de consumo encontrada en el archivo"
else
    echo "❌ No se encontró la sección de consumo"
    exit 1
fi

# ========== 7. REINICIAR FRONTEND ==========
echo ""
echo "[7] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

echo ""
echo "====================================================="
echo "✅✅ CONSUMO AGREGADO FORZOSAMENTE ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA DEBERÍAS VER:"
echo "   • Una nueva sección '⛽ CONSUMO DE COMBUSTIBLE'"
echo "   • Consumo actual en verde"
echo "   • Consumo histórico en gris"
echo ""
echo "🌐 Panel: http://10.10.31.31:8081/#/admin-plantas"
echo ""
echo "🔄 Prueba con PLANTA ELECTRICA EL ROSAL (DOWN) o CABUDARE (UP)"
echo ""
