#!/bin/bash
echo "🔄 REINICIO CON historyService.js ARREGLADO"
echo "==========================================="

BACKEND_DIR="/opt/kuma-central/kuma-aggregator"
LOG_FILE="/var/log/kuma-backend.log"

# 1. Detener cualquier proceso existente
echo "1. Limpiando procesos anteriores..."
sudo kill $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 2
sudo kill -9 $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 1
echo "   ✅ Procesos limpiados"

# 2. Verificar archivos críticos
echo ""
echo "2. Verificando archivos..."
cd "$BACKEND_DIR"

echo "   - historyService.js:"
if node -c "src/services/historyService.js" > /dev/null 2>&1; then
    echo "     ✅ Sintaxis OK"
else
    echo "     ❌ Error:"
    node -c "src/services/historyService.js"
    exit 1
fi

echo "   - index.js:"
if node -c "src/index.js" > /dev/null 2>&1; then
    echo "     ✅ Sintaxis OK"
else
    echo "     ❌ Error:"
    node -c "src/index.js"
    exit 1
fi

# 3. Verificar que no haya recursión infinita
echo ""
echo "3. Verificando función getAvailableMonitors..."
if grep -q "return await getAvailableMonitors()" "src/services/historyService.js"; then
    echo "   ❌ ¡RECURSIÓN INFINITA DETECTADA!"
    echo "   La función se llama a sí misma"
    sed -n '/export async function getAvailableMonitors/,/^}/p' "src/services/historyService.js"
    exit 1
else
    echo "   ✅ No hay recursión infinita"
fi

# 4. Iniciar backend
echo ""
echo "4. Iniciando backend..."
echo "   Logs: $LOG_FILE"
> "$LOG_FILE"  # Limpiar log

npm start >> "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "   ✅ Proceso iniciado: PID $NEW_PID"

# 5. Esperar con más paciencia
echo ""
echo "5. Esperando inicio (10 segundos)..."
for i in {1..10}; do
    echo -n "."
    sleep 1
done
echo ""

# 6. Verificar
echo ""
echo "6. Verificando estado..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    HEALTH=$(curl -s http://localhost:8080/health)
    echo "   ✅ Backend activo"
    echo "   📊 Health: $HEALTH"
    
    # Probar API de historial
    echo ""
    echo "7. Probando API de historial..."
    API_TEST=$(curl -s "http://localhost:8080/api/history?limit=1")
    if echo "$API_TEST" | grep -q "data\|errors"; then
        echo "   ✅ API de historial funcionando"
    else
        echo "   ⚠️  Respuesta: $(echo $API_TEST | head -c 100)"
    fi
else
    echo "   ❌ Backend NO responde después de 10 segundos"
    echo ""
    echo "🔍 Últimas 20 líneas del log:"
    tail -20 "$LOG_FILE"
    echo ""
    echo "💡 Posibles problemas:"
    echo "   - Error en otro archivo"
    echo "   - Puerto 8080 bloqueado"
    echo "   - Falta alguna dependencia"
    exit 1
fi

echo ""
echo "==========================================="
echo "🎉 BACKEND REINICIADO"
echo ""
echo "📋 INFORMACIÓN:"
echo "   - PID: $NEW_PID"
echo "   - Logs: sudo tail -f $LOG_FILE"
echo "   - Health: curl http://localhost:8080/health"
echo ""
echo "⏳ ESPERA 15 SEGUNDOS para que comience"
echo "   a guardar datos automáticamente..."
echo "==========================================="
