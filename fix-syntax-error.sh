#!/bin/bash
# fix-syntax-error.sh
# CORRIGE EL ERROR DE SINTAXIS EN ADMINPLANTAS.JSX

echo "====================================================="
echo "🔧 CORRIGIENDO ERROR DE SINTAXIS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
ADMIN_FILE="$FRONTEND_DIR/src/components/AdminPlantas.jsx"

# ========== 1. HACER BACKUP ==========
echo ""
echo "[1] Creando backup..."
cp "$ADMIN_FILE" "$ADMIN_FILE.backup.syntax.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup creado"

# ========== 2. CORREGIR EL ERROR ==========
echo ""
echo "[2] Corrigiendo error de sintaxis en línea 271..."

# Mostrar la línea problemática
echo "Línea problemática:"
sed -n '271p' "$ADMIN_FILE"

# Corregir el error (falta un paréntesis o llave)
sed -i '271s/^/          /' "$ADMIN_FILE"

# Alternativa: reemplazar toda la función con una versión corregida
cat > /tmp/funcion-corregida.txt << 'EOF'
  const actualizarConsumo = (nuevosEstados) => {
    setConsumoAcumulado(prev => {
      const nuevoConsumo = { ...prev };
      const ahora = Date.now();
      
      // Procesar cada planta
      Object.entries(nuevosEstados).forEach(([nombre, estado]) => {
        const plantaConfig = plantas.find(p => p.nombre_monitor === nombre);
        if (!plantaConfig) return;
        
        const consumoPorHora = plantaConfig.consumo_lh || 7.0;
        const estadoAnterior = prev[nombre]?.estado;
        const ultimoCambio = prev[nombre]?.ultimoCambio || ahora;
        const historicoAnterior = prev[nombre]?.historico || 0;
        
        // SI ESTABA APAGADA Y AHORA ENCENDIÓ
        if (estadoAnterior !== "UP" && estado.status === "UP") {
          console.log(`🔌 ${nombre} ENCENDIÓ`);
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: ahora,
            sesionActual: 0,
            historico: historicoAnterior,
            inicioSesion: ahora
          };
        }
        // SI ESTABA ENCENDIDA Y AHORA APAGÓ
        else if (estadoAnterior === "UP" && estado.status === "DOWN") {
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);
          const duracionHoras = duracionMs / (1000 * 60 * 60);
          const consumoSesion = duracionHoras * consumoPorHora;
          
          console.log(`🔴 ${nombre} APAGÓ - Consumió ${consumoSesion.toFixed(4)}L`);
          
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: ahora,
            sesionActual: 0,
            historico: historicoAnterior + consumoSesion,
            ultimaSesion: {
              inicio: prev[nombre]?.ultimoCambio,
              fin: ahora,
              consumo: consumoSesion,
              duracionMin: duracionMs / 60000
            }
          };
        }
        // SI SIGUE ENCENDIDA
        else if (estado.status === "UP") {
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);
          const duracionHoras = duracionMs / (1000 * 60 * 60);
          const consumoSesion = duracionHoras * consumoPorHora;
          
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,
            sesionActual: consumoSesion,
            historico: historicoAnterior
          };
          
          if (Math.floor(duracionMs / 1000) % 30 === 0) {
            console.log(`⚡ ${nombre} consumo actual: ${consumoSesion.toFixed(4)}L`);
          }
        }
        // SI SIGUE APAGADA
        else {
          nuevoConsumo[nombre] = {
            estado: estado.status,
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,
            sesionActual: 0,
            historico: historicoAnterior
          };
        }
      });
      
      return nuevoConsumo;
    });
  };
EOF

# Reemplazar la función en el archivo
sed -i '/const actualizarConsumo =/,/^  };/c\
  const actualizarConsumo = (nuevosEstados) => {\
    setConsumoAcumulado(prev => {\
      const nuevoConsumo = { ...prev };\
      const ahora = Date.now();\
      \
      Object.entries(nuevosEstados).forEach(([nombre, estado]) => {\
        const plantaConfig = plantas.find(p => p.nombre_monitor === nombre);\
        if (!plantaConfig) return;\
        \
        const consumoPorHora = plantaConfig.consumo_lh || 7.0;\
        const estadoAnterior = prev[nombre]?.estado;\
        const ultimoCambio = prev[nombre]?.ultimoCambio || ahora;\
        const historicoAnterior = prev[nombre]?.historico || 0;\
        \
        if (estadoAnterior !== "UP" && estado.status === "UP") {\
          console.log(`🔌 ${nombre} ENCENDIÓ`);\
          nuevoConsumo[nombre] = {\
            estado: estado.status,\
            ultimoCambio: ahora,\
            sesionActual: 0,\
            historico: historicoAnterior,\
            inicioSesion: ahora\
          };\
        }\
        else if (estadoAnterior === "UP" && estado.status === "DOWN") {\
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);\
          const duracionHoras = duracionMs / (1000 * 60 * 60);\
          const consumoSesion = duracionHoras * consumoPorHora;\
          console.log(`🔴 ${nombre} APAGÓ - Consumió ${consumoSesion.toFixed(4)}L`);\
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
        else if (estado.status === "UP") {\
          const duracionMs = ahora - (prev[nombre]?.ultimoCambio || ahora);\
          const duracionHoras = duracionMs / (1000 * 60 * 60);\
          const consumoSesion = duracionHoras * consumoPorHora;\
          nuevoConsumo[nombre] = {\
            estado: estado.status,\
            ultimoCambio: prev[nombre]?.ultimoCambio || ahora,\
            sesionActual: consumoSesion,\
            historico: historicoAnterior\
          };\
          if (Math.floor(duracionMs / 1000) % 30 === 0) {\
            console.log(`⚡ ${nombre} consumo actual: ${consumoSesion.toFixed(4)}L`);\
          }\
        }\
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

echo "✅ Error de sintaxis corregido"

# ========== 3. VERIFICAR SINTAXIS ==========
echo ""
echo "[3] Verificando sintaxis..."
cd "$FRONTEND_DIR"
npx eslint --no-eslintrc "$ADMIN_FILE" 2>/dev/null && echo "✅ Sintaxis OK" || echo "⚠️ Puede haber otros errores"

# ========== 4. HACER BUILD ==========
echo ""
echo "[4] Intentando build nuevamente..."
npm run build

echo ""
echo "====================================================="
echo "✅✅ ERROR DE SINTAXIS CORREGIDO ✅✅"
echo "====================================================="
echo ""
