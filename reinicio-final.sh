#!/bin/bash
echo "🚀 REINICIO FINAL DEL BACKEND"
echo "=============================="

BACKEND_DIR="/opt/kuma-central/kuma-aggregator"
LOG_FILE="/var/log/kuma-backend.log"

# 1. Asegurar que no hay procesos en 8080
echo "1. Limpiando puerto 8080..."
sudo kill $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 2
sudo kill -9 $(sudo lsof -ti:8080) 2>/dev/null || true
sleep 1

echo "   ✅ Puerto 8080 limpio"

# 2. Verificar archivos
echo ""
echo "2. Verificando archivos..."
cd "$BACKEND_DIR"

if ! node -c "src/index.js" > /dev/null 2>&1; then
    echo "   ❌ Error en src/index.js"
    node -c "src/index.js"
    exit 1
fi
echo "   ✅ src/index.js sintaxis OK"

# 3. Iniciar backend
echo ""
echo "3. Iniciando backend..."
echo "   Logs: $LOG_FILE"
> "$LOG_FILE"  # Limpiar log anterior

npm start >> "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "   ✅ Proceso iniciado: PID $NEW_PID"

# 4. Esperar inicio
echo ""
echo "4. Esperando inicio (7 segundos)..."
sleep 7

# 5. Verificar
echo ""
echo "5. Verificando estado..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    HEALTH=$(curl -s http://localhost:8080/health)
    echo "   ✅ Backend activo"
    echo "   📊 Health: $HEALTH"
else
    echo "   ❌ Backend NO responde"
    echo ""
    echo "🔍 Últimas 15 líneas del log:"
    tail -15 "$LOG_FILE"
    echo ""
    echo "💡 Intentar manualmente:"
    echo "   cd $BACKEND_DIR"
    echo "   npm start"
    exit 1
fi

# 6. Probar módulo de historial
echo ""
echo "6. Probando módulo de historial..."
API_TEST=$(curl -s "http://localhost:8080/api/history?limit=1")
if echo "$API_TEST" | grep -q "data\|errors"; then
    echo "   ✅ API de historial respondiendo"
else
    echo "   ⚠️  Respuesta inesperada: $(echo $API_TEST | head -c 100)"
fi

# 7. Verificar que el guardado automático está configurado
echo ""
echo "7. Verificando guardado automático..."
if grep -q "historyService.addEvent" "src/index.js"; then
    COUNT=$(grep -c "historyService.addEvent" "src/index.js")
    echo "   ✅ Guardado automático configurado ($COUNT lugares)"
else
    echo "   ❌ NO hay guardado automático"
fi

echo ""
echo "=============================="
echo "🎉 BACKEND REINICIADO EXITOSAMENTE"
echo ""
echo "📋 INFORMACIÓN:"
echo "   - PID: $NEW_PID"
echo "   - Logs: tail -f $LOG_FILE"
echo "   - Health: curl http://localhost:8080/health"
echo "   - API Historial: curl http://localhost:8080/api/history?limit=3"
echo ""
echo "⏳ ESPERA 15 SEGUNDOS para que el backend"
echo "   procese al menos 3 ciclos de polling y"
echo "   guarde datos en la base de datos."
echo "=============================="
