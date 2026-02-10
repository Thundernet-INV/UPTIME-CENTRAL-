#!/bin/bash
echo "🔄 REINICIO SEGURO DEL BACKEND"
echo "================================"

BACKEND_PID=$(sudo lsof -ti:8080)
BACKEND_DIR="/opt/kuma-central/kuma-aggregator"
LOG_FILE="/var/log/kuma-backend.log"

if [ -z "$BACKEND_PID" ]; then
    echo "⚠️  No hay backend corriendo en puerto 8080"
else
    echo "1. Backend actual: PID $BACKEND_PID"
    
    # Obtener información del proceso
    echo "   Comando: $(ps -p $BACKEND_PID -o cmd=)"
    echo "   Tiempo ejecutando: $(ps -p $BACKEND_PID -o etime=)"
    
    # Preguntar confirmación
    read -p "   ¿Detener este backend para reiniciar? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "❌ Reinicio cancelado"
        exit 0
    fi
    
    echo "2. Deteniendo backend PID $BACKEND_PID..."
    sudo kill $BACKEND_PID
    sleep 3
    
    # Verificar si se detuvo
    if sudo lsof -ti:8080 > /dev/null 2>&1; then
        echo "   ⚠️  No se detuvo, forzando..."
        sudo kill -9 $BACKEND_PID
        sleep 2
    fi
    
    # Confirmar detención
    if sudo lsof -ti:8080 > /dev/null 2>&1; then
        echo "   ❌ No se pudo detener el backend"
        exit 1
    else
        echo "   ✅ Backend detenido"
    fi
fi

echo ""
echo "3. Verificando archivos del backend..."
cd "$BACKEND_DIR"

# Verificar package.json
if ! node -e "require('./package.json')" > /dev/null 2>&1; then
    echo "   ❌ package.json inválido"
    exit 1
fi
echo "   ✅ package.json válido"

# Verificar index.js
if ! node -c "src/index.js" > /dev/null 2>&1; then
    echo "   ❌ Error de sintaxis en src/index.js"
    echo "   Detalle:"
    node -c "src/index.js"
    exit 1
fi
echo "   ✅ src/index.js sintaxis correcta"

# Verificar que tenga las modificaciones
if ! grep -q "historyService.addEvent" "src/index.js"; then
    echo "   ⚠️  src/index.js no tiene las modificaciones de guardado automático"
fi

echo ""
echo "4. Iniciando nuevo backend..."
echo "   Directorio: $BACKEND_DIR"
echo "   Logs: $LOG_FILE"

# Limpiar log anterior
> "$LOG_FILE"

# Iniciar backend
npm start >> "$LOG_FILE" 2>&1 &
NEW_PID=$!
echo "   ✅ Nuevo backend iniciado: PID $NEW_PID"

echo ""
echo "5. Esperando inicio (5 segundos)..."
sleep 5

echo ""
echo "6. Verificando estado..."
if curl -s http://localhost:8080/health > /dev/null; then
    HEALTH=$(curl -s http://localhost:8080/health)
    echo "   ✅ Backend respondiendo"
    echo "   📊 Health: $HEALTH"
else
    echo "   ❌ Backend NO responde después de 5 segundos"
    echo ""
    echo "🔍 Últimas líneas del log:"
    tail -20 "$LOG_FILE"
    echo ""
    echo "💡 Soluciones posibles:"
    echo "   - Verificar errores en src/index.js"
    echo "   - Revisar permisos: sudo chown -R thunder:thunder $BACKEND_DIR"
    echo "   - Otro proceso usando puerto 8080: sudo lsof -ti:8080"
    exit 1
fi

echo ""
echo "7. Probando módulo de historial..."
API_RESP=$(curl -s "http://localhost:8080/api/history?limit=1")
if echo "$API_RESP" | grep -q "data\|errors"; then
    echo "   ✅ API de historial funcionando"
else
    echo "   ⚠️  API de historial puede tener problemas: $(echo $API_RESP | head -c 100)"
fi

echo ""
echo "================================"
echo "🎉 REINICIO COMPLETADO"
echo ""
echo "📋 RESUMEN:"
echo "   - Backend anterior: PID $BACKEND_PID (detenido)"
echo "   - Backend nuevo: PID $NEW_PID"
echo "   - Logs: $LOG_FILE"
echo "   - Health: http://localhost:8080/health"
echo ""
echo "⏳ Ahora espera 10 segundos para que el backend"
echo "   comience a guardar datos automáticamente..."
echo "================================"
