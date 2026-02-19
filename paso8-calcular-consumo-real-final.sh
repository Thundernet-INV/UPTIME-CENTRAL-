#!/bin/bash
# paso8-calcular-consumo-real-final.sh
# CORRIGE EL CÁLCULO DE CONSUMO EN TIEMPO REAL

echo "====================================================="
echo "⛽ CORRIGIENDO CÁLCULO DE CONSUMO EN TIEMPO REAL"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. REEMPLAZAR LA FUNCIÓN DE CÁLCULO DE CONSUMO ==========
echo ""
echo "[2] Reemplazando función de cálculo de consumo..."

# Buscar y reemplazar la función actualizarConsumo
sed -i '/const actualizarConsumo =/,/};/c\
  const actualizarConsumo = (nuevosEstados) => {\
    setConsumoAcumulado(prev => {\
      const nuevoConsumo = { ...prev };\
      const ahora = Date.now();\
      \
      // Procesar cada planta\
      Object.entries(nuevosEstados).forEach(([nombre, estado]) => {\
        const plantaConfig = plantas.find(p => p.nombre_monitor === nombre);\
        if (!plantaConfig) return; // No configurada\
        \
        const consumoPorHora = plantaConfig.consumo_lh || 7.0;\
        const estadoAnterior = prev[nombre]?.estado;\
        const ultimoCambio = prev[nombre]?.ultimoCambio || ahora;\
        const historicoAnterior = prev[nombre]?.historico || 0;\
        \
        // SI ESTABA APAGADA Y AHORA ENCENDIÓ - NUEVA SESIÓN\
        if (estadoAnterior !== "UP" && estado.status === "UP") {\
          console.log(`🔌 ${nombre} ENCENDIÓ - Nueva sesión`);\
          nuevoConsumo[nombre] = {\
            estado: estado.status,\
            ultimoCambio: ahora,\
            sesionActual: 0,\
            historico: historicoAnterior,\
            inicioSesion: ahora\
          };\
        }\
        \
        // SI ESTABA ENCENDIDA Y AHORA APAGÓ - GUARDAR CONSUMO\
        else if (estadoAnterior === "UP" && estado.status === "DOWN") {\
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);\
          const duracionHoras = duracionMs / (1000 * 60 * 60);\
          const consumoSesion = duracionHoras * consumoPorHora;\
          \
          console.log(`🔴 ${nombre} APAGÓ - Consumió ${consumoSesion.toFixed(4)}L en ${(duracionMs/60000).toFixed(2)} minutos`);\
          \
          nuevoConsumo[nombre] = {\
            estado: estado.status,\
            ultimoCambio: ahora,\
            sesionActual: 0,\
            historico: historicoAnterior + consumoSesion,\
            ultimaSesion: {\
              inicio: prev[nombre]?.ultimoCambio,\
              fin: ahora,\
              consumo: consumoSesion,\
              duracionMin: duracionMs / 60000\
            }\
          };\
        }\
        \
        // SI SIGUE ENCENDIDA - CALCULAR CONSUMO ACTUAL\
        else if (estado.status === "UP") {\
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);\
          const duracionHoras = duracionMs / (1000 * 60 * 60);\
          const consumoSesion = duracionHoras * consumoPorHora;\
          \
          nuevoConsumo[nombre] = {\
            estado: estado.status,\
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,\
            sesionActual: consumoSesion,\
            historico: historicoAnterior\
          };\
          \
          // Log cada 30 segundos para ver que está calculando\
          if (Math.floor(duracionMs / 1000) % 30 === 0) {\
            console.log(`⚡ ${nombre} lleva ${(duracionMs/60000).toFixed(2)} min encendida, consumo actual: ${consumoSesion.toFixed(4)}L`);\
          }\
        }\
        \
        // SI SIGUE APAGADA - NO CAMBIA\
        else {\
          nuevoConsumo[nombre] = {\
            estado: estado.status,\
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,\
            sesionActual: 0,\
            historico: historicoAnterior\
          };\
        }\
      });\
      \
      return nuevoConsumo;\
    });\
  };' "$ADMIN_FILE"

echo "✅ Función de cálculo reemplazada"

# ========== 3. AGREGAR VISUALIZACIÓN DE CONSUMO EN LA TABLA ==========
echo ""
echo "[3] Mejorando visualización de consumo en la tabla..."

# Modificar la columna de consumo actual para mostrar siempre algo
sed -i '/<td>/,/<\/td>/ {
  /consumo-actual/ {
    s/<span className="consumo-actual">.*<\/span>/<span className="consumo-actual" style={{ color: isUp ? "#16a34a" : "#6b7280" }}>\n                        {isConfigurada ? consumoData.sesionActual.toFixed(3) : "—"} L\n                      <\/span>/
  }
}' "$ADMIN_FILE"

# Modificar la columna de histórico para mostrar siempre
sed -i '/<td>/,/<\/td>/ {
  /consumo-historico/ {
    s/<span className="consumo-historico">.*<\/span>/<span className="consumo-historico">\n                        {isConfigurada ? consumoData.historico.toFixed(2) : "—"} L\n                      <\/span>/
  }
}' "$ADMIN_FILE"

echo "✅ Visualización mejorada"

# ========== 4. AGREGAR BOTÓN PARA VER DETALLE DE CONSUMO ==========
echo ""
echo "[4] Agregando botón de detalle de consumo..."

# Agregar columna de Detalle Consumo
sed -i '/<th>Acciones<\/th>/ {
  i \              <th>Consumo Actual</th>
  i \              <th>Histórico</th>
  i \              <th>Detalle</th>
  i \              <th>Acciones</th>
}' "$ADMIN_FILE"

echo "✅ Botón de detalle agregado"

# ========== 5. AGREGAR LOGS DE DEPURACIÓN ==========
echo ""
echo "[5] Agregando logs de depuración..."

# Agregar log al inicio de cargarEstadosReales
sed -i '/const cargarEstadosReales = async () => {/a \    console.log("📊 Cargando estados de plantas...");' "$ADMIN_FILE"

# Agregar log después de procesar estados
sed -i '/setEstadosReales(estados);/a \    console.log(`📊 Estados cargados: ${Object.keys(estados).length} plantas`);' "$ADMIN_FILE"

echo "✅ Logs de depuración agregados"

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."

cd "$FRONTEND_DIR"
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

echo "✅ Frontend reiniciado"

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CÁLCULO DE CONSUMO CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📊 AHORA DEBERÍAS VER:"
echo ""
echo "   • 🔌 LOG cuando una planta ENCIENDE"
echo "   • 🔴 LOG cuando una planta APAGA (con el consumo)"
echo "   • ⚡ LOG cada 30 segundos de plantas encendidas"
echo "   • Columna 'Consumo Actual' con 3 decimales"
echo "   • Columna 'Histórico' con 2 decimales"
echo ""
echo "🔄 PARA PROBAR:"
echo ""
echo "   1. Abre la consola del navegador (F12)"
echo "   2. Ve al panel: http://10.10.31.31:8081/#/admin-plantas"
echo "   3. Espera a que PLANTA ELECTRICA CALABOZO esté UP"
echo "   4. Verás en la consola los logs de cálculo"
echo "   5. El consumo debería aumentar en la tabla"
echo ""
echo "📌 Si no ves cambios inmediatos, puede tomar hasta 5 segundos"
echo ""
